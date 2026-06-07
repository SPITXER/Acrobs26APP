import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/acro_theme.dart';
import 'room_screen.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  StreamSubscription? _queueWatcher;
  StreamSubscription? _matchListener;
  bool _matched = false;
  late final String _loadingWord;

  static const _words = ['Wandering', 'Contemplating', 'Questioning'];

  @override
  void initState() {
    super.initState();
    _loadingWord = _words[Random().nextInt(_words.length)];
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearching());
  }

  Future<void> _startSearching() async {
    final state = context.read<AppState>();
    await state.joinAgoraQueue();

    _matchListener = state.matchStream().listen((matchData) {
      if (matchData != null && !_matched && mounted) {
        _onMatchFound(matchData);
      }
    });

    _queueWatcher = state.watchAgoraQueue();
  }

  void _onMatchFound(Map<String, dynamic> matchData) {
    _matched = true;
    final state = context.read<AppState>();
    final room = state.buildRoomFromMatch(matchData);
    state.enterRoom(room);
    state.markMatchHandled();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoomScreen()),
    );
  }

  Future<void> _cancel() async {
    _queueWatcher?.cancel();
    _matchListener?.cancel();
    await context.read<AppState>().leaveAgoraQueue();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _queueWatcher?.cancel();
    _matchListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ghost with pulsing glow
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AcroColors.gold
                          .withOpacity(0.04 + 0.08 * _pulse.value),
                      blurRadius: 50,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/ghost_socrates_gold.png',
                  width: 110 + 6 * _pulse.value,
                  height: 110 + 6 * _pulse.value,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 52),

            // one randomly chosen term per session
            _TermWidget(word: _loadingWord, delayMs: 0),

            const SizedBox(height: 52),

            TextButton(
              onPressed: _cancel,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AcroColors.stoneLight.withOpacity(0.45),
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing term: Word + animated dashes ──────────────────────────────────

class _TermWidget extends StatefulWidget {
  final String word;
  final int delayMs;
  const _TermWidget({required this.word, required this.delayMs});

  @override
  State<_TermWidget> createState() => _TermWidgetState();
}

class _TermWidgetState extends State<_TermWidget>
    with SingleTickerProviderStateMixin {
  int  _dashes = 0;
  Timer? _step;
  Timer? _delay;
  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _delay = Timer(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      _step = Timer.periodic(const Duration(milliseconds: 210), (_) {
        if (mounted) setState(() => _dashes = (_dashes + 1) % 6);
      });
    });
  }

  @override
  void dispose() {
    _glow.dispose();
    _step?.cancel();
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        final dashStr = '─' * _dashes;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              widget.word,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.75),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              dashStr.padRight(5, ' '), // fixed width keeps layout stable
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                color: AcroColors.gold
                    .withOpacity(0.45 + 0.45 * _glow.value),
                letterSpacing: 3,
              ),
            ),
          ],
        );
      },
    );
  }
}
