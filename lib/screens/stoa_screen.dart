import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/side_menu.dart';
import 'room_screen.dart';

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
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    _nameCtrl.dispose();
    _matchSub?.cancel();
    super.dispose();
  }

  void _listenForMatch() {
    _matchSub = context.read<AppState>().matchStream().listen((data) {
      if (data != null && mounted) {
        final state = context.read<AppState>();
        if (state.myStoaRoomIds.isEmpty) {
          state.enterRoom(state.buildRoomFromMatch(data));
          state.clearMatch();
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RoomScreen()));
        }
      }
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

          // My live rooms → compact banner
          final myRooms = all
              .where((r) => r['hostUid'] == state.profile.uid)
              .toList();

          // Others' rooms → swipe stack
          final others = all
              .where((r) => r['hostUid'] != state.profile.uid)
              .toList();

          return Column(children: [
            // ── Your live room(s) indicator ───────────────────────────
            if (myRooms.isNotEmpty) _myRoomsBanner(myRooms, state),

            // ── Swipe cards ───────────────────────────────────────────
            Expanded(
              child: others.isEmpty
                  ? _emptyFloor(myRooms.isNotEmpty)
                  : _swipeArea(others),
            ),
          ]);
        },
      );
    });
  }

  Widget _myRoomsBanner(List<Map<String, dynamic>> rooms, AppState state) {
    final count = rooms.length;
    final title = count == 1
        ? (rooms.first['title'] as String? ?? 'Your argument')
        : '$count arguments on the floor';
    return GestureDetector(
      onTap: () => Scaffold.of(context).openEndDrawer(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AcroColors.gold.withOpacity(0.07),
          border: Border.all(color: AcroColors.gold.withOpacity(0.40)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: Colors.greenAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13)),
          ),
          Text('LIVE',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: 2,
                  color: AcroColors.gold.withOpacity(0.65))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 16, color: Colors.white.withOpacity(0.30)),
        ]),
      ),
    );
  }

  Widget _swipeArea(List<Map<String, dynamic>> rooms) {
    final idx  = _cardIndex % rooms.length;
    final room = rooms[idx];

    return Column(children: [
      // Counter
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${idx + 1} / ${rooms.length}',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.22))),
        ]),
      ),

      // Card
      Expanded(
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              _snapCtrl.stop();
              setState(() => _dragOffset += d.delta.dx);
            },
            onHorizontalDragEnd: (d) {
              final vel = d.velocity.pixelsPerSecond.dx;
              if (_dragOffset > 80 || vel > 500) {
                _animateOff(500, () => _skip(rooms.length));
              } else if (_dragOffset < -80 || vel < -500) {
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
                  if (_dragOffset < -28)
                    Positioned(top: 24, right: 24,
                        child: _badge('CHALLENGE', AcroColors.gold)),
                ]),
              ),
            ),
          ),
        ),
      ),

      // Buttons — 80 pt above FAB
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _skip(rooms.length),
              style: OutlinedButton.styleFrom(
                foregroundColor: AcroColors.stoneLight,
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2)),
              ),
              child: Text('SKIP',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _challenge(room),
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
              child: const Text('CHALLENGE'),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final title    = room['title']    as String? ?? 'Untitled';
    final thesis   = room['thesis']   as String? ?? '';
    final hostName = room['hostName'] as String? ?? 'Anonymous';
    final category = room['category'] as String? ?? '';
    final ts       = room['ts']       as int?    ?? 0;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1320),
        border: Border.all(color: AcroColors.gold.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 28,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          if (category.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AcroColors.gold.withOpacity(0.28)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(category,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: AcroColors.gold.withOpacity(0.70),
                      letterSpacing: 1.5)),
            ),
          const Spacer(),
          Text(_timeAgo(ts),
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.22))),
        ]),
        const SizedBox(height: 18),
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 20,
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
        Row(children: [
          AcroAvatar(
            initials: hostName.isNotEmpty ? hostName[0].toUpperCase() : '?',
            seed: room['hostUid'] as String? ?? hostName,
            size: 36,
          ),
          const SizedBox(width: 10),
          Text(hostName,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.60))),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3)),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontFamily: 'monospace',
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
            style: TextStyle(
                fontFamily: 'monospace',
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
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'Your full name…',
                        hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.22),
                            fontFamily: 'monospace'),
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

  String _timeAgo(int ts) {
    if (ts == 0) return '';
    final d =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
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
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: sel
                                    ? AcroColors.gold
                                    : Colors.white
                                        .withOpacity(0.45))),
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
              style: TextStyle(
                  fontFamily: 'monospace',
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
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontFamily: 'monospace'),
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
