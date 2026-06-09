import 'dart:async';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/app_state.dart';
import '../services/webrtc_service.dart';
import '../models/debate_room.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/side_menu.dart';

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
  // hand raise animations: member name → unique trigger key
  final Map<String, int> _handRaising = {};
  // prevents re-triggering animation for already-seen messages on chat refresh
  final Set<int> _processedHandRaisedTs = {};
  // timestamp when user entered this session — used to hide pre-join system events
  late final int _joinedAt;
  Timer? _timer;
  int _timeLeft = 0;
  Timer? _turnTimer;
  int _turnLeft = 0;
  int _turnDuration = 0;
  bool _turnExpired = false;
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
    _joinedAt = DateTime.now().millisecondsSinceEpoch;
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
        state.sendRoomSystemEventFB(room.id, state.profile.name, state.profile.initials, 'joined the debate');
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
            final type   = m['type']   as String? ?? 'chat';
            final ts     = m['ts']     as int?    ?? 0;
            final pinned = m['pinned'] as bool?   ?? false;
            final fbKey  = m['_fbKey'] as String? ?? '';

            // Hide session events (joined / left / hand_raise) from before this session.
            // Pinned chat messages are always shown regardless of join time.
            final isSessionEvent = type == 'system' || type == 'hand_raise';
            if (isSessionEvent && !pinned && ts < _joinedAt) continue;

            // Trigger hand-raise animation once per unique event
            if (type == 'hand_raise' && _processedHandRaisedTs.add(ts)) {
              final name = m['name'] as String? ?? '';
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _triggerHandRaise(name);
              });
            }
            _messages.add(_ChatMsg(
              name:   m['name'] ?? '',
              ini:    m['ini']  ?? '?',
              text:   m['msg']  ?? '',
              isMe:   m['name'] == state.profile.name,
              type:   type,
              ts:     ts,
              fbKey:  fbKey,
              pinned: pinned,
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

  void _triggerHandRaise(String name) {
    final key = DateTime.now().millisecondsSinceEpoch;
    setState(() => _handRaising[name] = key);
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _handRaising.remove(name));
    });
  }

  Future<void> _startWebRTC() async {
    final room = context.read<AppState>().currentRoom;
    if (room == null) return;
    if (room.isSpectator) return; // spectators watch without a WebRTC connection
    _webrtc = WebRTCService(roomId: room.id, isHost: room.isHost);

    _localStreamSub = _webrtc!.onLocalStream.listen((stream) {
      if (!mounted) return;
      final hasVideo = stream != null && stream.getVideoTracks().isNotEmpty;
      setState(() {
        _localRenderer.srcObject = stream;
        _localReady = true;
        if (!hasVideo) _camOn = false;
      });
      if (!hasVideo) {
        final s = context.read<AppState>();
        final r = s.currentRoom;
        if (r != null) s.updateCameraPresenceFB(r.id, false);
      }
    });

    _remoteStreamSub = _webrtc!.onRemoteStream.listen((stream) {
      if (!mounted) return;
      setState(() { _remoteRenderer.srcObject = stream; _remoteReady = true; });
    });

    _peerDisconnectSub = _webrtc!.onPeerDisconnected.listen((_) {
      if (!mounted) return;
      setState(() { _remoteReady = false; _remoteRenderer.srcObject = null; });
      // Guest: peer (host) disconnected — reset so we accept the host's new
      // offer when they re-enter, rather than blocking on stale _remoteDescSet.
      _webrtc?.resetForNewPeer();
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

  String get _turnText {
    if (_turnLeft == 0) return '⏱ 0:00';
    final m = _turnLeft ~/ 60;
    final s = _turnLeft % 60;
    return '⏱ $m:${s.toString().padLeft(2, '0')}';
  }

  void _startTurnTimer(int seconds) {
    _turnTimer?.cancel();
    setState(() { _turnDuration = seconds; _turnLeft = seconds; _turnExpired = false; });
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_turnLeft <= 1) {
        _turnTimer?.cancel();
        setState(() { _turnLeft = 0; _turnExpired = true; });
        _playTimesUpSound();
      } else {
        setState(() => _turnLeft--);
      }
    });
  }

  void _showTurnPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0E17),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TIMED TURNS',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in [30, 60, 90, 120])
                    GestureDetector(
                      onTap: () { Navigator.pop(context); _startTurnTimer(s); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: _turnDuration == s
                              ? AcroColors.gold.withOpacity(0.15)
                              : Colors.transparent,
                          border: Border.all(
                              color: _turnDuration == s
                                  ? AcroColors.gold
                                  : Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s < 60 ? '${s}s' : '${s ~/ 60} min',
                          style: TextStyle(
                              color: _turnDuration == s
                                  ? AcroColors.gold
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (_turnDuration > 0)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _turnTimer?.cancel();
                        setState(() {
                          _turnDuration = 0;
                          _turnLeft = 0;
                          _turnExpired = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('OFF',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playTimesUpSound() {
    try {
      final script = html.ScriptElement()
        ..text = '(function(){'
            'var c=new(window.AudioContext||window.webkitAudioContext)();'
            'var o=c.createOscillator(),g=c.createGain();'
            'o.type="sine";'
            'o.connect(g);g.connect(c.destination);'
            'var t=c.currentTime;'
            'o.frequency.setValueAtTime(880,t);'
            'o.frequency.setValueAtTime(660,t+0.13);'
            'o.frequency.setValueAtTime(440,t+0.26);'
            'g.gain.setValueAtTime(0.45,t);'
            'g.gain.exponentialRampToValueAtTime(0.001,t+0.5);'
            'o.start(t);o.stop(t+0.5);'
            '})()';
      html.document.head!.append(script);
      Future.delayed(const Duration(milliseconds: 700), script.remove);
    } catch (_) {}
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
    _turnTimer?.cancel();
    final state     = context.read<AppState>();
    final room      = state.currentRoom;
    final messenger = ScaffoldMessenger.of(context);
    if (room != null && !room.isSpectator) {
      state.sendRoomSystemEventFB(room.id, state.profile.name, state.profile.initials, 'left the debate');
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
    _turnTimer?.cancel();
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

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF09080F),
      endDrawer: const SideMenu(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        leading: TextButton(
          onPressed: _leave,
          child: const Row(
            children: [
              Icon(Icons.chevron_left, color: Colors.white54, size: 16),
              Text('Floor', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                style: const TextStyle(
                    fontSize: 12,
                    color: AcroColors.gold,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('${room.members.length}/${room.capacity}',
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(width: 8),
          if (!isMobile)
            IconButton(
              icon: Icon(Icons.chat_bubble_outline,
                  color: _chatVisible ? AcroColors.gold : Colors.white54),
              onPressed: () => setState(() => _chatVisible = !_chatVisible),
            ),
          const SideMenuButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: isMobile
          // ── Mobile: full-screen split + sliding chat overlay ──────────────
          ? Builder(builder: (ctx) {
              final chatW = MediaQuery.of(ctx).size.width * 0.62;
              final screenH = MediaQuery.of(ctx).size.height;
              final chatH = screenH * 0.50;
              final chatTop = screenH * 0.15;
              return Stack(
                children: [
                  // Edge-to-edge split video
                  Positioned.fill(child: _buildMobileVideoSplit(room)),
                  // Faded chat panel — centred between the two split tiles
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    right: _chatVisible ? 0 : -chatW,
                    top: chatTop, height: chatH, width: chatW,
                    child: _buildMobileChatPanel(room),
                  ),
                  // Recall tab — visible on right edge when chat is hidden
                  if (!_chatVisible)
                    Positioned(
                      right: 0,
                      top: screenH * 0.37,
                      child: GestureDetector(
                        onTap: () => setState(() => _chatVisible = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0E17).withOpacity(0.85),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                            border: Border(
                              left:   BorderSide(color: Colors.white.withOpacity(0.12)),
                              top:    BorderSide(color: Colors.white.withOpacity(0.08)),
                              bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 16, color: AcroColors.gold),
                              const SizedBox(height: 6),
                              RotatedBox(
                                quarterTurns: 1,
                                child: Text('CHAT',
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.white.withOpacity(0.50),
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            })
          // ── Web: side-by-side video + chat panel ──────────────────────────
          : Row(
              children: [
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
                        _buildPinnedSection(_messages.where((m) => m.pinned && m.type == 'chat').toList()),
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
                  final s = context.read<AppState>();
                  s.sendRoomSystemEventFB(s.currentRoom!.id, s.profile.name, s.profile.initials,
                      _micOn ? 'unmuted their microphone' : 'muted their microphone');
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
                  final s = context.read<AppState>();
                  s.updateCameraPresenceFB(s.currentRoom!.id, _camOn);
                  s.sendRoomSystemEventFB(s.currentRoom!.id, s.profile.name, s.profile.initials,
                      _camOn ? 'turned on camera' : 'turned off camera');
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
                  final wasRaised = _handRaised;
                  setState(() => _handRaised = !_handRaised);
                  if (!wasRaised) {
                    // Broadcast to all participants via chat channel
                    final s = context.read<AppState>();
                    s.sendHandRaiseEventFB(
                        s.currentRoom!.id, s.profile.name, s.profile.initials);
                  }
                },
              ),
              // ── Turn timer button ──────────────────────────────────────
              GestureDetector(
                onTap: () {
                  if (_turnDuration > 0) {
                    // stop / reset
                    _turnTimer?.cancel();
                    setState(() { _turnDuration = 0; _turnLeft = 0; _turnExpired = false; });
                  } else {
                    _showTurnPicker();
                  }
                },
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _turnExpired
                        ? AcroColors.redLight.withOpacity(0.20)
                        : _turnDuration > 0 && _turnLeft <= 10
                            ? AcroColors.redLight.withOpacity(0.15)
                            : Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                    boxShadow: _turnExpired
                        ? [BoxShadow(color: AcroColors.redLight.withOpacity(0.35), blurRadius: 12, spreadRadius: 1)]
                        : null,
                  ),
                  child: _turnExpired
                      ? const _RingingClockIcon()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.alarm,
                                color: _turnDuration > 0 && _turnLeft <= 10
                                    ? AcroColors.redLight
                                    : Colors.white,
                                size: _turnDuration > 0 ? 13 : 18),
                            if (_turnDuration > 0) ...[
                              const SizedBox(height: 1),
                              Text(
                                _turnText.replaceFirst('⏱ ', ''),
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _turnLeft <= 10
                                        ? AcroColors.redLight
                                        : Colors.white),
                              ),
                            ],
                          ],
                        ),
                ),
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

  static const _avColors = [AvatarStyle.gold, AvatarStyle.stone, AvatarStyle.red, AvatarStyle.green, AvatarStyle.blue];

  Widget _buildTile(DebateRoom room, int i, String myName, double avatarSize,
      {BorderRadius? borderRadius}) {
    final m = room.members[i];
    final isMe = m.name == myName;
    final showVideo = isMe ? (_localReady && _camOn) : (_remoteReady && m.camOn);
    final renderer = isMe ? _localRenderer : _remoteRenderer;
    final br = borderRadius ?? BorderRadius.circular(11);

    return ClipRRect(
      borderRadius: br,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1510), Color(0xFF2C2820)],
          ),
          borderRadius: br,
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
                    AnimatedGhostAvatar(
                        initials: m.initials,
                        seed: m.name,
                        size: avatarSize,
                        style: _avColors[i % _avColors.length]),
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
            if (_handRaising.containsKey(m.name))
              _HandRaiseOverlay(key: ValueKey(_handRaising[m.name])),
            if (isMe && _turnExpired)
              _TurnExpiredClockOverlay(key: ValueKey('clock_$_turnDuration')),
          ],
        ),
      ),
    );
  }

  // Web: padded grid layout
  Widget _buildVideoGrid(DebateRoom room) {
    final n = room.members.length;
    final myName = context.read<AppState>().profile.name;
    final avatarSize = n <= 2 ? 60.0 : n <= 4 ? 48.0 : 38.0;
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: n <= 1 ? 1 : n <= 4 ? 2 : 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: n,
      itemBuilder: (_, i) => _buildTile(room, i, myName, avatarSize),
    );
  }

  // Mobile: edge-to-edge vertical split
  Widget _buildMobileVideoSplit(DebateRoom room) {
    final n = room.members.length;
    final myName = context.read<AppState>().profile.name;
    if (n == 0) return const SizedBox.expand();

    // 1: full screen
    if (n == 1) {
      return _buildTile(room, 0, myName, 80, borderRadius: BorderRadius.zero);
    }
    // 2/4: equal halves
    if (n == 2) {
      return Column(children: [
        Expanded(child: _buildTile(room, 0, myName, 72, borderRadius: BorderRadius.zero)),
        const SizedBox(height: 2),
        Expanded(child: _buildTile(room, 1, myName, 72, borderRadius: BorderRadius.zero)),
      ]);
    }
    // 3/4: equal thirds stacked
    if (n == 3) {
      return Column(children: [
        Expanded(child: _buildTile(room, 0, myName, 56, borderRadius: BorderRadius.zero)),
        const SizedBox(height: 2),
        Expanded(child: _buildTile(room, 1, myName, 56, borderRadius: BorderRadius.zero)),
        const SizedBox(height: 2),
        Expanded(child: _buildTile(room, 2, myName, 56, borderRadius: BorderRadius.zero)),
      ]);
    }
    // 4/4: 2×2 quarters
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: n,
      itemBuilder: (_, i) => _buildTile(room, i, myName, 52, borderRadius: BorderRadius.zero),
    );
  }

  // Mobile: semi-transparent chat overlay panel
  Widget _buildMobileChatPanel(DebateRoom room) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E17).withOpacity(0.63),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14)),
        border: Border(
          left:   BorderSide(color: Colors.white.withOpacity(0.10)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_right, size: 15, color: Colors.white54),
                        SizedBox(width: 2),
                        Text('Hide', style: TextStyle(fontSize: 11, color: Colors.white38)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildPinnedSection(_messages.where((m) => m.pinned && m.type == 'chat').toList()),
          Expanded(
            child: ListView.builder(
              controller: _chatScroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildChatBubble(_messages[i]),
            ),
          ),
          if (!room.isSpectator)
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
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(color: AcroColors.gold),
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
    );
  }

  Widget _buildChatBubble(_ChatMsg msg) {
    // System events: joined / left / hand raise
    if (msg.type == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            '${msg.isMe ? 'You' : msg.name} ${msg.text}',
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.35), fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    if (msg.type == 'hand_raise') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.back_hand, size: 13, color: AcroColors.gold),
            const SizedBox(width: 5),
            Text(
              '${msg.isMe ? 'You' : msg.name} raised their hand',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _pinMessage(msg),
      child: Padding(
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg.type == 'chat')
                      GestureDetector(
                        onTap: () => _pinMessage(msg),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin,
                            size: 10,
                            color: msg.pinned
                                ? AcroColors.gold
                                : Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                    Text(msg.isMe ? 'You' : msg.name,
                        style: const TextStyle(fontSize: 10, color: Colors.white30)),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: msg.pinned
                        ? AcroColors.gold.withOpacity(0.12)
                        : msg.isMe
                            ? AcroColors.gold.withOpacity(0.18)
                            : Colors.white.withOpacity(0.07),
                    border: msg.pinned
                        ? Border.all(color: AcroColors.gold.withOpacity(0.25))
                        : null,
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
      ),
    );
  }

  // Pinned messages bar shown at top of chat panels
  Widget _buildPinnedSection(List<_ChatMsg> pinned) {
    if (pinned.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        color: AcroColors.gold.withOpacity(0.07),
        border: Border(bottom: BorderSide(color: AcroColors.gold.withOpacity(0.15))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.push_pin, size: 11, color: AcroColors.gold),
                const SizedBox(width: 5),
                Text('Pinned (${pinned.length})',
                    style: const TextStyle(fontSize: 10, color: AcroColors.gold, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ],
            ),
          ),
          ...pinned.map((m) => GestureDetector(
            onTap: () => _pinMessage(m),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.push_pin, size: 9, color: AcroColors.gold),
                  const SizedBox(width: 5),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${m.isMe ? 'You' : m.name}: ',
                            style: const TextStyle(fontSize: 10, color: AcroColors.gold, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: m.text,
                            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.65)),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _pinMessage(_ChatMsg msg) {
    if (msg.fbKey.isEmpty || _roomId == null) return;
    final s = context.read<AppState>();
    s.pinRoomMessageFB(_roomId!, msg.fbKey, !msg.pinned);
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
  final String name, ini, text, fbKey;
  final bool isMe, pinned;
  final String type;
  final int ts;
  _ChatMsg({
    required this.name,
    required this.ini,
    required this.text,
    required this.isMe,
    this.type   = 'chat',
    this.ts     = 0,
    this.fbKey  = '',
    this.pinned = false,
  });
}

// Ringing alarm clock icon shown in the turn timer button when time is up.
class _RingingClockIcon extends StatefulWidget {
  const _RingingClockIcon();
  @override
  State<_RingingClockIcon> createState() => _RingingClockIconState();
}

class _RingingClockIconState extends State<_RingingClockIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shake;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550))
      ..repeat(reverse: true);
    _shake = Tween<double>(begin: -0.28, end: 0.28)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _fade = Tween<double>(begin: 0.25, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.rotate(angle: _shake.value, child: child),
      ),
      child: const Icon(Icons.alarm, color: AcroColors.redLight, size: 20),
    );
  }
}

