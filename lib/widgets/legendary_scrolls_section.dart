import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/acro_theme.dart';

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
  double _angle = -pi / 6; // start with front scroll facing viewer
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
        height: 290,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _buildStack(constraints.maxWidth, constraints.maxHeight),
        ),
      ),
    );
  }

  Widget _buildStack(double w, double h) {
    // Platform surface centre — the brick floor sits roughly here
    final cx = w * 0.50;
    final cy = h * 0.54;

    // Ellipse radii — tight to fit inside the columns
    final rx = w * 0.20;
    final ry = h * 0.095;

    final count = widget.scrolls.length.clamp(1, 3);

    // Compute positions and sort back→front (ascending sinA)
    final items = List.generate(count, (i) {
      final a = _angle + (i * 2 * pi / 3);
      return _ScrollItem(index: i, angle: a);
    })..sort((a, b) => sin(a.angle).compareTo(sin(b.angle)));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Platform image — fills the section
        Positioned.fill(
          child: Image.asset(
            'assets/images/Legendisland.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),

        // Rotating scrolls
        for (final item in items) _positionedScroll(item, cx, cy, rx, ry),
      ],
    );
  }

  Widget _positionedScroll(
      _ScrollItem item, double cx, double cy, double rx, double ry) {
    final sinA = sin(item.angle);
    final cosA = cos(item.angle);

    final px = cx + cosA * rx;
    final py = cy + sinA * ry;

    // Depth: back=0, front=1
    final depth = (sinA + 1) / 2;
    final scale = 0.70 + 0.30 * depth;
    final opacity = 0.60 + 0.40 * depth;

    const cardW = 126.0;
    const cardH = 82.0;

    final scroll = item.index < widget.scrolls.length
        ? widget.scrolls[item.index]
        : null;

    return Positioned(
      left: px - (cardW * scale) / 2,
      top: py - (cardH * scale) / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: scroll != null ? () => widget.onScrollTap(scroll) : null,
            child: _ScrollChip(scroll: scroll),
          ),
        ),
      ),
    );
  }
}

// ── Individual scroll card that sits on the platform ─────────────────────────

class _ScrollChip extends StatelessWidget {
  final Map<String, dynamic>? scroll;
  const _ScrollChip({this.scroll});

  @override
  Widget build(BuildContext context) {
    final title    = scroll?['title']    as String? ?? 'Untitled Scroll';
    final category = scroll?['category'] as String? ?? '';

    return Container(
      width: 126,
      height: 82,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1608), Color(0xFF0E0B04)],
        ),
        border: Border.all(color: AcroColors.gold.withOpacity(0.65), width: 0.9),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: AcroColors.gold.withOpacity(0.25),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category / Legendary badge row
          Row(children: [
            if (category.isNotEmpty) ...[
              Flexible(
                child: Text(
                  category.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceMono(
                    fontSize: 7,
                    color: AcroColors.gold.withOpacity(0.75),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              '⭐',
              style: TextStyle(fontSize: 8, color: AcroColors.gold.withOpacity(0.9)),
            ),
          ]),
          const SizedBox(height: 5),

          // Title
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cormorant(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.92),
                height: 1.2,
              ),
            ),
          ),

          // Footer
          const SizedBox(height: 4),
          Row(children: [
            const Text('📜', style: TextStyle(fontSize: 8)),
            const SizedBox(width: 4),
            Text(
              'LEGENDARY',
              style: GoogleFonts.spaceMono(
                fontSize: 6.5,
                color: AcroColors.gold.withOpacity(0.50),
                letterSpacing: 1,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ScrollItem {
  final int index;
  final double angle;
  _ScrollItem({required this.index, required this.angle});
}
