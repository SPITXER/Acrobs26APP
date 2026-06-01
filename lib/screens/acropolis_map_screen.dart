import 'package:flutter/material.dart';
import 'agora_screen.dart';
import 'stoa_screen.dart';

// ---------------------------------------------------------------------------
// Pixel size for the retro grid. Every drawn element snaps to this unit.
// ---------------------------------------------------------------------------
const double _px = 6.0;

enum AcropolisZone { agora, stoa, symposium }

class AcropolisMapScreen extends StatefulWidget {
  const AcropolisMapScreen({super.key});

  @override
  State<AcropolisMapScreen> createState() => _AcropolisMapScreenState();
}

class _AcropolisMapScreenState extends State<AcropolisMapScreen>
    with SingleTickerProviderStateMixin {
  AcropolisZone? _hovered;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
      backgroundColor: const Color(0xFF0B0F1A),
      body: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              // Zone hit-boxes (proportional)
              final agoraRect = Rect.fromLTWH(w * 0.52, h * 0.62, w * 0.40, h * 0.28);
              final stoaRect  = Rect.fromLTWH(w * 0.15, h * 0.40, w * 0.55, h * 0.24);
              final sympRect  = Rect.fromLTWH(w * 0.22, h * 0.08, w * 0.55, h * 0.26);

              return GestureDetector(
                onTapDown: (d) => _handleTap(d.localPosition, agoraRect, stoaRect, sympRect),
                child: MouseRegion(
                  onHover: (e) => _handleHover(e.localPosition, agoraRect, stoaRect, sympRect),
                  onExit: (_) => setState(() => _hovered = null),
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _AcropolisPainter(
                      pulseT: _pulse.value,
                      hovered: _hovered,
                      agoraRect: agoraRect,
                      stoaRect: stoaRect,
                      sympRect: sympRect,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleTap(Offset pos, Rect agora, Rect stoa, Rect symp) {
    if (agora.contains(pos)) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AgoraScreen()));
    } else if (stoa.contains(pos)) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StoaScreen()));
    } else if (symp.contains(pos)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🍷 Symposium — coming soon'),
        backgroundColor: Color(0xFF1A1510),
      ));
    }
  }

  void _handleHover(Offset pos, Rect agora, Rect stoa, Rect symp) {
    AcropolisZone? zone;
    if (agora.contains(pos)) zone = AcropolisZone.agora;
    else if (stoa.contains(pos)) zone = AcropolisZone.stoa;
    else if (symp.contains(pos)) zone = AcropolisZone.symposium;
    if (zone != _hovered) setState(() => _hovered = zone);
  }
}

// ---------------------------------------------------------------------------
// The actual pixel-art painter
// ---------------------------------------------------------------------------
class _AcropolisPainter extends CustomPainter {
  final double pulseT;
  final AcropolisZone? hovered;
  final Rect agoraRect, stoaRect, sympRect;

  _AcropolisPainter({
    required this.pulseT,
    required this.hovered,
    required this.agoraRect,
    required this.stoaRect,
    required this.sympRect,
  });

  // Retro palette
  static const _sky1    = Color(0xFF0B0F1A);
  static const _sky2    = Color(0xFF1A2040);
  static const _star    = Color(0xFFE8D5A3);
  static const _hill    = Color(0xFF2A3520);
  static const _hillMid = Color(0xFF3D4F2E);
  static const _stone   = Color(0xFF7A6E58);
  static const _stoneLt = Color(0xFFA89878);
  static const _stoneDk = Color(0xFF4A4030);
  static const _gold    = Color(0xFFC9A84C);
  static const _goldLt  = Color(0xFFE8D5A3);
  static const _red     = Color(0xFF8B2E2E);
  static const _maroon  = Color(0xFF6B1A1A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawSky(canvas, size);
    _drawStars(canvas, size);
    _drawHill(canvas, size);
    _drawSymposium(canvas, w, h);
    _drawStoa(canvas, w, h);
    _drawAgora(canvas, w, h);
    _drawLabels(canvas, w, h);
    _drawHoverGlow(canvas, w, h);
    _drawTitle(canvas, w, h);
  }

