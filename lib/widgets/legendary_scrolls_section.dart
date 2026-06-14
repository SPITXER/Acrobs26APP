import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/acro_theme.dart';
import 'avatar.dart';

// Scroll.png is 2048×2048 (square). All positions are expressed as fractions
// of the source image so they scale correctly to any chip size.
//
// Measured from the 2048×2048 source:
//   Circle centre  ≈ (28.5%, 35.5%)   radius ≈ 16.5%
//   [PLAYER] start ≈ (49%,   21%)
//   TOPIC NAME     ≈ (48%,   32%)
//   ⭐ row start   ≈ (13%,   59.5%)
//   ⚡ row start   ≈ (55.5%, 59.5%)
//
// Chip is square to match the square source (no distortion under BoxFit.fill).
// 25 % smaller than the previous 172×162 → 130×130.

const double _cW = 130.0;
const double _cH = 130.0;

// Circle
const double _avatarCx = 0.285 * _cW; // ≈ 37.1
const double _avatarCy = 0.355 * _cH; // ≈ 46.2
const double _avatarR  = 0.165 * _cW; // ≈ 21.5  → diameter ≈ 43

// Text slots
const double _playerX  = 0.490 * _cW; // ≈ 63.7
const double _playerY  = 0.210 * _cH; // ≈ 27.3

const double _topicX   = 0.480 * _cW; // ≈ 62.4
const double _topicY   = 0.320 * _cH; // ≈ 41.6

// Stats row
const double _starsX   = 0.130 * _cW; // ≈ 16.9
const double _starsY   = 0.595 * _cH; // ≈ 77.4

const double _boltX    = 0.555 * _cW; // ≈ 72.2
const double _boltY    = 0.595 * _cH; // ≈ 77.4

const double kLegendSectionHeight = 442.0;

class LegendaryScrollsSection extends StatefulWidget {
  final List<Map<String, dynamic>> scrolls;
  final void Function(Map<String, dynamic>) onScrollTap;

  const LegendaryScrollsSection({
    super.key,
    required this.scrolls,
    required this.onScrollTap,
  });

  @override
  State<LegendaryScrollsSection> createState() =>
      _LegendaryScrollsSectionState();
}

class _LegendaryScrollsSectionState extends State<LegendaryScrollsSection>
    with SingleTickerProviderStateMixin {
  double _angle = -pi / 6;
  double _velocity = 0.0;
  late Ticker _ticker;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == null) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick!).inMilliseconds / 1000.0;
    setState(() {
      _angle += _velocity * dt * 60;
      _velocity *= 0.93;
    });
    if (_velocity.abs() < 0.0008) {
      _velocity = 0;
      _ticker.stop();
      _lastTick = null;
    } else {
      _lastTick = elapsed;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_ticker.isActive) {
      _ticker.stop();
      _lastTick = null;
    }
    setState(() => _angle += d.delta.dx * 0.009);
  }

  void _onPanEnd(DragEndDetails d) {
    _velocity = d.velocity.pixelsPerSecond.dx * 0.00012;
    _lastTick = null;
    if (_velocity.abs() > 0.0008) _ticker.start();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: SizedBox(
        height: kLegendSectionHeight,
        child: LayoutBuilder(
          builder: (ctx, constraints) =>
              _buildStack(constraints.maxWidth, constraints.maxHeight),
        ),
      ),
    );
  }

  Widget _buildStack(double w, double h) {
    final cx = w * 0.50;
    final cy = h * 0.67;

    // Wider orbit — rx raised from 0.215 to 0.30; cap raised from 80 to 115.
    final rx = min(w * 0.30, 115.0);
    final ry = h * 0.090;

    final count = widget.scrolls.length.clamp(1, 3);

    final items = List.generate(count, (i) {
      final a = _angle + (i * 2 * pi / 3);
      return _ScrollItem(index: i, angle: a);
    })..sort((a, b) => sin(a.angle).compareTo(sin(b.angle)));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Island
        Positioned.fill(
          child: Image.asset(
            'assets/images/Legendisland.png',
            fit: BoxFit.contain,
            alignment: const Alignment(0, 0.80),
          ),
        ),

        // Title
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('✦', style: TextStyle(fontSize: 10, color: AcroColors.gold.withOpacity(0.7))),
              const SizedBox(width: 10),
              Text(
                'LEGENDARY SCROLLS',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AcroColors.stoneLight,
                  letterSpacing: 3.5,
                ),
              ),
              const SizedBox(width: 10),
              Text('✦', style: TextStyle(fontSize: 10, color: AcroColors.gold.withOpacity(0.7))),
            ],
          ),
        ),

        for (final item in items) _positionedScroll(item, cx, cy, rx, ry),
      ],
    );
  }

  Widget _positionedScroll(
      _ScrollItem item, double cx, double cy, double rx, double ry) {
    final sinA  = sin(item.angle);
    final cosA  = cos(item.angle);
    final px    = cx + cosA * rx;
    final py    = cy + sinA * ry;
    final depth = (sinA + 1) / 2;
    final scale = 0.82 + 0.48 * depth;

    final scroll = item.index < widget.scrolls.length
        ? widget.scrolls[item.index]
        : null;

    return Positioned(
      left: px - (_cW * scale) / 2,
      top:  py - (_cH * scale) / 2,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: scroll != null ? () => widget.onScrollTap(scroll) : null,
          child: _LegendScrollChip(scroll: scroll),
        ),
      ),
    );
  }
}

