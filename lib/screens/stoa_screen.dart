import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
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

  // Joiner side: watch matches/{uid} and navigate when room is ready
  void _listenForMatch() {
    _matchSub = context.read<AppState>().matchStream().listen((data) {
      if (data != null && mounted) {
        final state = context.read<AppState>();
        // Only navigate here if it's not a stoa room we hosted
        // (hosted rooms are handled by AppState's background watcher)
        if (state.myStoaRoomId == null) {
          state.enterRoom(state.buildRoomFromMatch(data));
          state.clearMatch();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RoomScreen()),
          );
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

  Future<void> _postArgument() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _posting = true);
    await context.read<AppState>().createStoaRoom(
      title: title,
      thesis: _thesisCtrl.text.trim(),
      category: _category,
    );
    _titleCtrl.clear();
    _thesisCtrl.clear();
    setState(() => _posting = false);
    _tabs.animateTo(0);
  }

  Future<void> _join(Map<String, dynamic> room) async {
    await context.read<AppState>().joinStoaRoom(room);
    // matchStream listener above handles navigation for the joiner
  }

  Future<void> _terminate() async {
    await context.read<AppState>().terminateStoaRoom();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) return _buildNameEntry();
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
  // THE FLOOR tab
  // ---------------------------------------------------------------------------

  Widget _buildFloor() {
    return Consumer<AppState>(builder: (context, state, _) {
      final myRoomId = state.myStoaRoomId;
      return Column(children: [
        if (myRoomId != null) _myRoomBanner(state, myRoomId),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: state.stoaRoomsStream(),
            builder: (ctx, snap) {
              final all    = snap.data ?? [];
              final others = all
                  .where((r) => r['hostUid'] != state.profile.uid)
                  .toList();
              if (others.isEmpty) return _emptyFloor(myRoomId != null);
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                itemCount: others.length,
                itemBuilder: (_, i) => _roomCard(others[i]),
              );
            },
          ),
        ),
      ]);
    });
  }

  Widget _myRoomBanner(AppState state, String roomId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.stoaRoomsStream(),
      builder: (ctx, snap) {
        final myRoom = (snap.data ?? []).firstWhere(
            (r) => r['roomId'] == roomId,
            orElse: () => {});
        final title = myRoom['title'] as String? ?? 'Your Argument';
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AcroColors.gold.withOpacity(0.07),
            border: Border.all(color: AcroColors.gold.withOpacity(0.45)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR OPEN ARGUMENT',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            color: AcroColors.gold.withOpacity(0.65),
                            letterSpacing: 2)),
                    const SizedBox(height: 5),
                    Text(title,
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text('Waiting for a challenger…',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.35))),
                  ]),
            ),
            TextButton(
              onPressed: _terminate,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent.shade100,
                textStyle: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5),
              ),
              child: const Text('TERMINATE'),
            ),
          ]),
        );
      },
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final title    = room['title']    as String? ?? 'Untitled';
    final thesis   = room['thesis']   as String? ?? '';
    final hostName = room['hostName'] as String? ?? 'Anonymous';
    final category = room['category'] as String? ?? '';
    final ts       = room['ts']       as int?    ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: AcroColors.gold.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (category.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border:
                    Border.all(color: AcroColors.gold.withOpacity(0.28)),
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
        const SizedBox(height: 10),
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        if (thesis.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"$thesis"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.42),
                  fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Text(hostName,
              style: TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
          const Spacer(),
          OutlinedButton(
            onPressed: () => _join(room),
            style: OutlinedButton.styleFrom(
              foregroundColor: AcroColors.gold,
              side: BorderSide(color: AcroColors.gold.withOpacity(0.55)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
              textStyle: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2),
            ),
            child: const Text('CHALLENGE'),
          ),
        ]),
      ]),
    );
  }

  Widget _emptyFloor(bool hasOwnRoom) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚖', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 20),
        Text(
          hasOwnRoom ? 'Your argument is on the floor.' : 'The floor is empty.',
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.white.withOpacity(0.4)),
        ),
        const SizedBox(height: 8),
        Text(
          hasOwnRoom
              ? "You'll be notified when someone challenges you."
              : 'Post an argument and open the debate.',
          style:
              TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.2)),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // POST ARGUMENT tab
  // ---------------------------------------------------------------------------

  Widget _buildPost() {
    return Consumer<AppState>(builder: (context, state, _) {
      final hasRoom = state.myStoaRoomId != null;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border.all(
                  color: AcroColors.gold
                      .withOpacity(hasRoom ? 0.10 : 0.25)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: hasRoom ? _alreadyPosted() : _postForm(),
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
          style: TextStyle(
              fontSize: 13, color: Colors.white.withOpacity(0.30))),
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
        spacing: 8,
        runSpacing: 8,
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
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2),
          ),
          child: Text(_posting ? 'POSTING…' : 'POST TO THE FLOOR'),
        ),
      ),
    ]);
  }

  Widget _alreadyPosted() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text('⚖', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 16),
          Text('You already have an open argument.',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.45))),
          const SizedBox(height: 8),
          Text('Terminate it first before posting a new one.',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.25)),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _tabs.animateTo(0),
            style: OutlinedButton.styleFrom(
              foregroundColor: AcroColors.stoneLight,
              side: BorderSide(color: Colors.white.withOpacity(0.15)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
              textStyle: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2),
            ),
            child: const Text('VIEW THE FLOOR'),
          ),
          const SizedBox(height: 12),
        ]);
  }

  // ---------------------------------------------------------------------------
  // Name entry (first visit)
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
            child:
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  Widget _label(String text) => Text(text,
      style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AcroColors.stoneLight,
          letterSpacing: 3));

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text,
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
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.22),
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
