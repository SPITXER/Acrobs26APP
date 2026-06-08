import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

class WebRTCService {
  final String roomId;
  final bool isHost;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  final _localStreamCtrl      = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl     = StreamController<MediaStream?>.broadcast();
  final _peerDisconnectedCtrl = StreamController<void>.broadcast();

  Stream<MediaStream?> get onLocalStream      => _localStreamCtrl.stream;
  Stream<MediaStream?> get onRemoteStream     => _remoteStreamCtrl.stream;
  Stream<void>         get onPeerDisconnected => _peerDisconnectedCtrl.stream;

  final List<StreamSubscription> _subs = [];
  final _db = FirebaseDatabase.instance;
  bool _remoteDescSet = false;
  bool _resetting = false;
  // Set immediately at the top of dispose() so callbacks that fire during
  // pc.close() (e.g. onConnectionState → _resetForPeerReconnect) can bail out.
  bool _disposed = false;

  // Guest-side: SDP of the last processed offer so we detect host re-negotiation
  // even when _remoteDescSet was already set by a stale offer.
  String? _lastProcessedOfferSdp;

  // ICE candidates that arrived before setRemoteDescription completed.
  // Flushed immediately after setRemoteDescription succeeds.
  final List<RTCIceCandidate> _pendingCandidates = [];

  static const _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  WebRTCService({required this.roomId, required this.isHost});

