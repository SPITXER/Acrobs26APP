import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../services/badge_engine.dart';
import '../theme/acro_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/legendary_scrolls_section.dart';
import '../widgets/side_menu.dart';
import 'room_screen.dart';
import 'scroll_thread_page.dart';

const _kInterests = [
  'Philosophy', 'Science', 'Politics', 'Economics',
  'History', 'Ethics', 'Technology', 'Literature',
  'Psychology', 'Art', 'Mathematics', 'Theology',
];

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
}

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

  // Assembly sub-tabs (mobile only): RANK | INBOX
  late TabController _assembly;

  // Match listener
  StreamSubscription? _matchSub;

  // Hall horizontal scroll
  final _hallScrollCtrl = ScrollController();
  late Ticker _hallTicker;
  double _hallScrollOffset = 0;
  bool _hallUserScrolling = false;

  @override
  void initState() {
    super.initState();
    _tabs     = TabController(length: 2, vsync: this);
    _assembly = TabController(length: 2, vsync: this);

    _hallTicker = createTicker((_) {
      if (!mounted || !_hallScrollCtrl.hasClients || _hallUserScrolling) return;
      final max = _hallScrollCtrl.position.maxScrollExtent;
      if (max <= 0) return;
      _hallScrollOffset = (_hallScrollOffset + 0.6) % max;
      _hallScrollCtrl.jumpTo(_hallScrollOffset);
    });
    _hallTicker.start();

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
    _hallTicker.dispose();
    _hallScrollCtrl.dispose();
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

  Future<void> _accept(Map<String, dynamic> req) async {
    await context.read<AppState>().acceptSymposiumRequest(req);
  }

  Future<void> _decline(String reqId) async {
    await context.read<AppState>().declineSymposiumRequest(reqId);
  }

  // _initials is a top-level function defined above this class

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
      // _KeepAlivePage prevents TabBarView from destroying each tab's widget
      // tree when switching — streams stay subscribed, scroll positions persist,
      // and animations don't reset.
      children: [
        _KeepAlivePage(child: _buildTheHall()),
        _KeepAlivePage(child: _buildTheAssembly()),
      ],
    );
  }

  // ===========================================================================
  // THE HALL — Legendary platform + Scrolls feed
  // ===========================================================================

  Widget _buildTheHall() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AppState>().nominationsStream(),
      builder: (context, snap) {
        final allScrolls  = snap.data ?? [];
        final legendary   = allScrolls.take(3).toList();
        final hallScrolls = allScrolls.skip(3).toList(); // non-legendary feed

        // 13 % of the viewport height — island is pulled this far above the
        // canvas top. The AppBar (same dark colour) covers the overflow
        // seamlessly. A matching SizedBox placeholder in the Column keeps
        // the heading/feed butted right up against the island's visual bottom.
        final islandLift = MediaQuery.of(context).size.height * 0.13;
        final islandH    = legendary.isNotEmpty
            ? kLegendSectionHeight
            : 290.0; // _emptyPlatform height

        return CustomScrollView(
          slivers: [
            // ── Island + feed on one shared background canvas ────────────
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none, // island overflows upward into AppBar
                children: [
                  // ── hallback.png background ─────────────────────────────
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Image.asset(
                      'assets/images/hallback.png',
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      width: double.infinity,
                    ),
                  ),

                  // ── Dark overlay ────────────────────────────────────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                      ),
                    ),
                  ),

                  // ── Top fade into header colour ─────────────────────────
                  Positioned(
                    top: 0, left: 0, right: 0, height: 56,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0B0F1A), Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                  // ── Layout column (determines Stack height) ─────────────
                  // The island is Positioned separately above; this column
                  // starts with a placeholder SizedBox of (islandH - islandLift)
                  // so the heading lines up with the island's visual bottom.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: islandH - islandLift),

                      // THE HALL heading
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE HALL',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scrolls of the Assembly — ranked by the Forum',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.55),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Horizontal scrolling feed ──────────────────────
                      if (allScrolls.isEmpty)
                        SizedBox(height: 280, child: _hallEmptyState(context))
                      else if (hallScrolls.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: _emptyState('📜', 'All scrolls are legendary.',
                              'New nominations from the Stoa will appear here.'),
                        )
                      else
                        NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollStartNotification) {
                              setState(() => _hallUserScrolling = true);
                            } else if (n is ScrollEndNotification) {
                              setState(() => _hallUserScrolling = false);
                            }
                            return false;
                          },
                          child: SizedBox(
                            height: 360,
                            child: ScrollConfiguration(
                              behavior: _MouseDragBehavior(),
                              child: ListView.builder(
                                controller: _hallScrollCtrl,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                itemCount: hallScrolls.length,
                                itemBuilder: (_, i) => _hallScrollCard(hallScrolls[i]),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),

                  // ── Island — floated 13 % above the canvas top ──────────
                  Positioned(
                    top: -islandLift,
                    left: 0,
                    right: 0,
                    height: islandH,
                    child: legendary.isNotEmpty
                        ? LegendaryScrollsSection(
                            scrolls: legendary,
                            onScrollTap: (scroll) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ScrollThreadPage(scroll: scroll)),
                            ),
                          )
                        : _emptyPlatform(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyPlatform(BuildContext ctx) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No scrolls enshrined yet',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.30), fontFamily: 'monospace'),
                ),
                const SizedBox(height: 10),
                _seedButton(ctx),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hallEmptyState(BuildContext ctx) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📜', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 16),
          Text('The Hall awaits its first scroll.',
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 6),
          Text('Arguments nominated in the Stoa are enshrined here.',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.2)), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _seedButton(ctx),
        ],
      ),
    );
  }

  Widget _seedButton(BuildContext ctx) {
    return OutlinedButton.icon(
      onPressed: () => ctx.read<AppState>().seedTestScrolls(),
      icon: const Icon(Icons.auto_awesome, size: 13, color: AcroColors.gold),
      label: Text('SEED TEST SCROLLS',
          style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AcroColors.gold)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AcroColors.gold.withOpacity(0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  // HallScroll.png layout constants — source image is 600×600 px.
  // Rendered card size: 320×320.  Scale = 320/600 = 0.5333.
  //
  //  Category label  ≈ (90,  108) → (48,  57)
  //  Circle centre   ≈ (185, 261)  radius ≈ 100 → chip centre (98.7, 139.2) r=53.3
  //  [PLAYER]        ≈ (300, 190) → (160, 101)
  //  topic name      ≈ (300, 245) → (160, 131)
  //  ⭐ row          ≈ (93,  393) → (50,  210)
  //  ⚡ row          ≈ (93,  453) → (50,  242)

  static const double _hCardSz = 320.0;
  static const double _hS      = _hCardSz / 600; // 0.5333

  Widget _hallScrollCard(Map<String, dynamic> nom) {
    final nomId    = nom['nomId']    as String? ?? '';
    final title    = nom['title']    as String? ?? 'Untitled';
    final category = nom['category'] as String? ?? '';
    final hostName = nom['hostName'] as String? ?? 'Anonymous';
    final votes    = (nom['votes']   as int?)   ?? 0;
    final visitors = (nom['visitors'] as int?)  ?? 0;

    // Avatar constants
    const double avatarCx = 185 * _hS; // ≈ 98.7
    const double avatarCy = 261 * _hS; // ≈ 139.2
    const double avatarR  = 97  * _hS; // ≈ 51.7  → diam ≈ 103

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScrollThreadPage(scroll: nom)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          child: SizedBox(
            width: _hCardSz,
            height: _hCardSz,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Parchment background ───────────────────────────
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/HallScroll.png',
                    fit: BoxFit.fill,
                  ),
                ),

                // ── Category label (top text slot) ─────────────────
                Positioned(
                  left:  90  * _hS,
                  top:   108 * _hS,
                  right: 20 * _hS,
                  child: Text(
                    category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B2500),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                // ── Avatar inside the dashed circle ────────────────
                Positioned(
                  left: avatarCx - avatarR,
                  top:  avatarCy - avatarR,
                  child: ClipOval(
                    child: SizedBox(
                      width:  avatarR * 2,
                      height: avatarR * 2,
                      child: AcroAvatar(
                        initials: _initials(hostName),
                        seed: hostName,
                        size: avatarR * 2,
                      ),
                    ),
                  ),
                ),

                // ── Host name ([PLAYER] slot) ──────────────────────
                Positioned(
                  left:  300 * _hS,
                  top:   190 * _hS,
                  right: 24 * _hS,
                  child: Text(
                    hostName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceMono(
                      fontSize: 9,
                      color: const Color(0xFF3B2500),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                // ── Scroll title (topic name slot) ─────────────────
                Positioned(
                  left:  300 * _hS,
                  top:   240 * _hS,
                  right: 24 * _hS,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E1000),
                      height: 1.25,
                    ),
                  ),
                ),

                // ── ⭐ upvote count (tappable) ─────────────────────
                Positioned(
                  left: 93 * _hS,
                  top:  390 * _hS,
                  child: GestureDetector(
                    onTap: nomId.isNotEmpty
                        ? () => context.read<AppState>().upvoteNomination(nomId)
                        : null,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('⭐', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        '+$votes',
                        style: GoogleFonts.spaceMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4A2D00),
                        ),
                      ),
                    ]),
                  ),
                ),

                // ── ⚡ active visitors ──────────────────────────────
                Positioned(
                  left: 93 * _hS,
                  top:  452 * _hS,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('⚡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      '$visitors',
                      style: GoogleFonts.spaceMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4A2D00),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
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

  // Wide (tablet/web): 2 columns — 30% RANK | 70% INBOX
  Widget _assemblyWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildRanksPanel(showHeader: true)),
        VerticalDivider(width: 1, color: AcroColors.gold.withOpacity(0.10)),
        Expanded(flex: 7, child: _buildInboxPanel(showHeader: true)),
      ],
    );
  }

  // Narrow (mobile): sub-tabs RANK | INBOX
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
            Tab(text: 'INBOX'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _assembly,
            children: [
              _KeepAlivePage(child: _buildRanksPanel(showHeader: false)),
              _KeepAlivePage(child: _buildInboxPanel(showHeader: false)),
            ],
          ),
        ),
      ],
    );
  }

  // ── RANKS panel — Global leaderboard ────────────────────────────────────────

  Widget _buildRanksPanel({required bool showHeader}) {
    final myUid = context.read<AppState>().profile.uid;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AppState>().globalLeaderboardStream(),
      builder: (context, snap) {
        final board = snap.data ?? [];
        if (board.isEmpty) {
          return Column(
            children: [
              if (showHeader)
                Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 0), child: _panelHeader('GLOBAL RANK')),
              Expanded(child: _emptyState('🏛', 'No rankings yet.', 'Participate to earn your place.')),
            ],
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(0, showHeader ? 0 : 8, 0, 24),
          itemCount: board.length + (showHeader ? 1 : 0),
          itemBuilder: (_, i) {
            if (showHeader && i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: _panelHeader('GLOBAL RANK'),
              );
            }
            final entry = board[showHeader ? i - 1 : i];
            final pos   = showHeader ? i : i + 1;
            return _leaderboardRow(entry, pos, entry['uid'] == myUid);
          },
        );
      },
    );
  }

  Widget _leaderboardRow(Map<String, dynamic> entry, int pos, bool isMe) {
    final uid      = entry['uid']    as String? ?? '';
    final name     = entry['name']   as String? ?? 'Anonymous';
    final field    = entry['field']  as String? ?? '';
    final badgeId  = entry['badgeId'] as String? ?? '';
    final score    = (entry['score'] as double?) ?? 0.0;
    final badge    = BadgeEngine.fromId(badgeId);
    final info     = BadgeEngine.infoFor(badge);
    final ini      = _initials(name);

    final isMedal  = pos <= 3;
    final medals   = ['🥇', '🥈', '🥉'];
    final posLabel = isMedal ? medals[pos - 1] : '#$pos';

    void openProfile() {
      if (isMe) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UserProfilePopup(
          state: context.read<AppState>(),
          uid: uid, name: name, field: field, badgeId: badgeId, score: score,
        ),
      );
    }

    return InkWell(
      onTap: openProfile,
      splashColor: AcroColors.gold.withOpacity(0.06),
      highlightColor: Colors.transparent,
      child: Container(
      decoration: BoxDecoration(
        color: isMe
            ? AcroColors.gold.withOpacity(0.07)
            : Colors.transparent,
        border: isMe
            ? Border(left: BorderSide(color: AcroColors.gold.withOpacity(0.55), width: 2))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text(posLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMedal ? 16 : 11,
                color: isMedal ? Colors.white : Colors.white.withOpacity(0.35),
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              )),
        ),
        const SizedBox(width: 10),
        AcroAvatar(initials: ini, seed: uid, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMe ? AcroColors.gold : Colors.white.withOpacity(0.88),
                  )),
              Row(children: [
                Text(info.emoji, style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Text(info.name,
                    style: GoogleFonts.spaceMono(
                        fontSize: 8,
                        color: AcroColors.gold.withOpacity(0.60),
                        letterSpacing: 0.8)),
                if (field.isNotEmpty) ...[
                  Text('  ·  ', style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.18))),
                  Expanded(
                    child: Text(field,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.30))),
                  ),
                ],
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${(score * 100).toStringAsFixed(0)}',
            style: GoogleFonts.spaceMono(
                fontSize: 12,
                color: isMe ? AcroColors.gold : Colors.white.withOpacity(0.40),
                fontWeight: FontWeight.w700)),
      ]),
      ),
    );
  }

  // ── INBOX panel — Instagram DM style ────────────────────────────────────────

  Widget _buildInboxPanel({required bool showHeader}) {
    final state = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: _panelHeader('CONNECTIONS'),
          ),

        // ── Friends circle ─────────────────────────────────────────────
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: state.friendsStream(),
          builder: (context, snap) {
            final friends = snap.data ?? [];
            if (friends.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Text(
                  'Add friends from the leaderboard to see them here.',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25)),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: Text('YOUR CIRCLE',
                      style: GoogleFonts.spaceMono(fontSize: 8, color: Colors.white.withOpacity(0.30), letterSpacing: 1.5)),
                ),
                SizedBox(
                  height: 84,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: friends.length,
                    itemBuilder: (_, i) => _friendBubble(friends[i]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),

        Divider(height: 1, color: Colors.white.withOpacity(0.07)),

        // ── Notifications + requests unified list ──────────────────────
        Expanded(
          child: _buildNotifAndRequestList(state),
        ),
      ],
    );
  }

  Widget _friendBubble(Map<String, dynamic> friend) {
    final uid   = friend['uid']   as String? ?? '';
    final name  = friend['name']  as String? ?? 'Anonymous';
    final field = friend['field'] as String? ?? '';
    final ini   = _initials(name);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UserProfilePopup(
          state: context.read<AppState>(),
          uid: uid, name: name, field: field, badgeId: '', score: 0,
        ),
      ),
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AcroColors.gold, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AcroAvatar(initials: ini, seed: uid, size: 46),
              ),
            ),
            const SizedBox(height: 5),
            Text(name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.70))),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifAndRequestList(AppState state) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.friendRequestsStream(),
      builder: (context, frSnap) {
        final friendReqs = frSnap.data ?? [];
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: state.notificationsStream(),
          builder: (context, notifSnap) {
            final notifs = notifSnap.data ?? [];
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: state.requestsStream(),
              builder: (context, reqSnap) {
                final requests = reqSnap.data ?? [];
                if (friendReqs.isEmpty && notifs.isEmpty && requests.isEmpty) {
                  return _emptyState('📬', 'No requests yet.', 'Others in the Symposium can invite you.');
                }
                final items = <_InboxItem>[];
                if (friendReqs.isNotEmpty) {
                  items.add(_InboxItem.header('FRIEND REQUESTS'));
                  for (final fr in friendReqs) items.add(_InboxItem.friendReq(fr));
                }
                if (notifs.isNotEmpty) {
                  items.add(_InboxItem.header('NOTIFICATIONS'));
                  for (final n in notifs) items.add(_InboxItem.notif(n));
                }
                if (requests.isNotEmpty) {
                  items.add(_InboxItem.header('REQUESTS'));
                  for (final r in requests) items.add(_InboxItem.request(r));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    if (item.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                        child: Text(item.header!,
                            style: GoogleFonts.spaceMono(fontSize: 8, color: Colors.white.withOpacity(0.30), letterSpacing: 1.5)),
                      );
                    }
                    if (item.isFriendReq) return _friendRequestRow(item.data!);
                    if (item.isNotif) return _notifRow(item.data!);
                    return _dmRow(item.data!);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _notifRow(Map<String, dynamic> notif) {
    final notifId   = notif['notifId']   as String? ?? '';
    final fromUid   = notif['fromUid']   as String? ?? '';
    final fromName  = notif['fromName']  as String? ?? 'Someone';
    final fromField = notif['fromField'] as String? ?? '';
    final ts        = (notif['ts']       as int?)   ?? 0;
    final read      = notif['read']      as bool?   ?? false;
    final ini       = _initials(fromName);
    final timeLabel = _relativeTime(ts);

    return Dismissible(
      key: ValueKey(notifId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.white.withOpacity(0.05),
        child: Icon(Icons.check, size: 18, color: Colors.white.withOpacity(0.40)),
      ),
      onDismissed: (_) => context.read<AppState>().clearNotification(notifId),
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _UserProfilePopup(
            state: context.read<AppState>(),
            uid: fromUid, name: fromName, field: fromField, badgeId: '', score: 0,
          ),
        ),
        splashColor: AcroColors.gold.withOpacity(0.05),
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: read ? Colors.transparent : AcroColors.gold.withOpacity(0.04),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              AcroAvatar(initials: ini, seed: fromUid, size: 44),
              if (!read)
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: AcroColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0B0F1A), width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fromName,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(_notifLabel(notif),
                      style: TextStyle(
                          fontSize: 12,
                          color: read
                              ? Colors.white.withOpacity(0.35)
                              : AcroColors.gold.withOpacity(0.75))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(timeLabel,
                style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.white.withOpacity(0.28))),
          ]),
        ),
      ),
    );
  }

  String _notifLabel(Map<String, dynamic> notif) {
    final type = notif['type'] as String? ?? '';
    final name = notif['fromName'] as String? ?? 'Someone';
    switch (type) {
      case 'friend_accepted': return '$name accepted your friend request';
      default:                return '$name added you as a friend';
    }
  }

  Widget _friendRequestRow(Map<String, dynamic> req) {
    final fromUid  = req['fromUid']  as String? ?? '';
    final name     = req['name']     as String? ?? 'Anonymous';
    final field    = req['field']    as String? ?? '';
    final ts       = (req['ts']      as int?)   ?? 0;
    final ini      = _initials(name);
    final timeLabel = _relativeTime(ts);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AcroColors.gold.withOpacity(0.03),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        AcroAvatar(initials: ini, seed: fromUid, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              if (field.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(field,
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.40))),
              ],
              const SizedBox(height: 8),
              Row(children: [
                _smallBtn(
                  label: 'ACCEPT',
                  gold: true,
                  onTap: () => context.read<AppState>().acceptFriendRequest(fromUid, name, field),
                ),
                const SizedBox(width: 8),
                _smallBtn(
                  label: 'DECLINE',
                  gold: false,
                  onTap: () => context.read<AppState>().declineFriendRequest(fromUid),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(timeLabel,
            style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.white.withOpacity(0.28))),
      ]),
    );
  }

  Widget _smallBtn({required String label, required bool gold, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: gold ? AcroColors.gold.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: gold ? AcroColors.gold.withOpacity(0.55) : Colors.white.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: GoogleFonts.spaceMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: gold ? AcroColors.gold : Colors.white.withOpacity(0.40),
                letterSpacing: 1)),
      ),
    );
  }

  Widget _dmRow(Map<String, dynamic> req) {
    final name      = req['fromName']  as String? ?? 'Anonymous';
    final field     = req['fromField'] as String? ?? '';
    final quote     = req['fromQuote'] as String? ?? '';
    final ini       = _initials(name);
    final ts        = (req['ts']       as int?)   ?? 0;
    final timeLabel = _relativeTime(ts);

    return InkWell(
      onTap: () => _showDmDetail(req),
      splashColor: AcroColors.gold.withOpacity(0.06),
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Avatar with unread ring
          Stack(clipBehavior: Clip.none, children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AcroColors.gold.withOpacity(0.70), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AcroAvatar(initials: ini, seed: name, size: 44),
              ),
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: AcroColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0B0F1A), width: 2),
                ),
              ),
            ),
          ]),

          const SizedBox(width: 14),

          // Name + preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  quote.isNotEmpty ? '"$quote"' : field.isNotEmpty ? field : 'Wants to connect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.45),
                      fontStyle: quote.isNotEmpty ? FontStyle.italic : FontStyle.normal),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Time + unread dot
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(timeLabel,
                  style: GoogleFonts.spaceMono(fontSize: 9, color: Colors.white.withOpacity(0.30))),
              const SizedBox(height: 4),
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AcroColors.gold, shape: BoxShape.circle),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  void _showDmDetail(Map<String, dynamic> req) {
    final name      = req['fromName']      as String? ?? 'Anonymous';
    final field     = req['fromField']     as String? ?? '';
    final quote     = req['fromQuote']     as String? ?? '';
    final rawInterests = req['fromInterests'];
    final interests = rawInterests is List ? rawInterests.map((e) => e.toString()).toList() : <String>[];
    final ini       = _initials(name);
    final reqId     = req['reqId']         as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0F1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 24),

              // Profile row
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AcroColors.gold.withOpacity(0.55), width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: AcroAvatar(initials: ini, seed: name, size: 52),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                      if (field.isNotEmpty)
                        Text(field, style: TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
                    ],
                  ),
                ),
                Text('INVITES YOU', style: GoogleFonts.spaceMono(fontSize: 8, color: AcroColors.gold.withOpacity(0.6), letterSpacing: 1.5)),
              ]),

              if (quote.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('"$quote"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.50),
                        fontStyle: FontStyle.italic,
                        height: 1.5)),
              ],

              if (interests.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: interests.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(2)),
                    child: Text(t, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.white.withOpacity(0.50))),
                  )).toList(),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () { Navigator.pop(context); _decline(reqId); },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AcroColors.stoneLight,
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      textStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                    child: const Text('DECLINE'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); _accept(req); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AcroColors.gold,
                      foregroundColor: AcroColors.stone,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      textStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                    child: const Text('ACCEPT'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(int ts) {
    if (ts == 0) return '';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours   < 24) return '${diff.inHours}h';
    if (diff.inDays    < 7)  return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
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

// ── User profile popup (leaderboard + friend circle tap) ────────────────────

class _UserProfilePopup extends StatefulWidget {
  final AppState state;
  final String uid;
  // Seed values shown immediately; full data loaded async
  final String name;
  final String field;
  final String badgeId;
  final double score;

  const _UserProfilePopup({
    required this.state,
    required this.uid,
    required this.name,
    required this.field,
    required this.badgeId,
    required this.score,
  });

  @override
  State<_UserProfilePopup> createState() => _UserProfilePopupState();
}

class _UserProfilePopupState extends State<_UserProfilePopup> {
  bool _loading     = true;
  bool _isFriend    = false;
  bool _isPending   = false;
  bool _hasRequest  = false;
  bool _isFollowing = false;
  bool _isBlocked   = false;

  // Full profile data fetched from Firebase
  String       _name       = '';
  String       _field      = '';
  String       _badgeId    = '';
  double       _score      = 0;
  String       _headspace  = '';
  List<String> _interests  = [];
  int          _minutes    = 0;
  int          _quotes     = 0;
  int          _nomRecv    = 0;
  int          _topics     = 0;

  @override
  void initState() {
    super.initState();
    // Seed immediately with what the caller passed
    _name    = widget.name;
    _field   = widget.field;
    _badgeId = widget.badgeId;
    _score   = widget.score;
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.state.userRelation(widget.uid),
      widget.state.fetchUserProfile(widget.uid),
    ]);

    final rel     = results[0] as Map<String, bool>;
    final profile = results[1] as Map<String, dynamic>; // ignore: unnecessary_cast

    if (!mounted) return;

    final rawTopics = profile['topicEngagement'];
    final topics    = rawTopics is Map ? rawTopics.length : 0;
    final minutes   = (profile['totalMinutesActive'] as int?) ?? 0;
    final quotes    = (profile['quoteCount']          as int?) ?? 0;
    final nomRecv   = (profile['nominationsReceived'] as int?) ?? 0;
    final score = BadgeEngine.computeScore(
      totalMinutesActive: minutes,
      quoteCount: quotes,
      nominationsReceived: nomRecv,
      distinctTopics: topics,
    );
    final rawInterests = profile['interests'];
    final interests = rawInterests is List
        ? rawInterests.map((e) => e.toString()).toList()
        : <String>[];

    setState(() {
      _isFriend    = rel['isFriend']    ?? false;
      _isPending   = rel['isPending']   ?? false;
      _hasRequest  = rel['hasRequest']  ?? false;
      _isFollowing = rel['isFollowing'] ?? false;
      _isBlocked   = rel['isBlocked']   ?? false;
      _name        = (profile['name']      as String?) ?? widget.name;
      _field       = (profile['field']     as String?) ?? widget.field;
      _badgeId     = BadgeEngine.fromStats(profile).name;
      _headspace   = (profile['headspace'] as String?) ?? '';
      _interests   = interests;
      _minutes     = minutes;
      _quotes      = quotes;
      _nomRecv     = nomRecv;
      _topics      = topics;
      _score       = score;
      _loading     = false;
    });
  }

  Future<void> _handleFriendAction() async {
    if (_isFriend) {
      setState(() => _isFriend = false);
      await widget.state.removeFriend(widget.uid);
    } else if (_isPending) {
      setState(() => _isPending = false);
      await widget.state.cancelFriendRequest(widget.uid);
    } else if (_hasRequest) {
      setState(() { _hasRequest = false; _isFriend = true; });
      await widget.state.acceptFriendRequest(widget.uid, _name, _field);
    } else {
      setState(() => _isPending = true);
      await widget.state.sendFriendRequest(widget.uid, _name, _field);
    }
  }

  Future<void> _toggleFollow() async {
    final was = _isFollowing;
    setState(() => _isFollowing = !was);
    if (was) {
      await widget.state.unfollowUser(widget.uid);
    } else {
      await widget.state.followUser(widget.uid, _name);
    }
  }

  Future<void> _toggleBlock() async {
    final was = _isBlocked;
    setState(() => _isBlocked = !was);
    if (was) {
      await widget.state.unblockUser(widget.uid);
    } else {
      await widget.state.blockUser(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ini      = _initials(_name);
    final badge    = BadgeEngine.fromId(_badgeId);
    final badgeInfo = BadgeEngine.infoFor(badge);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1320),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 24),

            // ── Avatar + name + badge ────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AcroColors.gold.withOpacity(0.60), width: 2.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AcroAvatar(initials: ini, seed: widget.uid, size: 56),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (_field.isNotEmpty)
                      Text(_field, style: TextStyle(fontSize: 12, color: AcroColors.stoneLight)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(badgeInfo.emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                      Text(badgeInfo.name,
                          style: GoogleFonts.spaceMono(
                              fontSize: 9, color: AcroColors.gold.withOpacity(0.75), letterSpacing: 1)),
                    ]),
                  ],
                ),
              ),
            ]),

            // ── Headspace cloud thought ──────────────────────────────────
            if (_headspace.isNotEmpty) ...[
              const SizedBox(height: 20),
              _CloudThought(text: _headspace),
            ],

            // ── Rank stats (friends only) ────────────────────────────────
            if (!_loading && _isFriend) ...[
              const SizedBox(height: 20),
              Row(children: [
                Text('RANK', style: GoogleFonts.spaceMono(
                    fontSize: 8, color: Colors.white.withOpacity(0.30), letterSpacing: 1.5)),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.07), height: 1)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Text('SCORE', style: GoogleFonts.spaceMono(
                    fontSize: 8, color: Colors.white.withOpacity(0.25), letterSpacing: 1.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: _score.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.07),
                      valueColor: const AlwaysStoppedAnimation(AcroColors.gold),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(_score * 100).toStringAsFixed(0)}',
                    style: GoogleFonts.spaceMono(
                        fontSize: 10, color: AcroColors.gold, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _miniStat('⏱', '${(_minutes / 60).toStringAsFixed(1)}h', 'active'),
                _miniStat('📜', '$_quotes', 'quotes'),
                _miniStat('⭐', '$_nomRecv', 'noms'),
                _miniStat('🗂', '$_topics', 'topics'),
              ]),
            ] else if (!_loading) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.white.withOpacity(0.25)),
                  const SizedBox(width: 10),
                  Text('Rank stats are visible to friends only',
                      style: GoogleFonts.spaceMono(
                          fontSize: 9, color: Colors.white.withOpacity(0.30), letterSpacing: 0.5)),
                ]),
              ),
            ],

            // ── Interests ────────────────────────────────────────────────
            if (_interests.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Text('INTERESTS', style: GoogleFonts.spaceMono(
                    fontSize: 8, color: Colors.white.withOpacity(0.30), letterSpacing: 1.5)),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.07), height: 1)),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _interests.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      border: Border.all(color: AcroColors.gold.withOpacity(0.22)),
                      borderRadius: BorderRadius.circular(2)),
                  child: Text(t,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 9,
                          color: Colors.white.withOpacity(0.55))),
                )).toList(),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 14),

            // ── Action buttons ───────────────────────────────────────────
            if (_loading)
              const SizedBox(height: 48, child: Center(
                  child: CircularProgressIndicator(color: AcroColors.gold, strokeWidth: 2)))
            else
              Row(children: [
                Expanded(child: _actionBtn(
                  icon: _isFriend
                      ? Icons.people
                      : _hasRequest
                          ? Icons.person_add
                          : Icons.person_add_outlined,
                  label: _isFriend
                      ? 'FRIENDS'
                      : _isPending
                          ? 'PENDING'
                          : _hasRequest
                              ? 'ACCEPT'
                              : 'ADD FRIEND',
                  active: _isFriend || _hasRequest,
                  dimmed: _isPending,
                  onTap: _handleFriendAction,
                )),
                const SizedBox(width: 10),
                Expanded(child: _actionBtn(
                  icon: _isFollowing ? Icons.notifications_active : Icons.notifications_none,
                  label: _isFollowing ? 'FOLLOWING' : 'FOLLOW',
                  active: _isFollowing,
                  onTap: _toggleFollow,
                )),
                const SizedBox(width: 10),
                SizedBox(width: 52, child: _actionBtn(
                  icon: _isBlocked ? Icons.block : Icons.block_outlined,
                  label: '',
                  active: _isBlocked,
                  onTap: _toggleBlock,
                  isDestructive: true,
                  compact: true,
                )),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text('$icon $value',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.80),
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: GoogleFonts.spaceMono(
                  fontSize: 7, color: Colors.white.withOpacity(0.28), letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool compact = false,
    bool dimmed = false,
  }) {
    final activeColor = isDestructive ? Colors.redAccent : AcroColors.gold;
    final borderColor = dimmed
        ? Colors.white.withOpacity(0.08)
        : active ? activeColor.withOpacity(0.60) : Colors.white.withOpacity(0.12);
    final bgColor = dimmed
        ? Colors.white.withOpacity(0.02)
        : active ? activeColor.withOpacity(0.12) : Colors.white.withOpacity(0.04);
    final fgColor = dimmed
        ? Colors.white.withOpacity(0.28)
        : active ? activeColor : Colors.white.withOpacity(0.55);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: compact ? 0 : 8),
        decoration: BoxDecoration(
            color: bgColor, border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(3)),
        child: compact
            ? Center(child: Icon(icon, size: 18, color: fgColor))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 14, color: fgColor),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
                          color: fgColor, letterSpacing: 1.5)),
                ],
              ]),
      ),
    );
  }
}