// ── Parchment chip ─────────────────────────────────────────────────────────────

class _LegendScrollChip extends StatelessWidget {
  final Map<String, dynamic>? scroll;
  const _LegendScrollChip({this.scroll});

  @override
  Widget build(BuildContext context) {
    final hostName = scroll?['hostName']  as String? ?? 'Anon';
    final title    = scroll?['title']     as String? ?? 'Untitled';
    final votes    = (scroll?['votes']    as int?)   ?? 0;
    final visitors = (scroll?['visitors'] as int?)   ?? 0;
    final initials = _initials(hostName);

    return SizedBox(
      width:  _cW,
      height: _cH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Parchment
          Positioned.fill(
            child: Image.asset('assets/images/Scroll.png', fit: BoxFit.fill),
          ),

          // Avatar — ClipOval so it fills the circle exactly
          Positioned(
            left: _avatarCx - _avatarR,
            top:  _avatarCy - _avatarR,
            child: ClipOval(
              child: SizedBox(
                width:  _avatarR * 2,
                height: _avatarR * 2,
                child: AcroAvatar(
                  initials: initials,
                  seed: hostName,
                  size: _avatarR * 2,
                ),
              ),
            ),
          ),

          // [PLAYER]
          Positioned(
            left:  _playerX,
            top:   _playerY,
            right: 4,
            child: Text(
              hostName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                fontSize: 6.5,
                color: const Color(0xFF3B2500),
                letterSpacing: 0.2,
              ),
            ),
          ),

          // TOPIC NAME
          Positioned(
            left:  _topicX,
            top:   _topicY,
            right: 4,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1000),
                height: 1.2,
              ),
            ),
          ),

          // ⭐ votes
          Positioned(
            left: _starsX,
            top:  _starsY,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 8)),
                const Text('⭐', style: TextStyle(fontSize: 8)),
                const Text('⭐', style: TextStyle(fontSize: 8)),
                const SizedBox(width: 2),
                Text(
                  '+$votes',
                  style: GoogleFonts.spaceMono(
                    fontSize: 6.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A2D00),
                  ),
                ),
              ],
            ),
          ),

          // ⚡ visitors
          Positioned(
            left: _boltX,
            top:  _boltY,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 8)),
                const SizedBox(width: 1),
                Text(
                  '$visitors',
                  style: GoogleFonts.spaceMono(
                    fontSize: 6.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A2D00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
  }
}

class _ScrollItem {
  final int index;
  final double angle;
  _ScrollItem({required this.index, required this.angle});
}