  Future<void> start() async {
    // Gracefully degrade: video+audio → audio only → no media
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': true});
    } catch (_) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({'video': false, 'audio': true});
      } catch (_) {
        // No media devices at all — will still receive remote tracks
      }
    }
    if (_localStream != null) _localStreamCtrl.add(_localStream);
    await _connect();
  }

  // Creates a fresh peer connection, wires up handlers, and runs signaling.
  // Called by start() and by _resetForPeerReconnect() / resetForNewPeer().
  Future<void> _connect() async {
    _pc = await createPeerConnection(_iceConfig);
    _remoteDescSet = false;
    _pendingCandidates.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        _pc!.addTrack(track, _localStream!);
      }
    }

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) _remoteStreamCtrl.add(event.streams.first);
    };

    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _db.ref('signaling/$roomId/${isHost ? "hostCandidates" : "guestCandidates"}').push().set({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (!_peerDisconnectedCtrl.isClosed) _peerDisconnectedCtrl.add(null);
        // Host resets so it can accept a fresh connection when the peer re-enters.
        // Guard with _disposed so pc.close() inside dispose() doesn't spawn a ghost.
        if (isHost) _resetForPeerReconnect();
      }
    };

    if (isHost) {
      await _runHostSignaling();
    } else {
      _runGuestSignaling();
    }
  }

  Future<void> _runHostSignaling() async {
    // Wipe ALL stale signaling — offer, answer, and both candidate lists —
    // so a reconnecting guest never replays stale ICE candidates via onChildAdded.
    await _db.ref('signaling/$roomId').remove();

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _db.ref('signaling/$roomId/offer').set({'sdp': offer.sdp, 'type': offer.type});

    _subs.add(_db.ref('signaling/$roomId/answer').onValue.listen((e) async {
      if (!e.snapshot.exists || _remoteDescSet) return;
      _remoteDescSet = true;
      final v = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      await _pc!.setRemoteDescription(RTCSessionDescription(v['sdp'], v['type']));
      // Flush candidates that arrived before the answer was processed.
      for (final c in List.of(_pendingCandidates)) {
        try { await _pc!.addCandidate(c); } catch (_) {}
      }
      _pendingCandidates.clear();
    }));

    _subs.add(_db.ref('signaling/$roomId/guestCandidates').onChildAdded.listen((e) async {
      final v = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      final c = RTCIceCandidate(v['candidate'], v['sdpMid'], v['sdpMLineIndex']);
      if (!_remoteDescSet) {
        // Remote description not set yet — buffer and flush after the answer arrives.
        _pendingCandidates.add(c);
        return;
      }
      try { await _pc!.addCandidate(c); } catch (_) {}
    }));
  }

  void _runGuestSignaling() {
    _subs.add(_db.ref('signaling/$roomId/offer').onValue.listen((e) async {
      if (_disposed || !e.snapshot.exists) return;
      final v   = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      final sdp = v['sdp'] as String? ?? '';
      if (sdp.isEmpty || sdp == _lastProcessedOfferSdp) return;

      // A new offer arrived with a different SDP. If we've already negotiated
      // with a previous offer on this peer connection, the host has reset.
      // Create a fresh peer connection so the new offer gets a clean slate.
      if (_lastProcessedOfferSdp != null && !_resetting) {
        _lastProcessedOfferSdp = null;
        _remoteDescSet = false;
        for (final s in _subs) s.cancel();
        _subs.clear();
        _pendingCandidates.clear();
        await _pc?.close();
        _pc = null;
        await Future.wait([
          _db.ref('signaling/$roomId/answer').remove(),
          _db.ref('signaling/$roomId/guestCandidates').remove(),
        ]);
        if (!_disposed) await _connect();
        return;
      }

      _lastProcessedOfferSdp = sdp;
      _remoteDescSet = true;
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, v['type']));
      // Flush candidates buffered before the offer was processed.
      for (final c in List.of(_pendingCandidates)) {
        try { await _pc!.addCandidate(c); } catch (_) {}
      }
      _pendingCandidates.clear();
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _db.ref('signaling/$roomId/answer').set({'sdp': answer.sdp, 'type': answer.type});
    }));

    _subs.add(_db.ref('signaling/$roomId/hostCandidates').onChildAdded.listen((e) async {
      if (_disposed) return;
      final v = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      final c = RTCIceCandidate(v['candidate'], v['sdpMid'], v['sdpMLineIndex']);
      if (!_remoteDescSet) {
        // Buffer until the offer is processed and setRemoteDescription completes.
        _pendingCandidates.add(c);
        return;
      }
      try { await _pc!.addCandidate(c); } catch (_) {}
    }));
  }

  // Host-only: tear down the old peer connection and negotiate a fresh one
  // so a re-entering guest can connect without both sides being stuck on stale state.
  Future<void> _resetForPeerReconnect() async {
    if (_resetting || _disposed || _peerDisconnectedCtrl.isClosed) return;
    _resetting = true;
    try {
      for (final s in _subs) s.cancel();
      _subs.clear();
      _remoteDescSet = false;
      _pendingCandidates.clear();
      await _pc?.close();
      // _runHostSignaling() clears all signaling at the start, so no need to
      // do it here — but clearing early reduces the window where the guest
      // could pick up a stale offer before the new one is written.
      await _db.ref('signaling/$roomId').remove();
      await _connect();
    } catch (_) {
      // Non-fatal — next re-entry attempt will try again
    } finally {
      _resetting = false;
    }
  }

  // Guest-side reset: called when the host disconnects while the guest stays
  // in the room (host left and may re-enter). Tears down the stale peer
  // connection and re-subscribes so the guest is ready for the host's new offer.
  Future<void> resetForNewPeer() async {
    if (_disposed || isHost) return;
    try {
      for (final s in _subs) s.cancel();
      _subs.clear();
      _remoteDescSet = false;
      _lastProcessedOfferSdp = null;
      _pendingCandidates.clear();
      await _pc?.close();
      _pc = null;
      await Future.wait([
        _db.ref('signaling/$roomId/answer').remove(),
        _db.ref('signaling/$roomId/guestCandidates').remove(),
      ]);
      await _connect();
    } catch (_) {}
  }

  void toggleMic(bool enabled) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = enabled);
  }

  void toggleCamera(bool enabled) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  }

  Future<void> dispose() async {
    _disposed = true; // must be first — prevents ghost callbacks during pc.close()
    for (final s in _subs) s.cancel();
    _subs.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _pc?.close();
    _localStreamCtrl.close();
    _remoteStreamCtrl.close();
    _peerDisconnectedCtrl.close();
    if (isHost) {
      try { await _db.ref('signaling/$roomId').remove(); } catch (_) {}
    }
  }
}
