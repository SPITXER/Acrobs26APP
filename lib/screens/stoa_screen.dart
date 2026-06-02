import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
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
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _nameCtrl   = TextEditingController();
  final _titleCtrl  = TextEditingController();
  final _thesisCtrl = TextEditingController();
  String _category  = 'Philosophy';
  bool   _posting   = false;

  // Swipe state
  int    _cardIndex  = 0;
  double _dragOffset = 0;
  StreamSubscription? _matchSub;

  bool get _onboarded => context.read<AppState>().profile.name.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (_onboarded) _listenForMatch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _thesisCtrl.dispose();
    _matchSub?.cancel();
    super.dispose();
  }

  void _listenForMatch() {
    _matchSub = context.read<AppState>().matchStream().listen((data) {
      if (data != null && mounted) {
        final state = context.read<AppState>();
        if (state.myStoaRoomIds.isEmpty) {
          // We're the challenger — navigate directly
          state.enterRoom(state.buildRoomFromMatch(data));
          state.clearMatch();
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const RoomScreen()));
        }
        // If we're the host, the AppState background watcher handles it
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

  Future<void> _postArgument() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final state = context.read<AppState>();
    if (!state.canCreateStoaRoom) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You have reached the 10-room limit.'),
        backgroundColor: Color(0xFF1A1200),
      ));
      return;
    }
    setState(() => _posting = true);
    await state.createStoaRoom(
        title: title,
        thesis: _thesisCtrl.text.trim(),
        category: _category);
    _titleCtrl.clear();
    _thesisCtrl.clear();
    setState(() => _posting = false);
    _tabs.animateTo(0);
  }

  Future<void> _challenge(Map<String, dynamic> room) async {
    await context.read<AppState>().joinStoaRoom(room);
  }

  void _skip(int total) {
    setState(() {
      _dragOffset = 0;
      _cardIndex  = (_cardIndex + 1) % total;
    });
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
        title: Text('⚖  STOA',
            style: GoogleFonts.dmSans(
                color: AcroColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3)),
        actions: const [SideMenuButton(), SizedBox(width: 4)],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AcroColors.gold,
          unselectedLabelColor: AcroColors.stoneLight,
          indicatorColor: AcroColors.gold,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
          tabs: const [Tab(text: 'THE FLOOR'), Tab(text: 'POST ARGUMENT')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildFloor(), _buildPost()],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // THE FLOOR — swipe cards
  // ---------------------------------------------------------------------------

  Widget _buildFloor() {
    return Consumer<AppState>(builder: (context, state, _) {
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: state.stoaRoomsStream(),
        builder: (ctx, snap) {
          final others = (snap.data ?? [])
              .where((r) => r['hostUid'] != state.profile.uid)
              .toList();

          if (others.isEmpty) {
            return _emptyFloor();
          }

          final idx  = _cardIndex % others.length;
          final room = others[idx];

          return Column(children: [
            // Counter
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${idx + 1} of ${others.length}',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.25))),
                  ]),
            ),

            // Swipe card
            Expanded(
              child: Center(
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _dragOffset += d.delta.dx),
                  onHorizontalDragEnd: (d) {
                    final vel = d.velocity.pixelsPerSecond.dx;
                    if (_dragOffset > 90 || vel > 400) {
                      // Swipe right = skip
                      _skip(others.length);
                    } else if (_dragOffset < -90 || vel < -400) {
                      // Swipe left = challenge
                      setState(() => _dragOffset = 0);
                      _challenge(room);
                    } else {
                      setState(() => _dragOffset = 0);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    child: Transform.translate(
                      offset: Offset(_dragOffset, _dragOffset.abs() * 0.04),
                      child: Transform.rotate(
                        angle: _dragOffset * 0.0025,
                        child: Stack(alignment: Alignment.center, children: [
                          _roomCard(room),
                          // Drag intent overlays
                          if (_dragOffset > 30)
                            Positioned(
                              top: 28, left: 32,
                              child: _intentBadge('SKIP', Colors.white30),
                            ),
                          if (_dragOffset < -30)
                            Positioned(
                              top: 28, right: 32,
                              child: _intentBadge('CHALLENGE', AcroColors.gold),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _skip(others.length),
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
        },
      );
    });
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final title      = room['title']     as String? ?? 'Untitled';
    final thesis     = room['thesis']    as String? ?? '';
    final hostName   = room['hostName']  as String? ?? 'Anonymous';
    final category   = room['category'] as String? ?? '';
    final ts         = room['ts']        as int?    ?? 0;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1320),
        border: Border.all(color: AcroColors.gold.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.40),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Category + age
        Row(children: [
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AcroColors.gold.withOpacity(0.28)),
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

        // Title
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3)),

        // Thesis
        if (thesis.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('"$thesis"',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.45),
                  fontStyle: FontStyle.italic,
                  height: 1.4)),
        ],

        const SizedBox(height: 24),
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),

        // Host
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: AcroColors.gold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
            ),
            child: Center(
              child: Text(
                hostName.isNotEmpty ? hostName[0].toUpperCase() : '?',
                style: TextStyle(
                    color: AcroColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(hostName,
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.65))),
        ]),
      ]),
    );
  }

  Widget _intentBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2)),
    );
  }

  Widget _emptyFloor() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚖', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 20),
        Text('The floor is empty.',
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Colors.white.withOpacity(0.4))),
        const SizedBox(height: 8),
        Text('Post an argument and open the debate.',
            style:
                TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.2))),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // POST ARGUMENT tab
  // ---------------------------------------------------------------------------

  Widget _buildPost() {
    return Consumer<AppState>(builder: (context, state, _) {
      final atLimit = !state.canCreateStoaRoom;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border.all(
                  color: AcroColors.gold.withOpacity(atLimit ? 0.10 : 0.25)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: atLimit ? _limitReached() : _postForm(),
          ),
        ),
      );
    });
  }

  Widget _postForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('OPEN THE FLOOR'),
      const SizedBox(height: 4),
      Text('State your argument. Anyone can challenge you.',
          style:
              TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.30))),
      const SizedBox(height: 28),

      _fieldLabel('ARGUMENT TITLE'),
      _input(_titleCtrl, 'e.g. "Free will is an illusion"'),

      _fieldLabel('YOUR POSITION  (optional)'),
      _input(_thesisCtrl,
          'Expand on your position in a sentence or two…',
          maxLines: 3),

      _fieldLabel('CATEGORY'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _kCategories.map((cat) {
          final sel = _category == cat;
          return GestureDetector(
            onTap: () => setState(() => _category = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      fontSize: 11,
                      color: sel
                          ? AcroColors.gold
                          : Colors.white.withOpacity(0.45))),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 28),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _posting ? null : _postArgument,
          style: ElevatedButton.styleFrom(
            backgroundColor: AcroColors.gold,
            foregroundColor: AcroColors.stone,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2)),
            textStyle: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2),
          ),
          child: Text(_posting ? 'POSTING…' : 'POST TO THE FLOOR'),
        ),
      ),
    ]);
  }

  Widget _limitReached() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      const Text('⚖', style: TextStyle(fontSize: 36)),
      const SizedBox(height: 16),
      Text('10-room limit reached.',
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.white.withOpacity(0.45))),
      const SizedBox(height: 8),
      Text('Terminate rooms from the ledger (≡) before posting new ones.',
          style:
              TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.25)),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Name entry
  // ---------------------------------------------------------------------------

  Widget _buildNameEntry() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('⚖  STOA',
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
              border:
                  Border.all(color: AcroColors.gold.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('ENTER THE STOA'),
                  const SizedBox(height: 4),
                  Text('State your name to take the floor.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.30))),
                  const SizedBox(height: 24),
                  _fieldLabel('YOUR NAME'),
                  _input(_nameCtrl, 'Your full name…'),
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
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _timeAgo(int ts) {
    if (ts == 0) return '';
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AcroColors.stoneLight,
          letterSpacing: 3));

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 1.5)),
      );

  Widget _input(TextEditingController ctrl, String hint,
          {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.22),
                fontFamily: 'monospace'),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide:
                    BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide:
                    BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: AcroColors.gold)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );
}
