import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/app_state.dart';
import '../services/webrtc_service.dart';
import '../models/debate_room.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  bool _micOn = true;
  bool _camOn = true;
  bool _chatVisible = true;
  bool _handRaised = false;
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  final List<_ChatMsg> _messages = [];
  Timer? _timer;
  int _timeLeft = 0;
  StreamSubscription? _chatSub;

  WebRTCService? _webrtc;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _localReady = false;
  bool _remoteReady = false;
  StreamSubscription? _localStreamSub;
  StreamSubscription? _remoteStreamSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _peerDisconnectSub;
  StreamSubscription? _roomLiveSub;
  String? _roomId;
  bool _isSpectator = false;
  bool _leftExplicitly = false;
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    Future.wait([_localRenderer.initialize(), _remoteRenderer.initialize()])
        .then((_) => _startWebRTC());

    final state = context.read<AppState>();
    _appState = state;
    final room = state.currentRoom;
    if (room != null) {
      _roomId      = room.id;
      _isSpectator = room.isSpectator;

      if (!room.isSpectator) {
        state.writeRoomPresence(room.id, isHost: room.isHost);
        _presenceSub = state.roomPresenceStream(room.id).listen((members) {
          if (!mounted) return;
          state.updateRoomMembers(room.id, members);
        });
      }

      // Guests and spectators watch for the host ending the room.
      if (!room.isHost) {
        _roomLiveSub = state.roomLiveStream(room.id).listen((live) {
          if (!live && mounted) _ejectFromRoom();
        });
      }

      _startTimer(room);
      _chatSub = state.listenToRoomChat(room.id, (msgs) {
        if (!mounted) return;
        setState(() {
          _messages.clear();
          for (final m in msgs) {
            _messages.add(_ChatMsg(
              name: m['name'] ?? '',
              ini: m['ini'] ?? '?',
              text: m['msg'] ?? '',
              isMe: m['name'] == state.profile.name,
            ));
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScroll.hasClients) {
            _chatScroll.animateTo(_chatScroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          }
        });
      });
    }
  }

  Future<void> _startWebRTC() async {
    final room = context.read<AppState>().currentRoom;
    if (room == null) return;
    if (room.isSpectator) return; // spectators watch without a WebRTC connection
    _webrtc = WebRTCService(roomId: room.id, isHost: room.isHost);

    _localStreamSub = _webrtc!.onLocalStream.listen((stream) {
      if (!mounted) return;
      setState(() { _localRenderer.srcObject = stream; _localReady = true; });
    });

    _remoteStreamSub = _webrtc!.onRemoteStream.listen((stream) {
      if (!mounted) return;
      setState(() { _remoteRenderer.srcObject = stream; _remoteReady = true; });
    });

    _peerDisconnectSub = _webrtc!.onPeerDisconnected.listen((_) {
      if (!mounted) return;
      setState(() { _remoteReady = false; _remoteRenderer.srcObject = null; });
    });

    try {
      await _webrtc!.start();
    } catch (_) {
      // Camera permission denied or unavailable — avatars shown as fallback
    }
  }

  void _startTimer(DebateRoom room) {
    if (room.durationSeconds == 0) return;
    _timeLeft = room.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft <= 0) {
        _timer?.cancel();
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Time is up! Debate concluded.')));
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  String get _timerText {
    if (_timeLeft == 0) {
      final room = context.read<AppState>().currentRoom;
      return room?.durationSeconds == 0 ? '⏱ Open' : '⏱ 0:00';
    }
    final m = _timeLeft ~/ 60;
    final s = _timeLeft % 60;
    return '⏱ $m:${s.toString().padLeft(2, '0')}';
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    final state = context.read<AppState>();
    final room = state.currentRoom;
    if (room == null) return;
    _chatCtrl.clear();
    state.sendRoomChatFB(room.id, state.profile.name, state.profile.initials, text);
  }

  void _leave() {
    _leftExplicitly = true;
    _timer?.cancel();
    final state     = context.read<AppState>();
    final room      = state.currentRoom;
    final messenger = ScaffoldMessenger.of(context);
    if (room != null && !room.isSpectator) {
      state.leaveRoomFB(room.id);
      // Host leaving no longer ends the room — guests stay until they leave.
    }
    Navigator.pop(context);
    state.leaveRoom(); // after pop — prevents blank flash during exit animation
    messenger.showSnackBar(
        const SnackBar(content: Text('You have left the debate room.')));
  }

  // Called when Firebase signals the host ended the room.
  void _ejectFromRoom() {
    if (_leftExplicitly) return;
    _leftExplicitly = true;
    _timer?.cancel();
    _roomLiveSub?.cancel();
    final state     = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    if (!_isSpectator && _roomId != null) state.leaveRoomFB(_roomId!);
    Navigator.pop(context);
    state.leaveRoom(); // after pop — prevents blank flash during exit animation
    messenger.showSnackBar(
        const SnackBar(content: Text('The host ended the debate.')));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chatSub?.cancel();
    _presenceSub?.cancel();
    _peerDisconnectSub?.cancel();
    _roomLiveSub?.cancel();
    _localStreamSub?.cancel();
    _remoteStreamSub?.cancel();
    _webrtc?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    // Safety net: remove presence if widget is disposed without _leave() (e.g. system back).
    // Skipped when _leave() already removed it, preventing a race where dispose() fires
    // after the new RoomScreen's initState has already re-written presence.
    if (!_isSpectator && !_leftExplicitly && _roomId != null) {
      _appState?.leaveRoomFB(_roomId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<AppState>().currentRoom;
    if (room == null) return const SizedBox();

    // reenterRoom() initially sets isHost=false then corrects it async.
    // Once the correction arrives, drop the live-end watcher — hosts never
    // get ejected by it and it would fire incorrectly if endRoomFB runs.
    if (room.isHost && _roomLiveSub != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _roomLiveSub?.cancel();
        _roomLiveSub = null;
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09080F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        leading: TextButton(
          onPressed: _leave,
          child: const Row(
            children: [
              Icon(Icons.chevron_left, color: Colors.white54, size: 16),
              Text('Lobby', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        leadingWidth: 90,
        title: Text(room.title,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (room.isSpectator)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.10),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.35)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('WATCHING',
                  style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
            decoration: BoxDecoration(
              color: AcroColors.gold.withOpacity(0.1),
              border: Border.all(color: AcroColors.gold.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(_timerText,
                style: const TextStyle(fontSize: 12, color: AcroColors.gold, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('${room.members.length}/${room.capacity}',
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline,
                color: _chatVisible ? AcroColors.gold : Colors.white54),
            onPressed: () => setState(() => _chatVisible = !_chatVisible),
          ),
        ],
      ),
      body: Row(
        children: [
          // Video grid
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildVideoGrid(room)),
                if (room.desc.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: AcroColors.gold.withOpacity(0.07),
                      border: Border(top: BorderSide(color: AcroColors.gold.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: AcroColors.gold, size: 13),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(room.desc,
                              style: const TextStyle(fontSize: 12, color: AcroColors.goldLight)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Chat panel
          if (_chatVisible)
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0E17),
                border: Border(left: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.forum, size: 14, color: Colors.white54),
                        const SizedBox(width: 5),
                        const Text('Debate Chat',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white60)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _chatVisible = false),
                          child: const Icon(Icons.close, size: 16, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _chatScroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildChatBubble(_messages[i]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            onSubmitted: (_) => _sendChat(),
                            decoration: InputDecoration(
                              hintText: 'Argue your point…',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: AcroColors.gold),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        GestureDetector(
                          onTap: _sendChat,
                          child: Container(
                            width: 30, height: 30,
                            decoration: const BoxDecoration(color: AcroColors.gold, shape: BoxShape.circle),
                            child: const Icon(Icons.send, size: 12, color: AcroColors.stone),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),

      // Controls
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0E17),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: SafeArea(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 9,
            children: [
              if (!room.isSpectator) ...[
              _ctrlBtn(
                icon: _micOn ? Icons.mic : Icons.mic_off,
                active: _micOn,
                onTap: () {
                  setState(() => _micOn = !_micOn);
                  _webrtc?.toggleMic(_micOn);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_micOn ? 'Microphone on' : 'Muted')));
                },
              ),
              _ctrlBtn(
                icon: _camOn ? Icons.videocam : Icons.videocam_off,
                active: _camOn,
                onTap: () {
                  setState(() => _camOn = !_camOn);
                  _webrtc?.toggleCamera(_camOn);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_camOn ? 'Camera on' : 'Camera off')));
                },
              ),
              ],
              _ctrlBtn(
                icon: Icons.back_hand_outlined,
                color: AcroColors.gold.withOpacity(0.15),
                iconColor: _handRaised ? AcroColors.stone : AcroColors.gold,
                active: true,
                onTap: () {
                  setState(() => _handRaised = !_handRaised);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_handRaised ? '✋ Hand raised — host notified' : 'Hand lowered')));
                },
              ),
              GestureDetector(
                onTap: _leave,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AcroColors.red.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_disabled, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Leave', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoGrid(DebateRoom room) {
    final members = room.members;
    final n = members.length;
    final avColors = [AvatarStyle.gold, AvatarStyle.stone, AvatarStyle.red, AvatarStyle.green, AvatarStyle.blue];
    final myName = context.read<AppState>().profile.name;

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: n <= 1 ? 1 : n <= 4 ? 2 : 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: n,
      itemBuilder: (_, i) {
        final m = members[i];
        final isMe = m.name == myName;
        final showVideo = isMe ? (_localReady && _camOn) : _remoteReady;
        final renderer = isMe ? _localRenderer : _remoteRenderer;

        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1510), Color(0xFF2C2820)],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isMe
                    ? AcroColors.green.withOpacity(0.45)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showVideo)
                  RTCVideoView(renderer,
                      mirror: isMe,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AcroAvatar(
                            initials: m.initials,
                            seed: m.name,
                            size: n <= 2 ? 60 : n <= 4 ? 48 : 38,
                            style: avColors[i % avColors.length]),
                        const SizedBox(height: 8),
                        Text(isMe ? 'You (${m.initials})' : m.name,
                            style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      ],
                    ),
                  ),
                if (m.isHost)
                  Positioned(
                    top: 7, right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AcroColors.gold.withOpacity(0.15),
                        border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('HOST',
                          style: TextStyle(fontSize: 9, color: AcroColors.gold, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ),
                  ),
                Positioned(
                  bottom: 7, left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(m.isHost ? 'Host' : isMe ? 'You' : 'Guest',
                        style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  ),
                ),
                if (!_micOn && isMe)
                  const Positioned(
                    bottom: 7, right: 7,
                    child: Icon(Icons.mic_off, size: 12, color: AcroColors.redLight),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatBubble(_ChatMsg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isMe) ...[
            AcroAvatar(initials: msg.ini, size: 22, style: AvatarStyle.stone),
            const SizedBox(width: 7),
          ],
          Column(
            crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(msg.isMe ? 'You' : msg.name,
                  style: const TextStyle(fontSize: 10, color: Colors.white30)),
              const SizedBox(height: 2),
              Container(
                constraints: const BoxConstraints(maxWidth: 180),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: msg.isMe
                      ? AcroColors.gold.withOpacity(0.18)
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(11),
                    topRight: const Radius.circular(11),
                    bottomLeft: msg.isMe ? const Radius.circular(11) : const Radius.circular(3),
                    bottomRight: msg.isMe ? const Radius.circular(3) : const Radius.circular(11),
                  ),
                ),
                child: Text(msg.text,
                    style: TextStyle(
                        fontSize: 12,
                        color: msg.isMe ? AcroColors.goldLight : Colors.white70,
                        height: 1.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    Color? color,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: !active
              ? AcroColors.red
              : color ?? Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 16),
      ),
    );
  }
}

class _ChatMsg {
  final String name, ini, text;
  final bool isMe;
  _ChatMsg({required this.name, required this.ini, required this.text, required this.isMe});
}
