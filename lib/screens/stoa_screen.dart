import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cloud_corner_box.dart';
import '../widgets/side_menu.dart';
import 'room_screen.dart';
import 'host_wait_screen.dart';

const _kCategories = [
  'Philosophy', 'Politics', 'Science', 'Ethics',
  'Economics', 'History', 'Technology', 'Theology',
];

class StoaScreen extends StatefulWidget {
  const StoaScreen({super.key});
  @override
  State<StoaScreen> createState() => _StoaScreenState();
}

class _StoaScreenState extends State<StoaScreen>
    with TickerProviderStateMixin {

  // Snap-back animation
  late AnimationController _snapCtrl;
  late Animation<double>   _snapAnim;

  final _nameCtrl = TextEditingController();
  int    _cardIndex  = 0;
  double _dragOffset = 0;
  StreamSubscription? _matchSub;
  String? _currentCardRoomId;

  bool get _onboarded => context.read<AppState>().profile.name.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _snapAnim = const AlwaysStoppedAnimation(0);
    _snapCtrl.addListener(() {
      if (mounted) setState(() => _dragOffset = _snapAnim.value);
    });
    if (_onboarded) _listenForMatch();
    // Register callback so AppState snackbar can navigate here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().registerEnterRoomCallback(() {
        if (!mounted) return;
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoomScreen()));
      });
    });
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    _nameCtrl.dispose();
    _matchSub?.cancel();
    if (_currentCardRoomId != null) {
      context.read<AppState>().leaveStoaViewer(_currentCardRoomId!);
    }
    super.dispose();
  }

  void _listenForMatch() {
    _matchSub = context.read<AppState>().matchStream().listen((data) {
      if (data == null || !mounted) return;
      // isHost: true  → we are the argument host; _globalStoaWatcher handles entry
      // isHost: false → we are the challenger; navigate here
      final isHost = data['isHost'] as bool? ?? false;
      if (isHost) return;
      final state   = context.read<AppState>();
      final roomId  = data['roomId'] as String? ?? '';
      if (roomId.isEmpty) { state.markMatchHandled(); return; }
      // Guard: already in this room (stream can fire multiple times before
      // markMatchHandled() writes back to Firebase).
      if (state.currentRoom?.id == roomId) {
        state.markMatchHandled();
        return;
      }
      state.enterRoom(state.buildRoomFromMatch(data));
      state.markMatchHandled();
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoomScreen()));
    });
  }

  Future<void> _onboard() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    context.read<AppState>().setProfile(name: name, mode: AcroMode.stoa);
    setState(() {});
    _listenForMatch();
  }

  void _snapBack() {
    _snapAnim = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut));
    _snapCtrl.forward(from: 0);
  }

  void _animateOff(double target, VoidCallback onDone) {
    _snapAnim = Tween<double>(begin: _dragOffset, end: target).animate(
        CurvedAnimation(parent: _snapCtrl, curve: Curves.easeIn));
    _snapCtrl.forward(from: 0).then((_) {
      setState(() => _dragOffset = 0);
      onDone();
    });
  }

  void _skip(int total) {
    setState(() => _cardIndex = (_cardIndex + 1) % total);
  }

  Future<void> _challenge(Map<String, dynamic> room) async {
    await context.read<AppState>().joinStoaRoom(room);
  }

  void _openPostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => _PostSheet(
        canPost: context.read<AppState>().canCreateStoaRoom,
        onPost: (title, thesis, category) async {
          Navigator.pop(context);
          await context.read<AppState>().createStoaRoom(
              title: title, thesis: thesis, category: category);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) return _buildNameEntry();
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      endDrawer: const SideMenu(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('⚖  THE STOA',
            style: GoogleFonts.dmSans(
                color: AcroColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3)),
        actions: const [SideMenuButton(), SizedBox(width: 4)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPostSheet,
        backgroundColor: AcroColors.gold,
        foregroundColor: AcroColors.stone,
        icon: const Icon(Icons.add),
        label: Text('POST ARGUMENT',
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ),
      body: _buildFloor(),
    );
  }

  // ---------------------------------------------------------------------------
  // THE FLOOR
  // ---------------------------------------------------------------------------

  Widget _buildFloor() {
    return Consumer<AppState>(builder: (context, state, _) {
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: state.stoaRoomsStream(),
        builder: (ctx, snap) {
          final all = snap.data ?? [];
          return Stack(
            fit: StackFit.expand,
            children: [
              _stoaBackground(),
              all.isEmpty ? _emptyFloor(false) : _swipeArea(all),
            ],
          );
        },
      );
    });
  }

  Widget _stoaBackground() {
    const bg = Color(0xFF0B0F1A);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/stoaback.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            opacity: const AlwaysStoppedAnimation(0.48)),
        Positioned(
          top: 0, left: 0, right: 0,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.08, 0.72, 1.0],
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Transform.flip(
              flipY: true,
              child: Image.asset('assets/images/clouds.png',
                  fit: BoxFit.cover,
                  height: 55,
                  width: double.infinity,
                  opacity: const AlwaysStoppedAnimation(0.45)),
            ),
          ),
        ),
        // Bottom fade
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: [0.0, 0.30],
              colors: [bg, Colors.transparent],
            ),
          ),
        ),
        // Side fades
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.28],
              colors: [bg, Colors.transparent],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              stops: [0.0, 0.28],
              colors: [bg, Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _swipeArea(List<Map<String, dynamic>> rooms) {
    final idx   = _cardIndex % rooms.length;
    final room  = rooms[idx];
    final isOwn = room['hostUid'] == context.read<AppState>().profile.uid;

    // Viewer presence — fire after frame to avoid side effects during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final newId = room['roomId'] as String? ?? '';
      if (newId == _currentCardRoomId) return;
      final state = context.read<AppState>();
      if (_currentCardRoomId != null) state.leaveStoaViewer(_currentCardRoomId!);
      if (newId.isNotEmpty) state.joinStoaViewer(newId);
      _currentCardRoomId = newId;
    });

    return Column(children: [
      // Counter
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${idx + 1} / ${rooms.length}',
              style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.22))),
        ]),
      ),

      // Card — fills remaining space; buttons live below, never overlapping
      Expanded(
        child: Align(
          alignment: const Alignment(0, -0.20),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              _snapCtrl.stop();
              setState(() => _dragOffset += d.delta.dx);
            },
            onHorizontalDragEnd: (d) {
              final vel           = d.velocity.pixelsPerSecond.dx;
              final isParticipant = _isParticipant(room);
              final canChallenge  = !isOwn && room['matched'] != true && !isParticipant;
              final canRejoin     = !isOwn && isParticipant;
              if (_dragOffset > 80 || vel > 500) {
                _animateOff(500, () => _skip(rooms.length));
              } else if (canRejoin && (_dragOffset < -80 || vel < -500)) {
                _animateOff(-500, () => _rejoin(room));
              } else if (canChallenge && (_dragOffset < -80 || vel < -500)) {
                _animateOff(-500, () => _challenge(room));
              } else {
                _snapBack();
              }
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, _dragOffset.abs() * 0.04),
              child: Transform.rotate(
                angle: _dragOffset * 0.0022,
                child: Stack(alignment: Alignment.center, children: [
                  _roomCard(room),
                  if (_dragOffset > 28)
                    Positioned(top: 24, left: 24,
                        child: _badge('SKIP', Colors.white54)),
                  if (!isOwn && _dragOffset < -28) ...[
                    if (_isParticipant(room))
                      Positioned(top: 24, right: 24,
                          child: _badge('REJOIN', AcroColors.gold))
                    else if (room['matched'] != true)
                      Positioned(top: 24, right: 24,
                          child: _badge('CHALLENGE', AcroColors.gold)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),

      // Action buttons — always below the card, never overlapping
      Padding(
        padding: EdgeInsets.fromLTRB(28, 8, 28, kIsWeb ? 20 : 28),
        child: isOwn
            ? _ownCardFooter(room)
            : _challengerFooter(room, rooms.length),
      ),
    ]);
  }

  Widget _ownCardFooter(Map<String, dynamic> room) {
    final isMatched    = room['matched'] == true;
    final debateRoomId = room['debateRoomId'] as String?;
    final challengerCount = room['challengerCount'] as int? ?? 0;

    // Build display name from challengers map, fall back to stored challengerName
    final challengers = room['challengers'];
    String challengerName;
    if (challengers is Map && challengers.isNotEmpty) {
      final names = challengers.values
          .map((v) => v is Map ? (v['name'] as String? ?? '') : '')
          .where((n) => n.isNotEmpty)
          .toList();
      challengerName = names.join(', ');
    } else {
      challengerName = room['challengerName'] as String? ?? 'Challenger';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isMatched ? Colors.amberAccent : Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isMatched
                ? 'FULL  ·  $challengerName'
                : challengerCount > 0
                    ? '$challengerCount / 3 CHALLENGERS  ·  $challengerName'
                    : 'YOUR ARGUMENT  ·  LIVE',
            style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: AcroColors.gold.withOpacity(0.50),
                letterSpacing: 2),
          ),
        ]),
        if (isMatched && debateRoomId != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<AppState>().reenterRoom(
                      debateRoomId,
                      partnerName: challengerName,
                    );
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoomScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AcroColors.gold,
                foregroundColor: AcroColors.stone,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2)),
                textStyle: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
              ),
              child: const Text('ENTER DEBATE'),
            ),
          ),
        ],
      ],
    );
  }

  // Returns true if the current user is already a participant in this room
  // (i.e. they challenged it before and it's still in their active debates).
  bool _isParticipant(Map<String, dynamic> room) {
    final debateId = room['debateRoomId'] as String? ?? '';
    if (debateId.isEmpty) return false;
    return context.read<AppState>().activeDebates.any((d) => d['roomId'] == debateId);
  }

  void _rejoin(Map<String, dynamic> room) {
    final roomId = room['debateRoomId'] as String? ?? '';
    final title  = room['title']        as String? ?? 'Debate';
    if (roomId.isEmpty) return;
    context.read<AppState>().reenterRoom(roomId, title: title);
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RoomScreen()));
  }

  Widget _challengerFooter(Map<String, dynamic> room, int total) {
    final debateRoomId    = room['debateRoomId']    as String? ?? '';
    final title           = room['title']           as String? ?? 'Debate';
    final isMatched       = room['matched']         == true;
    // Room is 4/4 full when 3 challengers have joined (host + 3 = 4).
    final challengerCount = room['challengerCount'] as int? ?? 0;
    final isFull          = isMatched && challengerCount >= 3;
    final isParticipant   = _isParticipant(room);

    // Returning participant — offer REJOIN regardless of matched state.
    if (isParticipant && debateRoomId.isNotEmpty) {
      return Row(children: [
        if (isMatched) ...[
          Row(children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: Colors.amberAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('LIVE',
                style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    color: Colors.amberAccent.withOpacity(0.70),
                    letterSpacing: 2)),
          ]),
        ],
        const Spacer(),
        ElevatedButton(
          onPressed: () => _rejoin(room),
          style: ElevatedButton.styleFrom(
            backgroundColor: AcroColors.gold,
            foregroundColor: AcroColors.stone,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2)),
            textStyle: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2),
          ),
          child: const Text('REJOIN'),
        ),
      ]);
    }

    // Room is fully occupied (4/4) — offer spectating to 3rd parties.
    if (isFull && debateRoomId.isNotEmpty) {
      return Row(children: [
        Row(children: [
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
                color: Colors.amberAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('LIVE',
              style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: Colors.amberAccent.withOpacity(0.70),
                  letterSpacing: 2)),
        ]),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            context.read<AppState>().joinAsSpectator(debateRoomId, title);
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RoomScreen()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.07),
            foregroundColor: AcroColors.gold,
            side: BorderSide(color: AcroColors.gold.withOpacity(0.40)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2)),
            textStyle: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2),
          ),
          child: const Text('SPECTATE'),
        ),
      ]);
    }

    // Default: SKIP + CHALLENGE for new challengers on open rooms.
    final vPad = kIsWeb ? 9.0 : 14.0;
    final fSize = kIsWeb ? 11.0 : 12.0;

    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => _skip(total),
          style: OutlinedButton.styleFrom(
            foregroundColor: AcroColors.stoneLight,
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
            padding: EdgeInsets.symmetric(vertical: vPad),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2)),
          ),
          child: Text('SKIP',
              style: GoogleFonts.dmSans(
                  fontSize: fSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton(
          onPressed: () => _challenge(room),
          style: ElevatedButton.styleFrom(
            backgroundColor: AcroColors.gold,
            foregroundColor: AcroColors.stone,
            padding: EdgeInsets.symmetric(vertical: vPad),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2)),
            textStyle: GoogleFonts.dmSans(
                fontSize: fSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 2),
          ),
          child: const Text('CHALLENGE'),
        ),
      ),
    ]);
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final title           = room['title']          as String? ?? 'Untitled';
    final thesis          = room['thesis']         as String? ?? '';
    final hostName        = room['hostName']       as String? ?? 'Anonymous';
    final category        = room['category']       as String? ?? '';
    final ts              = room['ts']             as int?    ?? 0;
    final roomId       = room['roomId']         as String? ?? '';
    final debateRoomId = room['debateRoomId']  as String? ?? 'dr_$roomId';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CloudCornerBox(
          width: 320,
          padding: const EdgeInsets.all(28),
          borderColor: AcroColors.gold.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // ── Top row: category / viewers / countdown ──────────────────
          Row(children: [
            if (category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AcroColors.gold.withOpacity(0.28)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(category,
                    style: GoogleFonts.spaceMono(
                        fontSize: 9,
                        color: AcroColors.gold.withOpacity(0.70),
                        letterSpacing: 1.5)),
              ),
            const Spacer(),
            // Live viewer count (host excluded)
            StreamBuilder<int>(
              stream: context.read<AppState>().stoaViewerCountStream(
                    roomId, hostUid: room['hostUid'] as String? ?? ''),
              builder: (_, snap) {
                final n = snap.data ?? 0;
                if (n <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('$n here',
                      style: GoogleFonts.spaceMono(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.18))),
                );
              },
            ),
            Text(_countdown(ts),
                style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.22))),
            StreamBuilder<int>(
              stream: context.read<AppState>().roomPresenceCountStream(debateRoomId),
              builder: (_, snap) {
                final n = snap.data ?? 0;
                if (n <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: n >= 4
                          ? Colors.red.withOpacity(0.12)
                          : AcroColors.gold.withOpacity(0.08),
                      border: Border.all(
                        color: n >= 4
                            ? Colors.red.withOpacity(0.40)
                            : AcroColors.gold.withOpacity(0.30),
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text('$n / 4',
                        style: GoogleFonts.spaceMono(
                            fontSize: 9,
                            color: n >= 4
                                ? Colors.red.withOpacity(0.70)
                                : AcroColors.gold.withOpacity(0.70),
                            letterSpacing: 1)),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 18),

          // ── Title + thesis ────────────────────────────────────────────
          Text(title,
              style: GoogleFonts.cormorant(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3)),
          if (thesis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('"$thesis"',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.42),
                    fontStyle: FontStyle.italic,
                    height: 1.4)),
          ],
          const SizedBox(height: 22),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // ── Host + nominate ───────────────────────────────────────────
          Row(children: [
            AcroAvatar(
              initials: hostName.isNotEmpty ? hostName[0].toUpperCase() : '?',
              seed: room['hostUid'] as String? ?? hostName,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.60))),
            ),
            _NominateButton(
              room: room,
              isOwnRoom: room['hostUid'] ==
                  context.read<AppState>().profile.uid,
            ),
          ]),

          // ── Quote peek ────────────────────────────────────────────────
          Divider(height: 20, color: Colors.white.withOpacity(0.05)),
          _QuotePeek(roomId: roomId, room: room),
        ],
      ),
        ),
        Positioned(
          top: 0,
          left: -18,
          child: IgnorePointer(
            child: Image.asset(
              'assets/images/vine_asset.png',
              width: 36,
              fit: BoxFit.fitWidth,
              opacity: const AlwaysStoppedAnimation(0.88),
            ),
          ),
        ),
        Positioned(
          top: -12,
          left: -12,
          child: IgnorePointer(
            child: Transform.flip(
              flipY: true,
              child: RotatedBox(
                quarterTurns: 3,
                child: Image.asset(
                  'assets/images/vine_asset.png',
                  width: 23,
                  fit: BoxFit.fitWidth,
                  opacity: const AlwaysStoppedAnimation(0.88),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3)),
        child: Text(label,
            style: GoogleFonts.spaceMono(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      );

  Widget _emptyFloor(bool hasOwnRooms) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const Text('⚖', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          Text(
            hasOwnRooms
                ? 'Your argument is live.'
                : 'The floor is empty.',
            style: GoogleFonts.spaceMono(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 8),
          Text(
            hasOwnRooms
                ? 'Waiting for someone to challenge you.'
                : 'Tap + to post your argument.',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.2)),
          ),
        ]),
      );

  // ---------------------------------------------------------------------------
  // Name entry
  // ---------------------------------------------------------------------------

  Widget _buildNameEntry() => Scaffold(
        backgroundColor: const Color(0xFF0B0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0F1A),
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('⚖  THE STOA',
              style: GoogleFonts.dmSans(
                  color: AcroColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                border: Border.all(
                    color: AcroColors.gold.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENTER THE STOA',
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AcroColors.stoneLight,
                            letterSpacing: 3)),
                    const SizedBox(height: 4),
                    Text('State your name to take the floor.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.30))),
                    const SizedBox(height: 24),
                    Text('YOUR NAME',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.35),
                            letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      style: GoogleFonts.spaceMono(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Your full name…',
                        hintStyle: GoogleFonts.spaceMono(
                            color: Colors.white.withOpacity(0.22)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: BorderSide(
                                color:
                                    AcroColors.gold.withOpacity(0.2))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: BorderSide(
                                color:
                                    AcroColors.gold.withOpacity(0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide:
                                const BorderSide(color: AcroColors.gold)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onboard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AcroColors.gold,
                          foregroundColor: AcroColors.stone,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2)),
                          textStyle: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2),
                        ),
                        child: const Text('ENTER'),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      );

  String _countdown(int ts) {
    if (ts == 0) return '';
    final expiry = DateTime.fromMillisecondsSinceEpoch(ts)
        .add(const Duration(days: 40));
    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    if (remaining.inDays >= 1) return '${remaining.inDays}d left';
    if (remaining.inHours >= 1) return '${remaining.inHours}h left';
    return '${remaining.inMinutes}m left';
  }

}

// ── Post argument bottom sheet ─────────────────────────────────────────────

class _PostSheet extends StatefulWidget {
  final bool canPost;
  final Future<void> Function(String title, String thesis, String category) onPost;
  const _PostSheet({required this.canPost, required this.onPost});

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  final _titleCtrl  = TextEditingController();
  final _thesisCtrl = TextEditingController();
  String _category  = 'Philosophy';
  bool   _posting   = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _thesisCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _posting = true);
    await widget.onPost(title, _thesisCtrl.text.trim(), _category);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F1A),
          border: Border(
              top: BorderSide(
                  color: AcroColors.gold.withOpacity(0.30))),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: !widget.canPost
            ? _limitMsg()
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                Text('OPEN THE FLOOR',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AcroColors.stoneLight,
                        letterSpacing: 3)),
                const SizedBox(height: 20),

                _field(_titleCtrl, 'Argument title…'),
                _field(_thesisCtrl, 'Your position (optional)…',
                    maxLines: 2),

                // Category chips
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _kCategories.map((cat) {
                    final sel = _category == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel
                              ? AcroColors.gold.withOpacity(0.15)
                              : Colors.transparent,
                          border: Border.all(
                              color: sel
                                  ? AcroColors.gold
                                  : AcroColors.gold.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.spaceMono(
                                fontSize: 10,
                                color: sel
                                    ? AcroColors.gold
                                    : Colors.white.withOpacity(0.45))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _posting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AcroColors.gold,
                      foregroundColor: AcroColors.stone,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                      textStyle: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2),
                    ),
                    child: Text(
                        _posting ? 'POSTING…' : 'POST TO THE FLOOR'),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _limitMsg() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚖', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text('10-room limit reached.',
              style: GoogleFonts.spaceMono(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.45))),
          const SizedBox(height: 6),
          Text('Terminate rooms from the ledger (≡) first.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.25))),
        ]),
      );

  Widget _field(TextEditingController ctrl, String hint,
          {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceMono(
                color: Colors.white.withOpacity(0.25)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(
                    color: AcroColors.gold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(
                    color: AcroColors.gold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide:
                    const BorderSide(color: AcroColors.gold)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      );
}

// ── Nominate button ─────────────────────────────────────────────────────────

class _NominateButton extends StatefulWidget {
  final Map<String, dynamic> room;
  final bool isOwnRoom;
  const _NominateButton({required this.room, required this.isOwnRoom});

  @override
  State<_NominateButton> createState() => _NominateButtonState();
}

class _NominateButtonState extends State<_NominateButton> {
  bool _nominated = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  // Runs in background — button shows immediately, updates if already nominated
  Future<void> _check() async {
    final state  = context.read<AppState>();
    if (!state.isPermanentAccount) return;
    final roomId = widget.room['roomId'] as String? ?? '';
    final already = await state.hasNominated(roomId);
    if (mounted && already) setState(() => _nominated = true);
  }

  Future<void> _tap() async {
    final state = context.read<AppState>();
    if (!state.isPermanentAccount) {
      _showSignupSheet();
      return;
    }
    if (_nominated) return;
    setState(() => _nominated = true);
    try {
      await state.nominateStoaRoom(widget.room);
    } catch (_) {
      if (mounted) setState(() => _nominated = false);
    }
  }

  void _showSignupSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0F1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _NominateSignupSheet(
        onGoogleSignIn: () async {
          Navigator.pop(context);
          try {
            await context.read<AppState>().signInWithGoogle();
          } catch (_) {}
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwnRoom) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _nominated
              ? AcroColors.gold.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: _nominated
                ? AcroColors.gold.withOpacity(0.50)
                : Colors.white.withOpacity(0.15),
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _nominated ? Icons.stars : Icons.stars_outlined,
            size: 11,
            color: _nominated
                ? AcroColors.gold
                : Colors.white.withOpacity(0.55),
          ),
          const SizedBox(width: 4),
          Text(
            _nominated ? 'CANON' : 'NOMINATE',
            style: GoogleFonts.spaceMono(
              fontSize: 8,
              letterSpacing: 1,
              color: _nominated
                  ? AcroColors.gold
                  : Colors.white.withOpacity(0.55),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Signup prompt for temp users ─────────────────────────────────────────────

class _NominateSignupSheet extends StatelessWidget {
  final VoidCallback onGoogleSignIn;
  const _NominateSignupSheet({required this.onGoogleSignIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Text('NOMINATE TO THE CANON',
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AcroColors.stoneLight,
                  letterSpacing: 3)),
          const SizedBox(height: 8),
          Text(
            'Nominations are permanent — they send the argument to the Symposium for all time. A free account is required.',
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.38),
                height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGoogleSignIn,
              icon: const Icon(Icons.account_circle_outlined, size: 18),
              label: Text('CONTINUE WITH GOOGLE',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AcroColors.gold,
                foregroundColor: AcroColors.stone,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quote peek (card footer) ─────────────────────────────────────────────────

class _QuotePeek extends StatelessWidget {
  final String roomId;
  final Map<String, dynamic> room;
  const _QuotePeek({required this.roomId, required this.room});

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0F1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _QuoteSheet(
        roomId: roomId,
        roomTitle: room['title'] as String? ?? 'Argument',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AppState>().stoaQuotesStream(roomId),
      builder: (ctx, snap) {
        final count = snap.data?.length ?? 0;
        return GestureDetector(
          onTap: () => _open(context),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            const Text('👁', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text('QUOTE',
                style: GoogleFonts.spaceMono(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.28),
                    letterSpacing: 2)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text('· $count',
                  style: GoogleFonts.spaceMono(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.18))),
            ],
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 13, color: Colors.white.withOpacity(0.14)),
          ]),
        );
      },
    );
  }
}


// ── Quote thread bottom sheet ────────────────────────────────────────────────

class _QuoteSheet extends StatefulWidget {
  final String roomId;
  final String roomTitle;
  const _QuoteSheet({required this.roomId, required this.roomTitle});

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final _ctrl = TextEditingController();
  Set<String> _myBumps  = {};
  bool _loadingBumps    = true;
  bool _submitting      = false;

  @override
  void initState() {
    super.initState();
    _loadBumps();
  }

  Future<void> _loadBumps() async {
    final bumps =
        await context.read<AppState>().getUserBumps(widget.roomId);
    if (mounted) setState(() { _myBumps = bumps; _loadingBumps = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    await context.read<AppState>().addStoaQuote(widget.roomId, text);
    _ctrl.clear();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _toggleBump(String quoteId) async {
    final bumped = _myBumps.contains(quoteId);
    setState(() => bumped ? _myBumps.remove(quoteId) : _myBumps.add(quoteId));
    await context.read<AppState>()
        .bumpStoaQuote(widget.roomId, quoteId, bumped);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0F1A),
          border: Border(
              top: BorderSide(color: AcroColors.gold.withOpacity(0.30))),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(children: [
          // ── Handle ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              const Text('👁', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text('QUOTE',
                  style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AcroColors.stoneLight,
                      letterSpacing: 3)),
            ]),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(widget.roomTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.28))),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),

          // ── Quotes list ───────────────────────────────────────────────
          Flexible(
            child: _loadingBumps
                ? const SizedBox.shrink()
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: context
                        .read<AppState>()
                        .stoaQuotesStream(widget.roomId),
                    builder: (_, snap) {
                      final quotes = snap.data ?? [];
                      if (quotes.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('No quotes yet. Be the first.',
                                style: GoogleFonts.spaceMono(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.25))),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        itemCount: quotes.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 24),
                        itemBuilder: (_, i) {
                          final q   = quotes[i];
                          final qId = q['quoteId'] as String? ?? '';
                          return _quoteRow(q, _myBumps.contains(qId));
                        },
                      );
                    },
                  ),
          ),

          // ── Input ─────────────────────────────────────────────────────
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: GoogleFonts.spaceMono(
                      color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a quote or thought…',
                    hintStyle: GoogleFonts.spaceMono(
                        color: Colors.white.withOpacity(0.22),
                        fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2),
                        borderSide: BorderSide(
                            color: AcroColors.gold.withOpacity(0.2))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2),
                        borderSide: BorderSide(
                            color: AcroColors.gold.withOpacity(0.2))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2),
                        borderSide: const BorderSide(color: AcroColors.gold)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _submitting
                        ? AcroColors.gold.withOpacity(0.40)
                        : AcroColors.gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(Icons.arrow_upward,
                      size: 18, color: Color(0xFF0B0F1A)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _quoteRow(Map<String, dynamic> q, bool bumped) {
    final text       = q['text']       as String? ?? '';
    final authorName = q['authorName'] as String? ?? 'Anonymous';
    final bumps      = (q['bumps']     as int?)   ?? 0;
    final qId        = q['quoteId']    as String? ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(authorName,
                  style: GoogleFonts.spaceMono(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.28),
                      letterSpacing: 1.5)),
              const SizedBox(height: 5),
              Text('"$text"',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75),
                      fontStyle: FontStyle.italic,
                      height: 1.45)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () => _toggleBump(qId),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_upward,
                    size: 14,
                    color: bumped
                        ? AcroColors.gold.withOpacity(0.80)
                        : Colors.white.withOpacity(0.20)),
                if (bumps > 0)
                  Text('$bumps',
                      style: GoogleFonts.spaceMono(
                          fontSize: 8,
                          color: bumped
                              ? AcroColors.gold.withOpacity(0.60)
                              : Colors.white.withOpacity(0.20))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
