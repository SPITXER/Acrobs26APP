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
  // Called by start() and by _resetForPeerReconnect().
  Future<void> _connect() async {
    _pc = await createPeerConnection(_iceConfig);

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
        // Host resets so it can accept a fresh connection when the peer re-enters
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
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _db.ref('signaling/$roomId/offer').set({'sdp': offer.sdp, 'type': offer.type});

    _subs.add(_db.ref('signaling/$roomId/answer').onValue.listen((e) async {
      if (!e.snapshot.exists || _remoteDescSet) return;
      _remoteDescSet = true;
      final v = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      await _pc!.setRemoteDescription(RTCSessionDescription(v['sdp'], v['type']));
    }));

    _subs.add(_db.ref('signaling/$roomId/guestCandidates').onChildAdded.listen((e) async {
      final v = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      await _pc!.addCandidate(RTCIceCandidate(v['candidate'], v['sdpMid'], v['sdpMLineIndex']));
    }));
  }

  void _runGuestSignaling() {
    _subs.add(_db.ref('signaling/$roomId/offer').onValue.listen((e) async {
      if (!e.snapshot.exists || _remoteDescSet) return;
      _remoteDescSet = true;
      final v = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      await _pc!.setRemoteDescription(RTCSessionDescription(v['sdp'], v['type']));
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _db.ref('signaling/$roomId/answer').set({'sdp': answer.sdp, 'type': answer.type});
    }));

    _subs.add(_db.ref('signaling/$roomId/hostCandidates').onChildAdded.listen((e) async {
      final v = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      await _pc!.addCandidate(RTCIceCandidate(v['candidate'], v['sdpMid'], v['sdpMLineIndex']));
    }));
  }

  // Host-only: tear down the old peer connection and negotiate a fresh one
  // so a re-entering guest can connect without both sides being stuck on stale state.
  Future<void> _resetForPeerReconnect() async {
    if (_resetting || _peerDisconnectedCtrl.isClosed) return;
    _resetting = true;
    try {
      for (final s in _subs) s.cancel();
      _subs.clear();
      _remoteDescSet = false;
      await _pc?.close();
      // Clear stale guest signaling so the re-entering peer starts fresh
      await Future.wait([
        _db.ref('signaling/$roomId/answer').remove(),
        _db.ref('signaling/$roomId/guestCandidates').remove(),
      ]);
      await _connect();
    } catch (_) {
      // Non-fatal — next re-entry attempt will try again
    } finally {
      _resetting = false;
    }
  }

  void toggleMic(bool enabled) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = enabled);
  }

  void toggleCamera(bool enabled) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  }

  Future<void> dispose() async {
    for (final s in _subs) s.cancel();
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
