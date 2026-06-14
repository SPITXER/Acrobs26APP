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
import '../widgets/side_menu.dart';
import 'room_screen.dart';

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
    with SingleTickerProviderStateMixin {

  // Profile setup form (shown after auth if no profile set)
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

  // Tabs (Discover / Inbox / Canon)
  late TabController _tabs;

  // Sent requests (local tracking to prevent double-tap)
  final _sentTo = <String>{};

  // Match listener
  StreamSubscription? _matchSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);

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
    // signInWithRedirect navigates away; result is handled on return in AppState._init()
    await context.read<AppState>().signInWithGoogle();
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
  // Symposium entry (called once auth + profile are confirmed)
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

    // Surface any Google redirect sign-in error (set by AppState._handleGoogleRedirectResult)
    final googleErr = state.googleSignInError;
    if (googleErr != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        state.clearGoogleSignInError();
        String msg = 'Google sign-in failed. Try again.';
        if (googleErr.contains('unauthorized-domain'))  msg = 'Domain not authorized for Google sign-in.';
        else if (googleErr.contains('operation-not-allowed')) msg = 'Google sign-in not enabled. Contact support.';
        else if (googleErr.contains('popup-closed') || googleErr.contains('cancelled')) msg = 'Sign-in cancelled.';
        setState(() { _authLoading = false; _authError = msg; });
      });
    }

    // Gate: permanent account required
    if (!state.isPermanentAccount) {
      return _buildAuthScaffold();
    }

    // Auto-enter if profile already set (returning user or after Google sign-in)
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
                  Tab(text: 'DISCOVER'),
                  Tab(text: 'INBOX'),
                  Tab(text: 'CANON'),
                ],
              )
            : null,
      ),
      endDrawer: const SideMenu(),
      body: _onboarded ? _buildHome() : _buildProfileSetup(),
    );
  }

  // ---------------------------------------------------------------------------
  // Auth wall (not signed in)
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

                        // Google button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _authLoading ? null : _googleSignIn,
                            icon: const Text('G',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87)),
                            label: const Text('CONTINUE WITH GOOGLE'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              textStyle: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        Row(children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.10))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white.withOpacity(0.25))),
                          ),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.10))),
                        ]),
                        const SizedBox(height: 16),

                        // Email toggle
                        if (!_showEmailAuth)
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() => _showEmailAuth = true),
                              child: Text('Use email instead',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.40))),
                            ),
                          ),

                        // Email form
                        if (_showEmailAuth) ...[
                          // Sign-in / Create-account toggle
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
                          _authField(_authPassCtrl,  'Password (6+ chars)', TextInputType.visiblePassword, obscure: true),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _authLoading ? null : _emailAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AcroColors.gold,
                                foregroundColor: AcroColors.stone,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                textStyle: GoogleFonts.dmSans(
                                    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
                              ),
                              child: Text(_authLoading
                                  ? 'PLEASE WAIT…'
                                  : (_authMode == _AuthMode.createAccount ? 'CREATE ACCOUNT' : 'SIGN IN')),
                            ),
                          ),
                        ],

                        if (_authError != null) ...[
                          const SizedBox(height: 12),
                          Text(_authError!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ],

                        if (_authLoading) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(AcroColors.gold), strokeWidth: 2)),
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
          border: Border.all(
            color: selected ? AcroColors.gold : AcroColors.gold.withOpacity(0.22),
          ),
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

  Widget _authField(TextEditingController ctrl, String hint, TextInputType type,
      {bool obscure = false}) =>
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: AcroColors.gold)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );

  // ---------------------------------------------------------------------------
  // Profile setup (authenticated but no profile yet)
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
                      Text(
                        'Your full profile is visible to others. Make it count.',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35)),
                      ),
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
                                border: Border.all(
                                  color: sel ? AcroColors.gold : AcroColors.gold.withOpacity(0.2),
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                interest,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: sel ? AcroColors.gold : Colors.white.withOpacity(0.45),
                                ),
                              ),
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
                            textStyle: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2,
                            ),
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
              Image.asset(
                'assets/images/Sym2.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
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
  // Home — tabs
  // ---------------------------------------------------------------------------

  Widget _buildHome() {
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverToBoxAdapter(child: _courtroomBanner()),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [_buildDiscover(), _buildInbox(), _buildCanon()],
      ),
    );
  }

  // Discover — scroll list of symposium profiles
  Widget _buildDiscover() {
    final state = context.read<AppState>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.symposiumPoolStream(),
      builder: (context, snap) {
        final profiles = snap.data ?? [];
        if (profiles.isEmpty) {
          return _emptyState(
            '🍷',
            'The Symposium awaits.',
            'Your profile is visible. Others will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: profiles.length,
          itemBuilder: (_, i) => _profileCard(profiles[i]),
        );
      },
    );
  }

  Widget _profileCard(Map<String, dynamic> card) {
    final uid = card['uid'] as String? ?? '';
    final name = card['name'] as String? ?? 'Anonymous';
    final field = card['field'] as String? ?? '';
    final quote = card['quote'] as String? ?? '';
    final rawInterests = card['interests'];
    final interests = rawInterests is List
        ? rawInterests.map((e) => e.toString()).toList()
        : <String>[];
    final ini = _initials(name);
    final sent = _sentTo.contains(uid);

    final badgeId = card['badgeId'] as String? ?? '';
    final badge   = BadgeEngine.fromId(badgeId);
    final badgeInfo = BadgeEngine.infoFor(badge);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CloudCornerBox(
        backgroundColor: Colors.white.withOpacity(0.03),
        borderColor: AcroColors.gold.withOpacity(0.20),
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AcroAvatar(initials: ini, seed: uid, size: 54),
            const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (field.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    field,
                    style: TextStyle(fontSize: 12, color: AcroColors.stoneLight),
                  ),
                ],
                ...[
                  const SizedBox(height: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(badgeInfo.emoji,
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(badgeInfo.name,
                        style: GoogleFonts.spaceMono(
                            fontSize: 9,
                            color: AcroColors.gold.withOpacity(0.75),
                            letterSpacing: 1)),
                    const SizedBox(width: 4),
                    Text('· ${badgeInfo.domain}',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.28))),
                  ]),
                ],
                if (quote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '"$quote"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.45),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (interests.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: interests.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.50),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: sent ? null : () => _sendRequest(uid),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: sent ? AcroColors.stoneLight : AcroColors.gold,
                      side: BorderSide(
                        color: sent
                            ? AcroColors.gold.withOpacity(0.20)
                            : AcroColors.gold.withOpacity(0.55),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      textStyle: GoogleFonts.dmSans(
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2,
                      ),
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

  // Inbox — incoming requests
  Widget _buildInbox() {
    final state = context.read<AppState>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: state.requestsStream(),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return _emptyState(
            '📜',
            'No requests yet.',
            'Others in the Symposium can send you a request.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: requests.length,
          itemBuilder: (_, i) => _requestCard(requests[i]),
        );
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final name = req['fromName'] as String? ?? 'Anonymous';
    final field = req['fromField'] as String? ?? '';
    final quote = req['fromQuote'] as String? ?? '';
    final rawInterests = req['fromInterests'];
    final interests = rawInterests is List
        ? rawInterests.map((e) => e.toString()).toList()
        : <String>[];
    final ini = _initials(name);
    final reqId = req['reqId'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CloudCornerBox(
        backgroundColor: AcroColors.gold.withOpacity(0.04),
        borderColor: AcroColors.gold.withOpacity(0.30),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              AcroAvatar(initials: ini, seed: name, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (field.isNotEmpty)
                      Text(
                        field,
                        style: TextStyle(fontSize: 12, color: AcroColors.stoneLight),
                      ),
                  ],
                ),
              ),
              Text(
                'INVITES YOU',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: AcroColors.gold.withOpacity(0.6),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          if (quote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '"$quote"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.45),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          if (interests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: interests.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.50),
                  ),
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _decline(reqId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AcroColors.stoneLight,
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    textStyle: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2,
                    ),
                  ),
                  child: const Text('DECLINE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _accept(req),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AcroColors.gold,
                    foregroundColor: AcroColors.stone,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    textStyle: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2,
                    ),
                  ),
                  child: const Text('ACCEPT'),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  // Canon — permanently nominated arguments from the Stoa
  Widget _buildCanon() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AppState>().nominationsStream(),
      builder: (context, snap) {
        final nominations = snap.data ?? [];
        if (nominations.isEmpty) {
          return _emptyState(
            '⭐',
            'The canon is empty.',
            'Nominate arguments in the Stoa to send them here forever.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: nominations.length,
          itemBuilder: (_, i) => _canonCard(nominations[i]),
        );
      },
    );
  }

  Widget _canonCard(Map<String, dynamic> nom) {
    final title           = nom['title']           as String? ?? 'Untitled';
    final thesis          = nom['thesis']           as String? ?? '';
    final category        = nom['category']         as String? ?? '';
    final hostName        = nom['hostName']         as String? ?? 'Anonymous';
    final nominatedByName = nom['nominatedByName']  as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CloudCornerBox(
        backgroundColor: Colors.white.withOpacity(0.03),
        borderColor: AcroColors.gold.withOpacity(0.20),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              const Icon(Icons.stars, size: 11, color: AcroColors.gold),
              const SizedBox(width: 4),
              Text('CANON',
                  style: GoogleFonts.spaceMono(
                      fontSize: 9,
                      color: AcroColors.gold.withOpacity(0.60),
                      letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 14),
            Text(title,
                style: GoogleFonts.cormorant(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.3)),
            if (thesis.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"$thesis"',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.38),
                      fontStyle: FontStyle.italic,
                      height: 1.4)),
            ],
            const SizedBox(height: 14),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            Row(children: [
              Text(hostName,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.50))),
              const Spacer(),
              if (nominatedByName.isNotEmpty)
                Text('nominated by $nominatedByName',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.22))),
            ]),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _emptyState(String icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.2)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.35),
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AcroColors.stoneLight,
          letterSpacing: 3,
        ),
      );

  Widget _input(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
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
                color: Colors.white.withOpacity(0.22), fontFamily: 'monospace'),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(color: AcroColors.gold.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: const BorderSide(color: AcroColors.gold),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );
}
