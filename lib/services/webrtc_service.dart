import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';

class WebRTCService {
  final String roomId;
  final bool isHost;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  final _localStreamCtrl = StreamController<MediaStream?>.broadcast();
  final _remoteStreamCtrl = StreamController<MediaStream?>.broadcast();

  Stream<MediaStream?> get onLocalStream => _localStreamCtrl.stream;
  Stream<MediaStream?> get onRemoteStream => _remoteStreamCtrl.stream;

  final List<StreamSubscription> _subs = [];
  final _db = FirebaseDatabase.instance;
  bool _remoteDescSet = false;

  static const _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  WebRTCService({required this.roomId, required this.isHost});

  Future<void> start() async {
    _localStream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': true});
    _localStreamCtrl.add(_localStream);

    _pc = await createPeerConnection(_iceConfig);

    for (final track in _localStream!.getTracks()) {
      _pc!.addTrack(track, _localStream!);
    }

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreamCtrl.add(event.streams.first);
      }
    };

    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _db.ref('signaling/$roomId/${isHost ? "hostCandidates" : "guestCandidates"}').push().set({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    if (isHost) {
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
    } else {
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
    if (isHost) {
      try { await _db.ref('signaling/$roomId').remove(); } catch (_) {}
    }
  }
}
