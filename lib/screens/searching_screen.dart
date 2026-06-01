import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    state.clearMatch();

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
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => _buildPulseRings(_pulse.value),
            ),
            const SizedBox(height: 48),
            Text(
              'SEARCHING THE AGORA',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AcroColors.stoneLight,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            _AnimatedDots(),
            const SizedBox(height: 48),
            TextButton(
              onPressed: _cancel,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AcroColors.stoneLight.withOpacity(0.5),
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

  Widget _buildPulseRings(double t) {
    final size = 80.0 + 40.0 * t;
    final outerSize = 120.0 + 60.0 * t;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AcroColors.gold.withOpacity(0.1 + 0.1 * (1 - t)),
                width: 2,
              ),
            ),
          ),
          // Middle ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AcroColors.gold.withOpacity(0.2 + 0.15 * (1 - t)),
                width: 2,
              ),
            ),
          ),
          // Center — pixel Greek column icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AcroColors.gold.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AcroColors.gold.withOpacity(0.6)),
            ),
            child: Center(
              child: Text(
                'Α',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  color: AcroColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> {
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _step;
    return Text(
      dots.padRight(3),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 20,
        color: AcroColors.gold,
        letterSpacing: 4,
      ),
    );
  }
}
