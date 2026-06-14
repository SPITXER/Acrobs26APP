import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/acro_theme.dart';
import 'avatar.dart';

// Scroll.png is 600×600 px. All overlay positions are derived from
// the original image coordinates and then scaled to the chip size.
//
// Source measurements (in the 600×600 original):
//   Dashed circle centre ≈ (174, 254)   radius ≈ 82px
//   [PLAYER] text start  ≈ (270, 178)
//   TOPIC NAME start     ≈ (270, 228)
//   Stars row start      ≈ (82,  352)
//   Lightning start      ≈ (302, 352)
//
// Chip size: 172 × 162 px
//   x-scale = 172/600 = 0.2867
//   y-scale = 162/600 = 0.2700

const double _cW = 172.0; // chip width
const double _cH = 162.0; // chip height
const double _sx = _cW / 600; // 0.2867
const double _sy = _cH / 600; // 0.2700

// Derived chip positions
const double _avatarCx = 174 * _sx; // ≈ 49.9
const double _avatarCy = 254 * _sy; // ≈ 68.6
const double _avatarR  = 78  * _sx; // ≈ 22.4  → diameter ≈ 45

const double _playerX  = 270 * _sx; // ≈ 77.4
const double _playerY  = 172 * _sy; // ≈ 46.4

const double _topicX   = 270 * _sx; // ≈ 77.4
const double _topicY   = 220 * _sy; // ≈ 59.4

const double _starsX   = 80  * _sx; // ≈ 22.9
const double _starsY   = 350 * _sy; // ≈ 94.5

const double _boltX    = 298 * _sx; // ≈ 85.4
const double _boltY    = 350 * _sy; // ≈ 94.5

// Island section height (15 % smaller than the previous 520 px)
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
  double _angle = -pi / 6; // start with one scroll facing the viewer
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
    // Orbit centre — sits on the brick platform surface.
    // Image is shifted down with alignment(0, 0.80) so the platform is
    // lower in the container; calibrated to ≈ 67 % of container height.
    final cx = w * 0.50;
    final cy = h * 0.67;

    // Ellipse radii — scrolls sit properly across the platform width.
    // rx capped at 80 px so chips stay inside the island on narrow screens.
    final rx = min(w * 0.215, 80.0);
    final ry = h * 0.078;

    final count = widget.scrolls.length.clamp(1, 3);

    final items = List.generate(count, (i) {
      final a = _angle + (i * 2 * pi / 3);
      return _ScrollItem(index: i, angle: a);
    })..sort((a, b) => sin(a.angle).compareTo(sin(b.angle)));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Legendisland: pushed further down ─────────────────────────
        Positioned.fill(
          child: Image.asset(
            'assets/images/Legendisland.png',
            fit: BoxFit.contain,
            alignment: const Alignment(0, 0.80),
          ),
        ),

        // ── "LEGENDARY SCROLLS" title overlay ─────────────────────────
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

        // ── Rotating scroll chips ──────────────────────────────────────
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

    // depth: 0 = back, 1 = front (closest to viewer)
    final depth = (sinA + 1) / 2;

    // Scale: back ≈ 0.82, sides ≈ 0.96, front ≈ 1.30
    // Front scroll is ~35 % larger than side scrolls — visibly "in focus".
    final scale = 0.82 + 0.48 * depth;

    // Full opacity for all scrolls
    const opacity = 1.0;

    final scroll = item.index < widget.scrolls.length
        ? widget.scrolls[item.index]
        : null;

    return Positioned(
      left: px - (_cW * scale) / 2,
      top:  py - (_cH * scale) / 2,
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

// ── Individual parchment chip ──────────────────────────────────────────────────

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
          // Parchment background
          Positioned.fill(
            child: Image.asset('assets/images/Scroll.png', fit: BoxFit.fill),
          ),

          // ── Avatar — clipped to circle, fitted inside the dashed ring ──
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

          // ── Host name ([PLAYER] slot) ──────────────────────────────────
          Positioned(
            left:  _playerX,
            top:   _playerY,
            right: 8,
            child: Text(
              hostName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                fontSize: 7.5,
                color: const Color(0xFF3B2500),
                letterSpacing: 0.3,
              ),
            ),
          ),

          // ── Title (TOPIC NAME slot) ────────────────────────────────────
          Positioned(
            left:  _topicX,
            top:   _topicY,
            right: 8,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceMono(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1000),
                height: 1.2,
              ),
            ),
          ),

          // ── Stars + upvote count ───────────────────────────────────────
          Positioned(
            left: _starsX,
            top:  _starsY,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 9)),
                const Text('⭐', style: TextStyle(fontSize: 9)),
                const Text('⭐', style: TextStyle(fontSize: 9)),
                const SizedBox(width: 2),
                Text(
                  '+$votes',
                  style: GoogleFonts.spaceMono(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4A2D00),
                  ),
                ),
              ],
            ),
          ),

          // ── Lightning + visitor count ──────────────────────────────────
          Positioned(
            left: _boltX,
            top:  _boltY,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 1),
                Text(
                  '$visitors',
                  style: GoogleFonts.spaceMono(
                    fontSize: 7.5,
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
