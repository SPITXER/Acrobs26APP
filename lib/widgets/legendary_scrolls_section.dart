import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/acro_theme.dart';
import 'avatar.dart';

// Height of the entire legendary section (island + scrolls + title)
const double kLegendSectionHeight = 520.0;

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
          builder: (context, constraints) =>
              _buildStack(constraints.maxWidth, constraints.maxHeight),
        ),
      ),
    );
  }

  Widget _buildStack(double w, double h) {
    // Orbit center sits on the platform brick surface.
    // Island image is shifted down ~20 % via alignment → surface ≈ 57 % of h.
    final cx = w * 0.50;
    final cy = h * 0.60;

    // Ellipse: cap rx so it doesn't explode on wide screens
    final rx = min(w * 0.25, 110.0);
    final ry = h * 0.078;

    final count = widget.scrolls.length.clamp(1, 3);

    final items = List.generate(count, (i) {
      final a = _angle + (i * 2 * pi / 3);
      return _ScrollItem(index: i, angle: a);
    })..sort((a, b) => sin(a.angle).compareTo(sin(b.angle)));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Legendisland platform (shifted down) ──────────────────────
        Positioned.fill(
          child: Image.asset(
            'assets/images/Legendisland.png',
            fit: BoxFit.contain,
            // positive y moves the image toward the bottom
            alignment: const Alignment(0, 0.55),
          ),
        ),

        // ── "LEGENDARY SCROLLS" title overlay ─────────────────────────
        Positioned(
          top: 18,
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

        // ── Rotating scroll chips ─────────────────────────────────────
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

    // Depth: back=0, front=1
    final depth   = (sinA + 1) / 2;
    final scale   = 0.68 + 0.32 * depth;
    final opacity = 0.55 + 0.45 * depth;

    const chipW = 178.0;
    const chipH = 168.0;

    final scroll = item.index < widget.scrolls.length
        ? widget.scrolls[item.index]
        : null;

    return Positioned(
      left: px - (chipW * scale) / 2,
      top:  py - (chipH * scale) / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: scroll != null ? () => widget.onScrollTap(scroll) : null,
            child: _LegendScrollChip(scroll: scroll),
          ),
        ),
      ),
    );
  }
}

// ── Scroll chip — uses Scroll.png as template background ─────────────────────
//
// Scroll.png is 600×600. Content layout mapped to a 178×168 chip:
//   x-scale = 178/600 = 0.2967
//   y-scale = 168/600 = 0.2800
//
//   Avatar circle centre ≈ (175, 258) → chip (52, 72), r≈22 → left=30,top=50,size=44
//   [PLAYER] text         ≈ (268, 178) → chip (80, 50)
//   TOPIC NAME            ≈ (268, 228) → chip (80, 64)
//   Stars row             ≈ (76,  350) → chip (23, 98)
//   Lightning bolt        ≈ (298, 350) → chip (88, 98)

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
      width:  178,
      height: 168,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Parchment background
          Positioned.fill(
            child: Image.asset(
              'assets/images/Scroll.png',
              fit: BoxFit.fill,
            ),
          ),

          // Avatar — sits inside the dashed circle on the left
          Positioned(
            left: 30,
            top:  50,
            child: AcroAvatar(initials: initials, seed: hostName, size: 44),
          ),

          // Host name ([PLAYER])
          Positioned(
            left:  80,
            top:   46,
            right: 10,
            child: Text(
              hostName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                fontSize: 8,
                color: const Color(0xFF3B2500),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Topic title (TOPIC NAME)
          Positioned(
            left:  80,
            top:   58,
            right: 8,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1000),
                height: 1.25,
              ),
            ),
          ),

          // Stars + upvote count
          Positioned(
            left: 20,
            top:  108,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 10)),
                const Text('⭐', style: TextStyle(fontSize: 10)),
                const Text('⭐', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Text(
                  '+$votes',
                  style: GoogleFonts.spaceMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A2D00),
                  ),
                ),
              ],
            ),
          ),

          // Lightning bolt + visitors
          Positioned(
            left: 106,
            top:  108,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 2),
                Text(
                  '$visitors',
                  style: GoogleFonts.spaceMono(
                    fontSize: 8,
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