// Pixel-art clock that fades in/out on the local cam tile when turn expires.
class _TurnExpiredClockOverlay extends StatefulWidget {
  const _TurnExpiredClockOverlay({super.key});
  @override
  State<_TurnExpiredClockOverlay> createState() => _TurnExpiredClockOverlayState();
}

class _TurnExpiredClockOverlayState extends State<_TurnExpiredClockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // fade-in 250ms → hold 1000ms → fade-out 250ms → pause 300ms → repeat
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 14),
      TweenSequenceItem(tween: ConstantTween(1.0),           weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 14),
      TweenSequenceItem(tween: ConstantTween(0.0),           weight: 17),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: _opacity.value,
            child: const Center(child: _PixelClock(size: 210)),
          ),
        ),
      ),
    );
  }
}

// High-density pixel-art clock (40×40 grid) with Bresenham hands + tick marks.
class _PixelClock extends StatelessWidget {
  const _PixelClock({this.size = 210});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: const _PixelClockFace(),
      );
}

class _PixelClockFace extends CustomPainter {
  const _PixelClockFace();
  static const _n = 40;

  // Bresenham line → stream of (col, row) pairs
  static Iterable<(int, int)> _line(
      double x0, double y0, double x1, double y1) sync* {
    int x = x0.round(), y = y0.round();
    final ex = x1.round(), ey = y1.round();
    final dx = (ex - x).abs(), dy = -(ey - y).abs();
    final sx = x <= ex ? 1 : -1, sy = y <= ey ? 1 : -1;
    var err = dx + dy;
    while (true) {
      yield (x, y);
      if (x == ex && y == ey) break;
      final e2 = 2 * err;
      if (e2 >= dy) { err += dy; x += sx; }
      if (e2 <= dx) { err += dx; y += sy; }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pw = size.width  / _n;
    final ph = size.height / _n;
    const cx = (_n - 1) / 2.0; // 19.5
    const cy = (_n - 1) / 2.0; // 19.5
    const r  = 17.5;

    final p = Paint()..style = PaintingStyle.fill..color = AcroColors.gold;
    void dot(int x, int y) {
      if (x < 0 || x >= _n || y < 0 || y >= _n) return;
      canvas.drawRect(Rect.fromLTWH(x * pw, y * ph, pw - 1.0, ph - 1.0), p);
    }
    void seg(double x0, double y0, double x1, double y1) {
      for (final (x, y) in _line(x0, y0, x1, y1)) dot(x, y);
    }

    // Circular border — 2px thick
    for (int x = 0; x < _n; x++) {
      for (int y = 0; y < _n; y++) {
        final d = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        if ((d - r).abs() < 1.3) dot(x, y);
      }
    }

    // 12 tick marks — major (12/3/6/9) longer, minor shorter
    for (int h = 0; h < 12; h++) {
      final θ     = h * pi / 6;
      final major = h % 3 == 0;
      final rO = r - 1.5;
      final rI = rO - (major ? 3.5 : 1.8);
      seg(cx + rO * sin(θ), cy - rO * cos(θ),
          cx + rI * sin(θ), cy - rI * cos(θ));
    }

    // Minute hand — pointing to 12 (straight up), long
    seg(cx, cy, cx, cy - 13.0);

    // Hour hand — pointing to 10 (classic 10:10 open-arm position)
    const ha = 10.0 * pi / 6.0; // 300° clockwise from top
    seg(cx, cy, cx + 8.0 * sin(ha), cy - 8.0 * cos(ha));

    // Centre dot 3×3
    for (int dx = -1; dx <= 1; dx++)
      for (int dy = -1; dy <= 1; dy++)
        dot(cx.round() + dx, cy.round() + dy);
  }

  @override
  bool shouldRepaint(_PixelClockFace _) => false;
}

// Pulsing ring shown on the local tile when the turn timer expires.
class _TurnExpiredRing extends StatefulWidget {
  const _TurnExpiredRing();
  @override
  State<_TurnExpiredRing> createState() => _TurnExpiredRingState();
}

class _TurnExpiredRingState extends State<_TurnExpiredRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Positioned.fill(
        child: IgnorePointer(
          child: Opacity(
            opacity: _opacity.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AcroColors.redLight, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AcroColors.redLight.withOpacity(0.55),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Rising-hand animation overlaid on a participant's video tile.
class _HandRaiseOverlay extends StatefulWidget {
  const _HandRaiseOverlay({super.key});
  @override
  State<_HandRaiseOverlay> createState() => _HandRaiseOverlayState();
}

class _HandRaiseOverlayState extends State<_HandRaiseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;   // bottom offset: 20 → 90
  late final Animation<double> _opacity; // 1.0 → 0.0, starts fading at 50%

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _slide   = Tween<double>(begin: 60, end: 270).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 1.0, curve: Curves.easeIn)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: 0, right: 0,
        bottom: _slide.value,
        child: IgnorePointer(
          child: Opacity(
            opacity: _opacity.value,
            child: const Center(
              child: Text('✋', style: TextStyle(fontSize: 114)),
            ),
          ),
        ),
      ),
    );
  }
}
