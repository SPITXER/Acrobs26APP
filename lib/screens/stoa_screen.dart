import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/acro_mode.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
import 'room_screen.dart';

const _kInterests = [
  'Philosophy', 'Science', 'Politics', 'Economics',
  'History', 'Ethics', 'Technology', 'Literature',
  'Psychology', 'Art', 'Mathematics', 'Theology',
];

class StoaScreen extends StatefulWidget {
  const StoaScreen({super.key});

  @override
  State<StoaScreen> createState() => _StoaScreenState();
}

class _StoaScreenState extends State<StoaScreen> {
  // Onboarding
  final _nameCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _selectedInterests = <String>{};
  bool _onboarded = false;

  // Browsing
  List<Map<String, dynamic>> _cards = [];
  int _cardIndex = 0;
  bool _likeSent = false;
  StreamSubscription? _poolSub;
  StreamSubscription? _matchSub;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().profile;
    if (profile.name.isNotEmpty && profile.mode == AcroMode.stoa) {
      _onboarded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startBrowsing());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fieldCtrl.dispose();
    _poolSub?.cancel();
    _matchSub?.cancel();
    if (_onboarded) {
      context.read<AppState>().removeFromStoaPool();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Onboarding → browsing
  // ---------------------------------------------------------------------------

  Future<void> _completeOnboarding() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final state = context.read<AppState>();
    state.setProfile(
      name: name,
      field: _fieldCtrl.text.trim(),
      mode: AcroMode.stoa,
      interests: _selectedInterests.toList(),
    );

    await state.publishToStoaPool();
    setState(() => _onboarded = true);
    _startBrowsing();
  }

  void _startBrowsing() {
    final state = context.read<AppState>();

    _poolSub = state.browsePoolStream().listen((cards) {
      if (mounted) {
        setState(() {
          _cards = cards;
          if (_cardIndex >= _cards.length) _cardIndex = 0;
        });
      }
    });

    _matchSub = state.matchStream().listen((matchData) {
      if (matchData != null && mounted) {
        _navigateToRoom(matchData);
      }
    });
  }

  void _navigateToRoom(Map<String, dynamic> matchData) {
    final state = context.read<AppState>();
    final room = state.buildRoomFromMatch(matchData);
    state.enterRoom(room);
    state.clearMatch();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoomScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // Card interactions
  // ---------------------------------------------------------------------------

  void _skip() {
    if (_cards.isEmpty) return;
    setState(() {
      _cardIndex = (_cardIndex + 1) % _cards.length;
      _likeSent = false;
    });
  }

  Future<void> _connect() async {
    if (_cards.isEmpty || _cardIndex >= _cards.length) return;
    final card = _cards[_cardIndex];
    final toUid = card['uid'] as String? ?? '';
    final toName = card['name'] as String? ?? 'Anonymous';
    final toIni = _initials(toName);

    setState(() => _likeSent = true);

    final state = context.read<AppState>();
    final roomId = await state.sendStoaLike(toUid, toName, toIni);

    if (roomId != null && mounted) {
      final matchData = {
        'roomId': roomId,
        'partnerId': toUid,
        'partnerName': toName,
        'partnerIni': toIni,
        'isHost': true,
      };
      _navigateToRoom(matchData);
    } else if (mounted) {
      // Like sent, no mutual yet — move to next card
      await Future.delayed(const Duration(milliseconds: 800));
      _skip();
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AcroColors.stoneLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '🚶  STOA',
          style: GoogleFonts.dmSans(
            color: AcroColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ),
      body: _onboarded ? _buildBrowsing() : _buildOnboarding(),
    );
  }

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  Widget _buildOnboarding() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('SET UP YOUR STOA CARD'),
              const SizedBox(height: 4),
              Text(
                'Your card is shown to others. Choose wisely.',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.35)),
              ),
              const SizedBox(height: 28),

              _fieldLabel('NAME'),
              _pixelInput(_nameCtrl, 'Your full name…'),

              _fieldLabel('FIELD / EXPERTISE'),
              _pixelInput(_fieldCtrl, 'e.g. Political Philosophy, Neuroscience…'),

              _fieldLabel('INTERESTS  (pick a few)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kInterests.map((interest) {
                  final selected = _selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () => setState(() => selected
                        ? _selectedInterests.remove(interest)
                        : _selectedInterests.add(interest)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AcroColors.gold.withOpacity(0.15)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AcroColors.gold
                              : AcroColors.gold.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        interest,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: selected
                              ? AcroColors.gold
                              : Colors.white.withOpacity(0.45),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2)),
                    textStyle: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        letterSpacing: 2),
                  ),
                  child: const Text('ENTER THE STOA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Browsing (card stack)
  // ---------------------------------------------------------------------------

  Widget _buildBrowsing() {
    if (_cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🚶', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text(
              'The Stoa is quiet.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your card is visible. Waiting for others…',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ],
        ),
      );
    }

    final card = _cards[_cardIndex % _cards.length];
    final name = card['name'] as String? ?? 'Anonymous';
    final field = card['field'] as String? ?? '';
    final rawInterests = card['interests'];
    final interests = rawInterests is List
        ? rawInterests.map((e) => e.toString()).toList()
        : <String>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${_cardIndex + 1} of ${_cards.length}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Container(
              width: 360,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: AcroColors.gold.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AcroColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AcroColors.gold.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(
                        _initials(name),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AcroColors.gold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (field.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      field,
                      style: TextStyle(
                        fontSize: 13,
                        color: AcroColors.stoneLight,
                      ),
                    ),
                  ],

                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: interests.map((i) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AcroColors.gold.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          i,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.55),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _skip,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AcroColors.stoneLight,
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.15)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          child: Text(
                            'SKIP',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _likeSent ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _likeSent
                                ? AcroColors.gold.withOpacity(0.3)
                                : AcroColors.gold,
                            foregroundColor: AcroColors.stone,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2)),
                            textStyle: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2),
                          ),
                          child: Text(_likeSent ? 'SENT ✓' : 'CONNECT'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  Widget _pixelInput(TextEditingController ctrl, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
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
              borderSide:
                  BorderSide(color: AcroColors.gold.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide:
                  BorderSide(color: AcroColors.gold.withOpacity(0.2)),
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