// ── Cloud thought bubble (imported from side_menu context) ───────────────────
// Mirrors the _CloudThought in side_menu.dart — same visual language

class _CloudThought extends StatelessWidget {
  final String text;
  const _CloudThought({required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CloudPainter(
          color: Colors.white.withOpacity(0.06),
          borderColor: Colors.white.withOpacity(0.18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Text(
          '"$text"',
          style: GoogleFonts.cormorant(
              fontSize: 15, fontStyle: FontStyle.italic,
              color: Colors.white.withOpacity(0.72), height: 1.5),
        ),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  const _CloudPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint  = Paint()..color = color..style = PaintingStyle.fill;
    final border = Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final path   = Path();
    final r      = size.height * 0.38;
    path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - 10), Radius.circular(r * 0.7)));
    path.addOval(Rect.fromCircle(center: Offset(20, size.height - 8), radius: 6));
    path.addOval(Rect.fromCircle(center: Offset(12, size.height - 2), radius: 4));
    path.addOval(Rect.fromCircle(center: Offset(6, size.height + 2), radius: 2.5));
    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_CloudPainter old) =>
      old.color != color || old.borderColor != borderColor;
}

// ── Keep-alive wrapper for TabBarView children ──────────────────────────────
// Flutter's TabBarView destroys off-screen pages by default. This wrapper
// opts the page into AutomaticKeepAlive so streams stay subscribed, scroll
// positions are remembered, and animations don't reset when switching tabs.

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by the mixin
    return widget.child;
  }
}

// ── Mouse-drag scroll behavior for web ──────────────────────────────────────
// MaterialScrollBehavior subclass that opts mouse drags into the scroll arena.
// Unlike copyWith(), a subclass override is guaranteed to apply at all times.

class _MouseDragBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

// ── Inbox list item discriminated union ─────────────────────────────────────

class _InboxItem {
  final String? header;
  final Map<String, dynamic>? data;
  final bool isNotif;
  final bool isFriendReq;

  const _InboxItem._({this.header, this.data, this.isNotif = false, this.isFriendReq = false});

  factory _InboxItem.header(String label) => _InboxItem._(header: label);
  factory _InboxItem.notif(Map<String, dynamic> d) => _InboxItem._(data: d, isNotif: true);
  factory _InboxItem.request(Map<String, dynamic> d) => _InboxItem._(data: d);
  factory _InboxItem.friendReq(Map<String, dynamic> d) => _InboxItem._(data: d, isFriendReq: true);

  bool get isHeader => header != null;
}
