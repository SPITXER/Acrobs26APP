import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../services/badge_engine.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cloud_corner_box.dart';
import '../widgets/legendary_scrolls_section.dart';
import '../widgets/side_menu.dart';
import 'room_screen.dart';
import 'scroll_thread_page.dart';

const _kInterests = [
  'Philosophy', 'Science', 'Politics', 'Economics',
  'History', 'Ethics', 'Technology', 'Literature',
  'Psychology', 'Art', 'Mathematics', 'Theology',
];

enum _AuthMode { createAccount, signIn }

class SymposiumScreen extends StatefulWidget {
  const SymposiumScreen({super.key});

  @override
  State<SymposiumScreen> createState() => _SymposiumScreenState();
}

class _SymposiumScreenState extends State<SymposiumScreen>
    with TickerProviderStateMixin {

  // Profile setup form
  final _nameCtrl  = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _quoteCtrl = TextEditingController();
  final _selectedInterests = <String>{};
  bool _onboarded = false;
  bool _enterScheduled = false;

  // Auth wall state
  bool _showEmailAuth = false;
  _AuthMode _authMode = _AuthMode.createAccount;
  bool _authLoading = false;
  String? _authError;
  final _authEmailCtrl = TextEditingController();
  final _authPassCtrl  = TextEditingController();

  // Main tabs: THE HALL | THE ASSEMBLY
  late TabController _tabs;

  // Assembly sub-tabs (mobile only): RANK | FORUM | INBOX
  late TabController _assembly;

  // Sent requests (local tracking to prevent double-tap)
  final _sentTo = <String>{};

  // Match listener
  StreamSubscription? _matchSub;

  @override
  void initState() {
    super.initState();
    _tabs     = TabController(length: 2, vsync: this);
    _assembly = TabController(length: 3, vsync: this);

    final state = context.read<AppState>();
    if (state.isPermanentAccount && state.profile.name.isNotEmpty) {
      _onboarded = true;
      _enterScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await context.read<AppState>().publishToSymposiumPool();
        _startListening();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fieldCtrl.dispose();
    _quoteCtrl.dispose();
    _authEmailCtrl.dispose();
    _authPassCtrl.dispose();
    _tabs.dispose();
    _assembly.dispose();
    _matchSub?.cancel();
    if (_onboarded) {
      context.read<AppState>().removeFromSymposiumPool();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Auth actions
  // ---------------------------------------------------------------------------

  Future<void> _googleSignIn() async {
    setState(() { _authLoading = true; _authError = null; });
    try {
      await context.read<AppState>().signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String display = 'Google sign-in failed. Try again.';
      if (msg.contains('popup-blocked'))   display = 'Pop-up blocked — allow pop-ups for this site and try again.';
      if (msg.contains('popup-closed') || msg.contains('cancelled')) display = 'Sign-in cancelled.';
      if (msg.contains('unauthorized-domain')) display = 'Domain not authorised. Contact support.';
      setState(() { _authLoading = false; _authError = display; });
    }
  }

  Future<void> _emailAuth() async {
    final email = _authEmailCtrl.text.trim();
    final pass  = _authPassCtrl.text;
    if (email.isEmpty || pass.length < 6) {
      setState(() => _authError = 'Enter a valid email and password (6+ chars).');
      return;
    }
    setState(() { _authLoading = true; _authError = null; });
    try {
      final state = context.read<AppState>();
      if (_authMode == _AuthMode.createAccount) {
        await state.signUpWithEmail(email, pass);
      } else {
        await state.signInWithEmail(email, pass);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        setState(() {
          _authLoading = false;
          if (msg.contains('email-already-in-use')) {
            _authError = 'That email is already registered. Try signing in instead.';
          } else if (msg.contains('user-not-found') || msg.contains('wrong-password') || msg.contains('invalid-credential')) {
            _authError = 'Incorrect email or password.';
          } else {
            _authError = 'Authentication failed. Try again.';
          }
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Symposium entry
  // ---------------------------------------------------------------------------

  Future<void> _enterSymposium() async {
    if (_enterScheduled) return;
    _enterScheduled = true;
    await context.read<AppState>().publishToSymposiumPool();
    if (mounted) {
      setState(() => _onboarded = true);
      _startListening();
    }
  }

  Future<void> _completeOnboarding() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final state = context.read<AppState>();
    state.setProfile(
      name: name,
      field: _fieldCtrl.text.trim(),
      mode: AcroMode.symposium,
      interests: _selectedInterests.toList(),
    );
    state.updateProfileDetails(quote: _quoteCtrl.text.trim());
    await state.syncProfileToFirebase();
    await _enterSymposium();
  }

  void _startListening() {
    _matchSub?.cancel();
    _matchSub = context.read<AppState>().matchStream().listen((matchData) {
      if (matchData != null && mounted) _navigateToRoom(matchData);
    });
  }

  void _navigateToRoom(Map<String, dynamic> matchData) {
    final state = context.read<AppState>();
    final room = state.buildRoomFromMatch(matchData);
    state.enterRoom(room);
    state.markMatchHandled();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoomScreen()),
    );
  }

  Future<void> _sendRequest(String toUid) async {
    setState(() => _sentTo.add(toUid));
    await context.read<AppState>().sendSymposiumRequest(toUid);
  }

  Future<void> _accept(Map<String, dynamic> req) async {
    await context.read<AppState>().acceptSymposiumRequest(req);
  }

  Future<void> _decline(String reqId) async {
    await context.read<AppState>().declineSymposiumRequest(reqId);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final googleErr = state.googleSignInError;
    if (googleErr != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        state.clearGoogleSignInError();
        String msg = 'Google sign-in failed. Try again.';
        if (googleErr.contains('unauthorized-domain'))      msg = 'Domain not authorized for Google sign-in.';
        else if (googleErr.contains('operation-not-allowed')) msg = 'Google sign-in not enabled. Contact support.';
        else if (googleErr.contains('popup-closed') || googleErr.contains('cancelled')) msg = 'Sign-in cancelled.';
        setState(() { _authLoading = false; _authError = msg; });
      });
    }

    if (!state.isPermanentAccount) {
      return _buildAuthScaffold();
    }

    if (!_enterScheduled && state.profile.name.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enterSymposium();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '🍷  SYMPOSIUM',
          style: GoogleFonts.dmSans(
            color: AcroColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        actions: const [SideMenuButton(), SizedBox(width: 4)],
        bottom: _onboarded
            ? TabBar(
                controller: _tabs,
                labelColor: AcroColors.gold,
                unselectedLabelColor: AcroColors.stoneLight,
                indicatorColor: AcroColors.gold,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
                tabs: const [
                  Tab(text: 'THE HALL'),
                  Tab(text: 'THE ASSEMBLY'),
                ],
              )
            : null,
      ),
      endDrawer: const SideMenu(),
      body: _onboarded ? _buildHome() : _buildProfileSetup(),
    );
  }

  // ---------------------------------------------------------------------------
  // Auth wall
  // ---------------------------------------------------------------------------

  Widget _buildAuthScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '🍷  SYMPOSIUM',
          style: GoogleFonts.dmSans(
            color: AcroColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _courtroomBanner(),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: AcroColors.gold.withOpacity(0.30)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('ENTER THE SYMPOSIUM'),
                        const SizedBox(height: 4),
                        Text(
                          'The Symposium requires a permanent account. Your profile and history are preserved across sessions.',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35), height: 1.5),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _authLoading ? null : _googleSignIn,
                            icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                            label: const Text('CONTINUE WITH GOOGLE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.10))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
                          ),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.10))),
                        ]),
                        const SizedBox(height: 16),
                        if (!_showEmailAuth)
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() => _showEmailAuth = true),
                              child: Text('Use email instead', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.40))),
                            ),
                          ),
                        if (_showEmailAuth) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _authModeChip('CREATE ACCOUNT', _AuthMode.createAccount),
                              const SizedBox(width: 8),
                              _authModeChip('SIGN IN', _AuthMode.signIn),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _authField(_authEmailCtrl, 'Email address', TextInputType.emailAddress),
                          _authField(_authPassCtrl, 'Password (6+ chars)', TextInputType.visiblePassword, obscure: true),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _authLoading ? null : _emailAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AcroColors.gold,
                                foregroundColor: AcroColors.stone,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
                              ),
                              child: Text(_authLoading ? 'PLEASE WAIT…' : (_authMode == _AuthMode.createAccount ? 'CREATE ACCOUNT' : 'SIGN IN')),
                            ),
                          ),
                        ],
                        if (_authError != null) ...[
                          const SizedBox(height: 12),
                          Text(_authError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ],
                        if (_authLoading) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AcroColors.gold), strokeWidth: 2)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _authModeChip(String label, _AuthMode mode) {
    final selected = _authMode == mode;
    return GestureDetector(
      onTap: () => setState(() { _authMode = mode; _authError = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AcroColors.gold.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: selected ? AcroColors.gold : AcroColors.gold.withOpacity(0.22)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.5,
                color: selected ? AcroColors.gold : Colors.white.withOpacity(0.40))),
      ),
    );
  }

  Widget _authField(TextEditingController ctrl, String hint, TextInputType type, {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.22), fontFamily: 'monospace'),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: AcroColors.gold)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // Profile setup
  // ---------------------------------------------------------------------------

  Widget _buildProfileSetup() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _courtroomBanner(),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(color: AcroColors.gold.withOpacity(0.30)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('CREATE YOUR SYMPOSIUM PROFILE'),
                      const SizedBox(height: 4),
                      Text('Your full profile is visible to others. Make it count.',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35))),
                      const SizedBox(height: 28),
                      _fieldLabel('NAME'),
                      _input(_nameCtrl, 'Your full name…'),
                      _fieldLabel('FIELD / EXPERTISE'),
                      _input(_fieldCtrl, 'e.g. Classical Studies, Cognitive Science…'),
                      _fieldLabel('OPENING STATEMENT  (optional)'),
                      _input(_quoteCtrl, 'A thought, question, or position…', maxLines: 2),
                      _fieldLabel('INTERESTS  (pick a few)'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kInterests.map((interest) {
                          final sel = _selectedInterests.contains(interest);
                          return GestureDetector(
                            onTap: () => setState(() =>
                                sel ? _selectedInterests.remove(interest) : _selectedInterests.add(interest)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? AcroColors.gold.withOpacity(0.15) : Colors.transparent,
                                border: Border.all(color: sel ? AcroColors.gold : AcroColors.gold.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(interest, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: sel ? AcroColors.gold : Colors.white.withOpacity(0.45))),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _completeOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AcroColors.gold,
                            foregroundColor: AcroColors.stone,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                            textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2),
                          ),
                          child: const Text('ENTER THE SYMPOSIUM'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Courtroom banner
  // ---------------------------------------------------------------------------

  Widget _courtroomBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = (w * 9 / 16 * 0.42).clamp(160.0, 320.0);
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/Sym2.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55, 1.0],
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0B0F1A).withOpacity(0.15),
                      const Color(0xFF0B0F1A),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Home — 2 main tabs (no banner, flat page)
  // ---------------------------------------------------------------------------

  Widget _buildHome() {
    return TabBarView(
      controller: _tabs,
      children: [_buildTheHall(), _buildTheAssembly()],
    );
  }

  // ===========================================================================
  // THE HALL — Legendary platform + Scrolls feed
  // ===========================================================================

  Widget _buildTheHall() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AppState>().nominationsStream(),
      builder: (context, snap) {
        final allScrolls = snap.data ?? [];
        final legendary  = allScrolls.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Legendary Scrolls header ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(children: [
                Text('⭐', style: TextStyle(fontSize: 13, color: AcroColors.gold.withOpacity(0.9))),
                const SizedBox(width: 8),
                Text(
                  'LEGENDARY SCROLLS',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AcroColors.stoneLight,
                    letterSpacing: 3,
                  ),
                ),
                const Spacer(),
                Text(
                  '${legendary.length} enshrined',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.25),
                    fontFamily: 'monospace',
                  ),
                ),
              ]),
            ),

            // ── Rotating platform ───────────────────────────────────────
            legendary.isNotEmpty
                ? LegendaryScrollsSection(
                    scrolls: legendary,
                    onScrollTap: (scroll) => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ScrollThreadPage(scroll: scroll)),
                    ),
                  )
                : _emptyPlatform(),

            // ── Section divider ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Row(children: [
                Expanded(child: Divider(color: AcroColors.gold.withOpacity(0.15))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'THE HALL',
                    style: GoogleFonts.spaceMono(
                      fontSize: 8,
                      color: Colors.white.withOpacity(0.25),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AcroColors.gold.withOpacity(0.15))),
              ]),
            ),

            // ── Feed ────────────────────────────────────────────────────
            if (allScrolls.isEmpty)
              Expanded(
                child: _emptyState(
                  '📜',
                  'The Hall awaits its first scroll.',
                  'Arguments nominated in the Stoa are enshrined here.',
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: allScrolls.length,
                  itemBuilder: (_, i) => _scrollCard(allScrolls[i]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _emptyPlatform() {
    return SizedBox(
      height: 290,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Legendisland.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
          Center(
            child: Text(
              'No legendary scrolls yet',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.30),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollCard(Map<String, dynamic> nom) {
    final title    = nom['title']           as String? ?? 'Untitled';
    final thesis   = nom['thesis']           as String? ?? '';
    final category = nom['category']         as String? ?? '';
    final hostName = nom['hostName']         as String? ?? 'Anonymous';
    final byName   = nom['nominatedByName']  as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScrollThreadPage(scroll: nom)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF131826), const Color(0xFF0D1020)],
          ),
          border: Border.all(color: AcroColors.gold.withOpacity(0.22)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top strip
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(children: [
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AcroColors.gold.withOpacity(0.35)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: GoogleFonts.spaceMono(fontSize: 8, color: AcroColors.gold, letterSpacing: 2),
                    ),
                  ),
                const Spacer(),
                const Icon(Icons.stars, size: 10, color: AcroColors.gold),
                const SizedBox(width: 4),
                Text('SCROLL', style: GoogleFonts.spaceMono(fontSize: 8, color: AcroColors.gold.withOpacity(0.55), letterSpacing: 1.5)),
              ]),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Text(
                title,
                style: GoogleFonts.cormorant(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            ),

            // Thesis excerpt
            if (thesis.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AcroColors.gold.withOpacity(0.04),
                    border: Border(left: BorderSide(color: AcroColors.gold.withOpacity(0.4), width: 2)),
                  ),
                  child: Text(
                    '"$thesis"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), fontStyle: FontStyle.italic, height: 1.45),
                  ),
                ),
              ),

            // Bottom bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(children: [
                AcroAvatar(initials: _initials(hostName), seed: hostName, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hostName, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                      if (byName.isNotEmpty)
                        Text('nom. by $byName', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.25))),
                    ],
                  ),
                ),
                Row(children: [
                  Text('OPEN THREAD', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: AcroColors.gold, letterSpacing: 1.5)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 12, color: AcroColors.gold),
                ]),
              ]),
            ),

            // Thread-entry gradient line at the bottom
            Container(height: 2, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AcroColors.gold.withOpacity(0),
                AcroColors.gold.withOpacity(0.3),
                AcroColors.gold.withOpacity(0),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // THE ASSEMBLY — Ranks | Forum | Inbox
  // ===========================================================================

  Widget _buildTheAssembly() {
    return LayoutBuilder(builder: (ctx, constraints) {
      if (constraints.maxWidth >= 700) {
        return _assemblyWide();
      }
      return _assemblyNarrow();
    });
  }

  // Wide (tablet/web): 3 columns side by side
  Widget _assemblyWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildRanksPanel(showHeader: true)),
        VerticalDivider(width: 1, color: AcroColors.gold.withOpacity(0.10)),
        Expanded(flex: 7, child: _buildForumPanel(showHeader: true)),
        VerticalDivider(width: 1, color: AcroColors.gold.withOpacity(0.10)),
        Expanded(flex: 5, child: _buildInboxPanel(showHeader: true)),
      ],
    );
  }

  // Narrow (mobile): sub-tabs
  Widget _assemblyNarrow() {
    return Column(
      children: [
        TabBar(
          controller: _assembly,
          labelColor: AcroColors.gold,
          unselectedLabelColor: AcroColors.stoneLight,
          indicatorColor: AcroColors.gold,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
          tabs: const [
            Tab(text: 'RANK'),
            Tab(text: 'FORUM'),
            Tab(text: 'INBOX'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _assembly,
            children: [
              _buildRanksPanel(showHeader: false),
              _buildForumPanel(showHeader: false),
              _buildInboxPanel(showHeader: false),
            ],
          ),
        ),
      ],
    );
  }

  // ── RANKS panel ─────────────────────────────────────────────────────────────

  Widget _buildRanksPanel({required bool showHeader}) {
    final state = context.read<AppState>();
    return StreamBuilder<Map<String, dynamic>>(
      stream: state.userStatsStream(),
      builder: (context, snap) {
        final stats = snap.data ?? {};
        final badge = BadgeEngine.fromStats(stats);
        final info  = BadgeEngine.infoFor(badge);

        final minutes  = (stats['totalMinutesActive'] as int?) ?? 0;
        final quotes   = (stats['quoteCount']          as int?) ?? 0;
        final nomRecv  = (stats['nominationsReceived'] as int?) ?? 0;
        final rawTopics = stats['topicEngagement'];
        final topicMap  = rawTopics is Map
            ? Map<String, int>.from(rawTopics.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
            : <String, int>{};
        final topics = topicMap.length;

        final score = BadgeEngine.computeScore(
          totalMinutesActive: minutes,
          quoteCount: quotes,
          nominationsReceived: nomRecv,
          distinctTopics: topics,
        );

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (showHeader) ...[
              _panelHeader('RANK'),
              const SizedBox(height: 16),
            ],

            // Badge display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AcroColors.gold.withOpacity(0.08), Colors.transparent],
                ),
                border: Border.all(color: AcroColors.gold.withOpacity(0.28)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(info.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.name,
                            style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          Text(
                            info.epithet,
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    info.domain,
                    style: GoogleFonts.spaceMono(fontSize: 9, color: AcroColors.gold.withOpacity(0.7), letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 14),
                  // Score bar
                  Row(children: [
                    Text('SCORE', style: GoogleFonts.spaceMono(fontSize: 8, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: score.clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withOpacity(0.08),
                          valueColor: const AlwaysStoppedAnimation(AcroColors.gold),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(score * 100).toStringAsFixed(0)}', style: GoogleFonts.spaceMono(fontSize: 9, color: AcroColors.gold)),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Stats grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                _statCell('⏱', '${(minutes / 60).toStringAsFixed(1)} h', 'TIME ACTIVE'),
                _statCell('📜', '$quotes', 'QUOTES'),
                _statCell('⭐', '$nomRecv', 'NOMINATIONS'),
                _statCell('🗂', '$topics', 'TOPICS'),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _statCell(String icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$icon  $value',
              style: GoogleFonts.playfairDisplay(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.spaceMono(fontSize: 8, color: Colors.white.withOpacity(0.28), letterSpacing: 1)),
        ],
      ),
    );
  }

  // ── FORUM panel (connections / discover) ────────────────────────────────────

  Widget _buildForumPanel({required bool showHeader}) {
    final state = context.read<AppState>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.symposiumPoolStream(),
      builder: (context, snap) {
        final profiles = snap.data ?? [];
        if (profiles.isEmpty) {
          return Column(
            children: [
              if (showHeader) ...[
                Padding(padding: const EdgeInsets.all(18), child: _panelHeader('FORUM')),
              ],
              Expanded(child: _emptyState('🍷', 'The Symposium awaits.', 'Your profile is visible. Others will appear here.')),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
          itemCount: profiles.length + (showHeader ? 1 : 0),
          itemBuilder: (_, i) {
            if (showHeader && i == 0) {
              return Padding(padding: const EdgeInsets.only(bottom: 14), child: _panelHeader('FORUM'));
            }
            return _profileCard(profiles[showHeader ? i - 1 : i]);
          },
        );
      },
    );
  }

  Widget _profileCard(Map<String, dynamic> card) {
    final uid       = card['uid']       as String? ?? '';
    final name      = card['name']      as String? ?? 'Anonymous';
    final field     = card['field']     as String? ?? '';
    final quote     = card['quote']     as String? ?? '';
    final rawInterests = card['interests'];
    final interests = rawInterests is List ? rawInterests.map((e) => e.toString()).toList() : <String>[];
    final ini       = _initials(name);
    final sent      = _sentTo.contains(uid);

    final badgeId   = card['badgeId'] as String? ?? '';
    final badge     = BadgeEngine.fromId(badgeId);
    final badgeInfo = BadgeEngine.infoFor(badge);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CloudCornerBox(
        backgroundColor: Colors.white.withOpacity(0.03),
        borderColor: AcroColors.gold.withOpacity(0.18),
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AcroAvatar(initials: ini, seed: uid, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.playfairDisplay(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (field.isNotEmpty)
                    Text(field, style: TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(badgeInfo.emoji, style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(badgeInfo.name, style: GoogleFonts.spaceMono(fontSize: 8, color: AcroColors.gold.withOpacity(0.75), letterSpacing: 1)),
                  ]),
                  if (quote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('"$quote"', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontStyle: FontStyle.italic)),
                  ],
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: interests.take(4).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: AcroColors.gold.withOpacity(0.22)), borderRadius: BorderRadius.circular(2)),
                        child: Text(t, style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.white.withOpacity(0.45))),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: sent ? null : () => _sendRequest(uid),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sent ? AcroColors.stoneLight : AcroColors.gold,
                        side: BorderSide(color: sent ? AcroColors.gold.withOpacity(0.18) : AcroColors.gold.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                        textStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
                      ),
                      child: Text(sent ? 'REQUEST SENT ✓' : 'SEND REQUEST'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── INBOX panel ─────────────────────────────────────────────────────────────

  Widget _buildInboxPanel({required bool showHeader}) {
    final state = context.read<AppState>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.requestsStream(),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return Column(
            children: [
              if (showHeader) ...[
                Padding(padding: const EdgeInsets.all(18), child: _panelHeader('INBOX')),
              ],
              Expanded(child: _emptyState('📬', 'No requests yet.', 'Others in the Symposium can send you a request.')),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
          itemCount: requests.length + (showHeader ? 1 : 0),
          itemBuilder: (_, i) {
            if (showHeader && i == 0) {
              return Padding(padding: const EdgeInsets.only(bottom: 14), child: _panelHeader('INBOX'));
            }
            return _requestCard(requests[showHeader ? i - 1 : i]);
          },
        );
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final name      = req['fromName']      as String? ?? 'Anonymous';
    final field     = req['fromField']     as String? ?? '';
    final quote     = req['fromQuote']     as String? ?? '';
    final rawInterests = req['fromInterests'];
    final interests = rawInterests is List ? rawInterests.map((e) => e.toString()).toList() : <String>[];
    final ini       = _initials(name);
    final reqId     = req['reqId']         as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CloudCornerBox(
        backgroundColor: AcroColors.gold.withOpacity(0.04),
        borderColor: AcroColors.gold.withOpacity(0.28),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AcroAvatar(initials: ini, seed: name, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (field.isNotEmpty) Text(field, style: TextStyle(fontSize: 11, color: AcroColors.stoneLight)),
                  ],
                ),
              ),
              Text('INVITES YOU', style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: AcroColors.gold.withOpacity(0.6), letterSpacing: 1.5)),
            ]),
            if (quote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('"$quote"', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.42), fontStyle: FontStyle.italic)),
            ],
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: interests.take(3).map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: AcroColors.gold.withOpacity(0.22)), borderRadius: BorderRadius.circular(2)),
                  child: Text(t, style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: Colors.white.withOpacity(0.45))),
                )).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _decline(reqId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AcroColors.stoneLight,
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    textStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
                  ),
                  child: const Text('DECLINE'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _accept(req),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AcroColors.gold,
                    foregroundColor: AcroColors.stone,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    textStyle: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
                  ),
                  child: const Text('ACCEPT'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _panelHeader(String label) {
    return Text(
      label,
      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AcroColors.stoneLight, letterSpacing: 3),
    );
  }

  Widget _emptyState(String icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 18),
          Text(title, style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(sub, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.2)), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.35), letterSpacing: 1.5)),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AcroColors.stoneLight, letterSpacing: 3),
      );

  Widget _input(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.22), fontFamily: 'monospace'),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: AcroColors.gold)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );
}