  void _drawSky(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [_sky1, _sky2],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawStars(Canvas canvas, Size size) {
    final p = Paint()..color = _star.withOpacity(0.4 + 0.3 * pulseT);
    // Fixed star positions as fractions
    const stars = [
      [0.08, 0.05], [0.18, 0.12], [0.35, 0.04], [0.55, 0.09],
      [0.72, 0.03], [0.88, 0.07], [0.92, 0.15], [0.05, 0.18],
      [0.62, 0.15], [0.78, 0.20], [0.42, 0.13], [0.13, 0.22],
      [0.96, 0.22], [0.28, 0.07], [0.48, 0.20],
    ];
    for (final s in stars) {
      final x = s[0] * size.width;
      final y = s[1] * size.height;
      _drawPixel(canvas, p, x, y, _px * 0.5);
    }
  }

  void _drawHill(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Main rocky plateau — tiered like the real Acropolis
    final hillPaint = Paint()..color = _hillMid;
    final stonePaint = Paint()..color = _stone;
    final stoneDkPaint = Paint()..color = _stoneDk;
    final stoneLtPaint = Paint()..color = _stoneLt;

    // Base ground strip
    _fillRect(canvas, Paint()..color = _hill, 0, h * 0.88, w, h * 0.12);

    // Rock platform tiers (pixel-stepped edges)
    // Tier 3 — widest, lowest
    _fillRect(canvas, stonePaint, w * 0.05, h * 0.70, w * 0.90, _px * 3);
    _fillRect(canvas, stoneDkPaint, w * 0.05, h * 0.70 + _px * 3, w * 0.90, _px);

    // Tier 2 — middle
    _fillRect(canvas, stoneLtPaint, w * 0.12, h * 0.46, w * 0.76, _px * 2);
    _fillRect(canvas, stonePaint, w * 0.12, h * 0.46 + _px * 2, w * 0.76, _px * 4);
    _fillRect(canvas, stoneDkPaint, w * 0.12, h * 0.46 + _px * 6, w * 0.76, _px);

    // Tier 1 — top, narrowest (for Symposium)
    _fillRect(canvas, stoneLtPaint, w * 0.22, h * 0.32, w * 0.56, _px * 2);
    _fillRect(canvas, stonePaint, w * 0.22, h * 0.32 + _px * 2, w * 0.56, _px * 3);
    _fillRect(canvas, stoneDkPaint, w * 0.22, h * 0.32 + _px * 5, w * 0.56, _px);

    // Stepped path up left side
    for (int i = 0; i < 5; i++) {
      _fillRect(canvas, stonePaint,
          w * 0.10 + i * _px * 2, h * 0.70 - i * _px * 5.5, _px * 2, _px * 5.5);
    }

    // Fill body of rock below tiers
    _fillRect(canvas, hillPaint, w * 0.05, h * 0.73, w * 0.90, h * 0.15);
  }

  void _drawSymposium(Canvas canvas, double w, double h) {
    final isHot = hovered == AcropolisZone.symposium;
    final glow = isHot ? _gold : _stoneLt;
    final roofC = isHot ? _gold : _stone;
    final wallC = isHot ? _stoneLt : _stone;

    // Pediment (triangle roof) — pixel stepped
    final steps = 8;
    final roofW = w * 0.36;
    final roofX = w * 0.32;
    final roofTop = h * 0.09;
    final roofBase = h * 0.18;
    final stepH = (roofBase - roofTop) / steps;
    final p = Paint()..color = roofC;
    for (int i = 0; i < steps; i++) {
      final indent = (i / steps) * (roofW / 2);
      _fillRect(canvas, p,
          roofX + indent, roofTop + i * stepH,
          roofW - indent * 2, stepH + _px * 0.5);
    }

    // Entablature (frieze band)
    _fillRect(canvas, Paint()..color = glow, w * 0.26, h * 0.21, w * 0.48, _px * 1.5);
    _fillRect(canvas, Paint()..color = wallC, w * 0.26, h * 0.21 + _px * 1.5, w * 0.48, _px * 3);

    // Columns (6 tall columns)
    final colCount = 6;
    final colArea = w * 0.44;
    final colStart = w * 0.28;
    final colW = _px * 2.5;
    final colTop = h * 0.24;
    final colBot = h * 0.32;
    for (int i = 0; i < colCount; i++) {
      final cx = colStart + (i / (colCount - 1)) * colArea;
      // Capital
      _fillRect(canvas, Paint()..color = glow, cx - _px * 1.8, colTop, _px * 3.6, _px);
      // Shaft
      _fillRect(canvas, Paint()..color = wallC, cx - colW / 2, colTop + _px, colW, colBot - colTop - _px * 2);
      // Base
      _fillRect(canvas, Paint()..color = glow, cx - _px * 1.8, colBot - _px, _px * 3.6, _px);
    }

    // Court icon — simple crown/wreath symbol centered
    _drawCrownIcon(canvas, w * 0.50, h * 0.15, isHot ? _gold : _goldLt.withOpacity(0.7));
  }

  void _drawStoa(Canvas canvas, double w, double h) {
    final isHot = hovered == AcropolisZone.stoa;
    final wallC = isHot ? _stoneLt : _stone;
    final roofC = isHot ? _gold : _stoneDk;
    final accentC = isHot ? _goldLt : _stoneLt;

    // Long covered walkway — horizontal building
    final roofY = h * 0.46;
    final wallY = h * 0.50;
    final wallBot = h * 0.64;
    final bldgX = w * 0.15;
    final bldgW = w * 0.55;

    // Sloped roof (flat pixel roof with overhang)
    _fillRect(canvas, Paint()..color = roofC, bldgX - _px * 2, roofY, bldgW + _px * 4, _px * 2);
    _fillRect(canvas, Paint()..color = accentC, bldgX - _px * 2, roofY + _px * 2, bldgW + _px * 4, _px);

    // Wall
    _fillRect(canvas, Paint()..color = wallC, bldgX, wallY, bldgW, wallBot - wallY);

    // 4 doorway arches (school doors)
    final doorCount = 4;
    final doorW = _px * 5;
    final doorH = _px * 10;
    final doorSpacing = bldgW / (doorCount + 0.5);
    for (int i = 0; i < doorCount; i++) {
      final dx = bldgX + doorSpacing * (i + 0.4);
      final dy = wallBot - doorH;
      // Dark doorway
      _fillRect(canvas, Paint()..color = _sky1, dx, dy, doorW, doorH);
      // Arch top (3 pixels)
      _fillRect(canvas, Paint()..color = _sky1, dx - _px, dy - _px, doorW + _px * 2, _px);
      _fillRect(canvas, Paint()..color = wallC, dx - _px * 0.5, dy - _px * 1.5, doorW + _px, _px * 0.5);
    }

    // Columns between doors
    for (int i = 0; i <= doorCount; i++) {
      final cx = bldgX + doorSpacing * (i + 0.1);
      _fillRect(canvas, Paint()..color = accentC, cx, wallY + _px, _px * 1.5, wallBot - wallY - _px);
    }

    // School icon — book symbol above center
    _drawBookIcon(canvas, bldgX + bldgW * 0.5, h * 0.42, isHot ? _gold : _goldLt.withOpacity(0.7));
  }

  void _drawAgora(Canvas canvas, double w, double h) {
    final isHot = hovered == AcropolisZone.agora;
    final awningC = isHot ? _gold : _red;
    final awningLt = isHot ? _goldLt : _maroon;
    final wallC = isHot ? _stoneLt : _stone;
    final accentC = isHot ? _goldLt : _stoneLt;

    final bldgX = w * 0.56;
    final bldgW = w * 0.34;
    final roofY = h * 0.63;
    final wallY = h * 0.67;
    final wallBot = h * 0.85;

    // Market stall awning — striped (pixel stripes)
    final stripes = 7;
    final stripeW = bldgW / stripes;
    for (int i = 0; i < stripes; i++) {
      _fillRect(canvas,
          Paint()..color = i.isEven ? awningC : awningLt,
          bldgX + i * stripeW, roofY, stripeW, _px * 4);
    }
    // Awning valance (zigzag strip — pixel triangles)
    for (int i = 0; i < stripes * 2; i++) {
      final tx = bldgX + i * (bldgW / (stripes * 2));
      _fillRect(canvas, Paint()..color = awningC, tx, roofY + _px * 4, _px * 2, _px * 2);
    }

    // Wall
    _fillRect(canvas, Paint()..color = wallC, bldgX, wallY, bldgW, wallBot - wallY);

    // Market stall openings (3 stalls with goods)
    final stallCount = 3;
    final stallW = _px * 7;
    final stallSpacing = bldgW / (stallCount + 0.3);
    for (int i = 0; i < stallCount; i++) {
      final sx = bldgX + stallSpacing * (i + 0.25);
      final sy = wallBot - _px * 8;
      // Stall opening
      _fillRect(canvas, Paint()..color = _sky1, sx, sy, stallW, _px * 8);
      // Goods on counter (little pixel boxes)
      _fillRect(canvas, Paint()..color = accentC, sx + _px, sy + _px * 5, _px * 2, _px * 2);
      _fillRect(canvas, Paint()..color = _gold, sx + _px * 4, sy + _px * 4, _px * 2, _px * 3);
    }

    // Market icon — bag/coin symbol above center
    _drawMarketIcon(canvas, bldgX + bldgW * 0.5, h * 0.59, isHot ? _gold : _goldLt.withOpacity(0.7));
  }

  // ---------------------------------------------------------------------------
  // Zone icons (drawn as chunky pixel symbols)
  // ---------------------------------------------------------------------------

  void _drawCrownIcon(Canvas canvas, double cx, double cy, Color c) {
    // Crown: 5 pixel teeth + base band
    final p = Paint()..color = c;
    final s = _px * 1.2;
    // Teeth
    for (final ox in [-2.0, -1.0, 0.0, 1.0, 2.0]) {
      final height = (ox.abs() == 1) ? s * 1.5 : (ox == 0 ? s * 2.2 : s);
      _fillRect(canvas, p, cx + ox * s * 1.8 - s * 0.4, cy - height, s * 0.8, height);
    }
    // Band
    _fillRect(canvas, p, cx - s * 4, cy, s * 8, s * 0.8);
  }

  void _drawBookIcon(Canvas canvas, double cx, double cy, Color c) {
    final p = Paint()..color = c;
    final s = _px * 1.2;
    // Left page
    _fillRect(canvas, p, cx - s * 3, cy - s * 2, s * 2.8, s * 4);
    // Spine
    _fillRect(canvas, Paint()..color = c.withOpacity(0.5), cx - s * 0.2, cy - s * 2, s * 0.4, s * 4);
    // Right page
    _fillRect(canvas, p, cx + s * 0.2, cy - s * 2, s * 2.8, s * 4);
    // Lines on pages
    final linePaint = Paint()..color = _sky1.withOpacity(0.5);
    for (int i = 1; i <= 3; i++) {
      _fillRect(canvas, linePaint, cx - s * 2.8, cy - s * 2 + i * s, s * 2.4, s * 0.3);
      _fillRect(canvas, linePaint, cx + s * 0.4, cy - s * 2 + i * s, s * 2.4, s * 0.3);
    }
  }

  void _drawMarketIcon(Canvas canvas, double cx, double cy, Color c) {
    final p = Paint()..color = c;
    final s = _px * 1.2;
    // Coin stack
    _fillRect(canvas, p, cx - s * 1.5, cy - s * 0.5, s * 3, s * 0.8);
    _fillRect(canvas, p, cx - s * 1.5, cy - s * 1.5, s * 3, s * 0.8);
    _fillRect(canvas, p, cx - s * 1.5, cy - s * 2.5, s * 3, s * 0.8);
    // Bag outline
    _fillRect(canvas, p, cx - s * 2, cy, s * 4, s * 2.5);
    _fillRect(canvas, Paint()..color = _sky1, cx - s * 1.5, cy + s * 0.5, s * 3, s * 1.5);
    // Tie knot
    _fillRect(canvas, p, cx - s * 0.5, cy - s * 3, s, s);
  }

  // ---------------------------------------------------------------------------
  // Hover glow outlines
  // ---------------------------------------------------------------------------

  void _drawHoverGlow(Canvas canvas, double w, double h) {
    if (hovered == null) return;
    final rect = switch (hovered!) {
      AcropolisZone.symposium => sympRect,
      AcropolisZone.stoa      => stoaRect,
      AcropolisZone.agora     => agoraRect,
    };
    final alpha = (0.3 + 0.25 * pulseT).clamp(0.0, 1.0);
    final glowPaint = Paint()
      ..color = _gold.withOpacity(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _px;
    canvas.drawRect(rect.inflate(_px * 1.5), glowPaint);
  }

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  void _drawLabels(Canvas canvas, double w, double h) {
    _drawZoneLabel(canvas, '🏛  SYMPOSIUM', w * 0.50, h * 0.365,
        hovered == AcropolisZone.symposium);
    _drawZoneLabel(canvas, '🏫  STOA', w * 0.425, h * 0.665,
        hovered == AcropolisZone.stoa);
    _drawZoneLabel(canvas, '🏪  AGORA', w * 0.735, h * 0.875,
        hovered == AcropolisZone.agora);
  }

  void _drawZoneLabel(Canvas canvas, String text, double cx, double cy, bool active) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: _px * 2.2,
          fontWeight: FontWeight.bold,
          color: active ? _gold : _stoneLt,
          letterSpacing: 1.5,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawTitle(Canvas canvas, double w, double h) {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'A C R O',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFFC9A84C),
          letterSpacing: 10,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.01));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _fillRect(Canvas canvas, Paint paint, double x, double y, double w, double h) {
    if (w <= 0 || h <= 0) return;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  void _drawPixel(Canvas canvas, Paint paint, double x, double y, double size) {
    canvas.drawRect(Rect.fromLTWH(x - size / 2, y - size / 2, size, size), paint);
  }

  @override
  bool shouldRepaint(_AcropolisPainter old) =>
      old.pulseT != pulseT || old.hovered != hovered;
}
