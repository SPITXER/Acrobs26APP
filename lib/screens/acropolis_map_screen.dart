import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'agora_screen.dart';
import 'stoa_screen.dart';

const double _px = 5.0;

enum AcropolisZone { agora, stoa, acropolis }

class AcropolisMapScreen extends StatefulWidget {
  const AcropolisMapScreen({super.key});

  @override
  State<AcropolisMapScreen> createState() => _AcropolisMapScreenState();
}

class _AcropolisMapScreenState extends State<AcropolisMapScreen>
    with SingleTickerProviderStateMixin {
  AcropolisZone? _hovered;
  bool _menuOpen = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C0A),
      body: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              final acropolisRect = Rect.fromLTWH(w * 0.20, h * 0.04, w * 0.60, h * 0.23);
              final stoaRect      = Rect.fromLTWH(w * 0.05, h * 0.30, w * 0.90, h * 0.35);
              final agoraRect     = Rect.fromLTWH(w * 0.14, h * 0.69, w * 0.72, h * 0.23);

              return Stack(
                children: [
                  GestureDetector(
                    onTapDown: (d) {
                      if (_menuOpen) {
                        setState(() => _menuOpen = false);
                        return;
                      }
                      _handleTap(d.localPosition, acropolisRect, stoaRect, agoraRect);
                    },
                    child: MouseRegion(
                      onHover: (e) => _handleHover(
                          e.localPosition, acropolisRect, stoaRect, agoraRect),
                      onExit: (_) => setState(() => _hovered = null),
                      child: CustomPaint(
                        size: Size(w, h),
                        painter: _MapPainter(
                          pulseT: _pulse.value,
                          hovered: _hovered,
                          acropolisRect: acropolisRect,
                          stoaRect: stoaRect,
                          agoraRect: agoraRect,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 16,
                    child: _buildDropdown(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => setState(() => _menuOpen = !_menuOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1614),
              border: Border.all(color: const Color(0xFFB87333), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MENU',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFFB87333),
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _menuOpen ? '▲' : '▼',
                  style: const TextStyle(color: Color(0xFFB87333), fontSize: 9),
                ),
              ],
            ),
          ),
        ),
        if (_menuOpen) ...[
          const SizedBox(height: 2),
          Container(
            width: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1614),
              border: Border.all(color: const Color(0xFFB87333), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _menuItem('◈  PROFILE'),
                _menuDivider(),
                _menuItem('📜  RULES'),
                _menuDivider(),
                _menuItem('⚙  SETTINGS'),
                _menuDivider(),
                _menuItem('⬡  EXIT'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _menuItem(String label) {
    return InkWell(
      onTap: () => setState(() => _menuOpen = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: Color(0xFFD0D1D5),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _menuDivider() =>
      Container(height: 1, color: const Color(0xFFB87333).withOpacity(0.25));

  void _handleTap(Offset pos, Rect acropolis, Rect stoa, Rect agora) {
    if (acropolis.contains(pos)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🏛  Acropolis Court — Symposium coming soon'),
        backgroundColor: Color(0xFF1A1614),
        duration: Duration(seconds: 2),
      ));
    } else if (stoa.contains(pos)) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const StoaScreen()));
    } else if (agora.contains(pos)) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AgoraScreen()));
    }
  }

  void _handleHover(Offset pos, Rect acropolis, Rect stoa, Rect agora) {
    AcropolisZone? zone;
    if (acropolis.contains(pos)) {
      zone = AcropolisZone.acropolis;
    } else if (stoa.contains(pos)) {
      zone = AcropolisZone.stoa;
    } else if (agora.contains(pos)) {
      zone = AcropolisZone.agora;
    }
    if (zone != _hovered) setState(() => _hovered = zone);
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _MapPainter extends CustomPainter {
  final double pulseT;
  final AcropolisZone? hovered;
  final Rect acropolisRect, stoaRect, agoraRect;

  const _MapPainter({
    required this.pulseT,
    required this.hovered,
    required this.acropolisRect,
    required this.stoaRect,
    required this.agoraRect,
  });

  // Palette
  static const _bg       = Color(0xFF0E0C0A);
  static const _bgMid    = Color(0xFF1C1815);
  static const _bgLight  = Color(0xFF2A2420);
  static const _copper   = Color(0xFFB87333);
  static const _copperLt = Color(0xFFD4956A);
  static const _copperDk = Color(0xFF7A4520);
  static const _silver   = Color(0xFFA8A9AD);
  static const _silverLt = Color(0xFFD0D1D5);
  static const _silverDk = Color(0xFF6B6C70);
  static const _gold     = Color(0xFFC9A84C);
  static const _goldLt   = Color(0xFFE8D5A3);
  static const _orange   = Color(0xFFFF8C42);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawDottedPath(canvas, w, h);
    _drawAcropolis(canvas, w, h);
    _drawStoa(canvas, w, h);
    _drawAgora(canvas, w, h);
    _drawHoverGlow(canvas, w, h);
    _drawTitle(canvas, w, h);
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _bg,
    );
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [_bg.withOpacity(0), Colors.black.withOpacity(0.65)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _bgLight.withOpacity(0.25)
      ..strokeWidth = 0.5;
    final gs = _px * 8;
    for (double x = 0; x < size.width; x += gs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += gs) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  // Dotted copper trail: Agora → Stoa → Acropolis
  void _drawDottedPath(Canvas canvas, double w, double h) {
    final dot = Paint()..color = _copper.withOpacity(0.65);
    final waypoints = [
      Offset(w * 0.50, h * 0.91),
      Offset(w * 0.50, h * 0.76),
      Offset(w * 0.42, h * 0.69),
      Offset(w * 0.36, h * 0.62),
      Offset(w * 0.50, h * 0.56),
      Offset(w * 0.62, h * 0.49),
      Offset(w * 0.56, h * 0.42),
      Offset(w * 0.50, h * 0.35),
      Offset(w * 0.50, h * 0.28),
      Offset(w * 0.50, h * 0.18),
    ];
    for (int i = 0; i < waypoints.length - 1; i++) {
      final p0 = waypoints[i];
      final p1 = waypoints[i + 1];
      final steps = ((p1 - p0).distance / (_px * 3.5)).floor();
      for (int j = 0; j <= steps; j++) {
        final t = steps == 0 ? 0.0 : j / steps;
        final x = p0.dx + (p1.dx - p0.dx) * t;
        final y = p0.dy + (p1.dy - p0.dy) * t;
        _fillRect(canvas, dot, x - _px * 0.7, y - _px * 0.7, _px * 1.4, _px * 1.4);
      }
    }
  }

  // ── Acropolis ─────────────────────────────────────────────────────────────

  void _drawAcropolis(Canvas canvas, double w, double h) {
    final hot = hovered == AcropolisZone.acropolis;
    final wallC   = hot ? _goldLt : _gold;
    final accentC = hot ? _gold   : _silver;
    final fillC   = hot ? _gold.withOpacity(0.12) : _bgMid;

    final r = acropolisRect;

    _fillRect(canvas, Paint()..color = fillC, r.left, r.top, r.width, r.height);
    _pixelBorder(canvas, r.left, r.top, r.width, r.height, wallC, _px);

    // Inner court
    final cx = r.left + r.width * 0.15;
    final cy = r.top  + r.height * 0.22;
    final cw = r.width  * 0.70;
    final ch = r.height * 0.55;
    _fillRect(canvas, Paint()..color = _bgLight, cx, cy, cw, ch);
    _pixelBorder(canvas, cx, cy, cw, ch, accentC, _px * 0.8);

    // Pixel columns across top of court
    final cols = 9;
    final colSpacing = cw / (cols + 1);
    for (int i = 1; i <= cols; i++) {
      final colX = cx + colSpacing * i;
      _fillRect(canvas, Paint()..color = accentC, colX - _px * 0.7, cy, _px * 1.4, _px * 2);
      _fillRect(canvas, Paint()..color = accentC.withOpacity(0.45),
          colX - _px * 0.5, cy + _px * 2, _px, ch - _px * 2);
    }

    // Pulsing gold/orange star
    _drawPixelStar(canvas,
      cx: r.left + r.width  * 0.50,
      cy: r.top  + r.height * 0.52,
      size: _px * 3.4,
      color: hot
        ? Color.lerp(_gold, _orange, pulseT)!
        : Color.lerp(_gold, _goldLt, pulseT)!,
    );

    _drawLabel(canvas, 'ACROPOLIS  COURT',
        r.left + r.width * 0.5, r.top + r.height * 0.87,
        hot ? _goldLt : _gold, _px * 2.1);
  }

  // ── Stoa ──────────────────────────────────────────────────────────────────

  void _drawStoa(Canvas canvas, double w, double h) {
    final hot     = hovered == AcropolisZone.stoa;
    final wallC   = hot ? _silverLt : _silver;
    final accentC = hot ? _silver   : _silverDk;
    final fillC   = hot ? _silverDk.withOpacity(0.12) : _bgMid;

    final r = stoaRect;
    _fillRect(canvas, Paint()..color = fillC, r.left, r.top, r.width, r.height);
    _pixelBorder(canvas, r.left, r.top, r.width, r.height, wallC, _px);

    // Central walkway corridor
    final walkY = r.top  + r.height * 0.42;
    final walkH = r.height * 0.16;
    _fillRect(canvas, Paint()..color = _bgLight, r.left, walkY, r.width, walkH);
    _fillRect(canvas, Paint()..color = wallC.withOpacity(0.25),
        r.left, walkY, r.width, _px * 0.5);
    _fillRect(canvas, Paint()..color = wallC.withOpacity(0.25),
        r.left, walkY + walkH - _px * 0.5, r.width, _px * 0.5);

    // Side rooms — top row
    final rw = r.width  * 0.11;
    final rh = r.height * 0.30;
    _drawRoom(canvas, r.left + _px * 2,                        r.top + r.height * 0.07, rw, rh, wallC, accentC);
    _drawRoom(canvas, r.left + r.width - rw - _px * 2,        r.top + r.height * 0.07, rw, rh, wallC, accentC);

    // Side rooms — bottom row
    _drawRoom(canvas, r.left + _px * 2,                        r.top + r.height * 0.63, rw, rh, wallC, accentC);
    _drawRoom(canvas, r.left + r.width - rw - _px * 2,        r.top + r.height * 0.63, rw, rh, wallC, accentC);

    // Open debate tables — upper zone
    _drawDebateTable(canvas, r.left + r.width * 0.28, r.top + r.height * 0.22, hot, wallC, accentC);
    _drawDebateTable(canvas, r.left + r.width * 0.50, r.top + r.height * 0.22, hot, wallC, accentC);
    _drawDebateTable(canvas, r.left + r.width * 0.72, r.top + r.height * 0.22, hot, wallC, accentC);

    // Open debate tables — lower zone
    _drawDebateTable(canvas, r.left + r.width * 0.28, r.top + r.height * 0.73, hot, wallC, accentC);
    _drawDebateTable(canvas, r.left + r.width * 0.50, r.top + r.height * 0.73, hot, wallC, accentC);
    _drawDebateTable(canvas, r.left + r.width * 0.72, r.top + r.height * 0.73, hot, wallC, accentC);

    // Pulsing silver/orange star on walkway
    _drawPixelStar(canvas,
      cx: r.left + r.width  * 0.50,
      cy: walkY  + walkH    * 0.50,
      size: _px * 3.0,
      color: hot
        ? Color.lerp(_silver, _orange, pulseT)!
        : Color.lerp(_silverDk, _silverLt, pulseT)!,
    );

    _drawLabel(canvas, 'STOA',
        r.left + r.width * 0.5, r.top + r.height * 0.89,
        hot ? _silverLt : _silver, _px * 2.1);
  }

  void _drawRoom(Canvas canvas, double x, double y, double rw, double rh,
      Color wall, Color accent) {
    _fillRect(canvas, Paint()..color = _bgLight, x, y, rw, rh);
    _pixelBorder(canvas, x, y, rw, rh, wall, _px * 0.7);
    // Mini table
    _fillRect(canvas, Paint()..color = accent.withOpacity(0.5),
        x + rw * 0.25, y + rh * 0.30, rw * 0.50, rh * 0.28);
    // Two seats
    _fillRect(canvas, Paint()..color = wall.withOpacity(0.45),
        x + rw * 0.20, y + rh * 0.14, _px * 1.6, _px * 1.6);
    _fillRect(canvas, Paint()..color = wall.withOpacity(0.45),
        x + rw * 0.55, y + rh * 0.14, _px * 1.6, _px * 1.6);
  }

  void _drawDebateTable(Canvas canvas, double cx, double cy, bool hot,
      Color wall, Color accent) {
    final s = _px * 2.2;
    // Pixel-art circle (cross + filled center)
    _fillRect(canvas, Paint()..color = accent, cx - s, cy - s * 0.35, s * 2, s * 0.7);
    _fillRect(canvas, Paint()..color = accent, cx - s * 0.35, cy - s, s * 0.7, s * 2);
    _fillRect(canvas, Paint()..color = accent, cx - s * 0.65, cy - s * 0.65, s * 1.3, s * 1.3);
    // 4 seats
    for (final angle in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
      final dx = cx + math.cos(angle) * s * 1.7;
      final dy = cy + math.sin(angle) * s * 1.7;
      _fillRect(canvas, Paint()..color = wall.withOpacity(hot ? 0.8 : 0.5),
          dx - _px * 0.7, dy - _px * 0.7, _px * 1.4, _px * 1.4);
    }
  }

  // ── Agora ─────────────────────────────────────────────────────────────────

  void _drawAgora(Canvas canvas, double w, double h) {
    final hot     = hovered == AcropolisZone.agora;
    final wallC   = hot ? _copperLt : _copper;
    final accentC = hot ? _copperLt : _copperDk;
    final fillC   = hot ? _copperDk.withOpacity(0.12) : _bgMid;

    final r = agoraRect;
    _fillRect(canvas, Paint()..color = fillC, r.left, r.top, r.width, r.height);
    _pixelBorder(canvas, r.left, r.top, r.width, r.height, wallC, _px);

    // 5 market stalls
    final stallW  = r.width  * 0.09;
    final stallH  = r.height * 0.48;
    final spacing = r.width  / 6.0;
    for (int i = 0; i < 5; i++) {
      final sx = r.left + spacing * (i + 0.5) - stallW / 2;
      final sy = r.top  + r.height * 0.12;
      _fillRect(canvas, Paint()..color = _bgLight, sx, sy, stallW, stallH);
      _pixelBorder(canvas, sx, sy, stallW, stallH, accentC, _px * 0.5);
      // Awning
      _fillRect(canvas, Paint()..color = wallC, sx, sy - _px * 1.8, stallW, _px * 1.8);
      // Goods pixel
      _fillRect(canvas, Paint()..color = _gold,
          sx + stallW * 0.3, sy + stallH * 0.5, _px * 1.5, _px * 1.5);
    }

    // Entrance arch (bottom center)
    final ax = r.left + r.width * 0.5;
    final ay = r.top  + r.height * 0.82;
    _fillRect(canvas, Paint()..color = wallC, ax - _px * 6, ay, _px * 12, _px * 1.5);
    _fillRect(canvas, Paint()..color = wallC, ax - _px * 6, ay - _px * 4.5, _px * 2.5, _px * 4.5);
    _fillRect(canvas, Paint()..color = wallC, ax + _px * 3.5, ay - _px * 4.5, _px * 2.5, _px * 4.5);

    // Pulsing copper/orange star
    _drawPixelStar(canvas,
      cx: r.left + r.width  * 0.50,
      cy: r.top  + r.height * 0.45,
      size: _px * 3.0,
      color: hot
        ? Color.lerp(_copper, _orange, pulseT)!
        : Color.lerp(_copperDk, _copperLt, pulseT)!,
    );

    _drawLabel(canvas, 'AGORA  ·  ENTRANCE',
        r.left + r.width * 0.5, r.top + r.height * 0.87,
        hot ? _copperLt : _copper, _px * 2.1);
  }

  // ── Pixel star (Claude-style) ──────────────────────────────────────────────

  void _drawPixelStar(Canvas canvas,
      {required double cx, required double cy,
      required double size, required Color color}) {
    final p = Paint()..color = color;
    final s = size;
    // Top spike
    _fillRect(canvas, p, cx - s * 0.16, cy - s,       s * 0.32, s * 0.55);
    // Left spike
    _fillRect(canvas, p, cx - s,        cy - s * 0.16, s * 0.55, s * 0.32);
    // Right spike
    _fillRect(canvas, p, cx + s * 0.45, cy - s * 0.16, s * 0.55, s * 0.32);
    // Bottom spike
    _fillRect(canvas, p, cx - s * 0.16, cy + s * 0.45, s * 0.32, s * 0.55);
    // Diagonal spikes (upper-left, upper-right, lower-left, lower-right)
    _fillRect(canvas, p, cx - s * 0.72, cy - s * 0.72, s * 0.38, s * 0.38);
    _fillRect(canvas, p, cx + s * 0.34, cy - s * 0.72, s * 0.38, s * 0.38);
    _fillRect(canvas, p, cx - s * 0.72, cy + s * 0.34, s * 0.38, s * 0.38);
    _fillRect(canvas, p, cx + s * 0.34, cy + s * 0.34, s * 0.38, s * 0.38);
    // Center body
    _fillRect(canvas, p, cx - s * 0.45, cy - s * 0.45, s * 0.90, s * 0.90);
    // Glow ring pulse
    final glowAlpha = (0.12 + 0.28 * pulseT).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: s * 3.2, height: s * 3.2),
      Paint()
        ..color = color.withOpacity(glowAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _px * 0.9,
    );
  }

  // ── Hover glow ────────────────────────────────────────────────────────────

  void _drawHoverGlow(Canvas canvas, double w, double h) {
    if (hovered == null) return;
    final rect = switch (hovered!) {
      AcropolisZone.acropolis => acropolisRect,
      AcropolisZone.stoa      => stoaRect,
      AcropolisZone.agora     => agoraRect,
    };
    final c = switch (hovered!) {
      AcropolisZone.acropolis => _gold,
      AcropolisZone.stoa      => _silver,
      AcropolisZone.agora     => _copper,
    };
    final alpha = (0.18 + 0.22 * pulseT).clamp(0.0, 1.0);
    canvas.drawRect(
      rect.inflate(_px * 1.2),
      Paint()
        ..color = c.withOpacity(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _px * 1.5,
    );
  }

  // ── Title ─────────────────────────────────────────────────────────────────

  void _drawTitle(Canvas canvas, double w, double h) {
    _drawLabel(canvas, 'A · C · R · O', w * 0.5, h * 0.966,
        _gold, _px * 2.2, letterSpacing: 8.0);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _drawLabel(Canvas canvas, String text, double cx, double cy, Color color,
      double fontSize, {double letterSpacing = 2.0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: letterSpacing,
          shadows: [Shadow(color: Colors.black.withOpacity(0.9), blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _pixelBorder(Canvas canvas, double x, double y, double w, double h,
      Color color, double thickness) {
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );
  }

  void _fillRect(Canvas canvas, Paint paint, double x, double y, double w, double h) {
    if (w <= 0 || h <= 0) return;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.pulseT != pulseT || old.hovered != hovered;
}
