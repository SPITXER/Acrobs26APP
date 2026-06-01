import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'agora_screen.dart';
import 'stoa_screen.dart';
import 'symposium_screen.dart';

const double _px = 2.0;

enum AcropolisZone { agora, stoa, acropolis }

const _copper   = Color(0xFFB87333);
const _copperLt = Color(0xFFD4956A);
const _copperDk = Color(0xFF7A4520);
const _orange   = Color(0xFFFF8C42);
const _wallFill = Color(0xFF0F0500);
const _treeDk   = Color(0xFF3D1800);
const _treeLt   = Color(0xFF7A4520);

class AcropolisMapScreen extends StatefulWidget {
  const AcropolisMapScreen({super.key});
  @override
  State<AcropolisMapScreen> createState() => _AcropolisMapScreenState();
}

class _AcropolisMapScreenState extends State<AcropolisMapScreen>
    with TickerProviderStateMixin {
  AcropolisZone? _hovered;
  bool _menuOpen = false;
  late AnimationController _pulse;
  late AnimationController _flicker;

  @override
  void initState() {
    super.initState();
    _pulse   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _flicker = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); _flicker.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _flicker]),
        builder: (context, _) {
          return LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final agoraRect     = Rect.fromLTWH(w * 0.40, h * 0.84, w * 0.20, h * 0.09);
            final stoaRect      = Rect.fromLTWH(w * 0.26, h * 0.50, w * 0.48, h * 0.19);
            final acropolisRect = Rect.fromLTWH(w * 0.31, h * 0.12, w * 0.38, h * 0.26);
            return Stack(children: [
              GestureDetector(
                onTapDown: (d) {
                  if (_menuOpen) { setState(() => _menuOpen = false); return; }
                  _handleTap(d.localPosition, agoraRect, stoaRect, acropolisRect);
                },
                child: MouseRegion(
                  onHover: (e) => _handleHover(e.localPosition, agoraRect, stoaRect, acropolisRect),
                  onExit: (_) => setState(() => _hovered = null),
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _CityMapPainter(
                      pulseT: _pulse.value, flickerT: _flicker.value,
                      hovered: _hovered,
                      agoraRect: agoraRect, stoaRect: stoaRect, acropolisRect: acropolisRect,
                    ),
                  ),
                ),
              ),
              Positioned(top: 14, right: 16, child: _buildDropdown()),
            ]);
          });
        },
      ),
    );
  }

  Widget _buildDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      GestureDetector(
        onTap: () => setState(() => _menuOpen = !_menuOpen),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: Colors.black, border: Border.all(color: _copper, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('MENU', style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                color: _copper, letterSpacing: 2.5, fontWeight: FontWeight.bold)),
            const SizedBox(width: 7),
            Text(_menuOpen ? '▲' : '▼', style: const TextStyle(color: _copper, fontSize: 9)),
          ]),
        ),
      ),
      if (_menuOpen) ...[
        const SizedBox(height: 2),
        Container(
          width: 140,
          decoration: BoxDecoration(color: Colors.black, border: Border.all(color: _copper, width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _mi('◈  PROFILE'), _md(), _mi('\u{1F4DC}  RULES'),
            _md(), _mi('⚙  SETTINGS'), _md(), _mi('⬡  EXIT'),
          ]),
        ),
      ],
    ]);
  }

  Widget _mi(String label) => InkWell(
    onTap: () => setState(() => _menuOpen = false),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: const TextStyle(fontFamily: 'monospace',
            fontSize: 11, color: _copperLt, letterSpacing: 1.5))),
  );
  Widget _md() => Container(height: 1, color: const Color(0x40B87333));

  void _handleTap(Offset pos, Rect agora, Rect stoa, Rect acropolis) {
    if (agora.contains(pos)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgoraScreen()));
    } else if (stoa.contains(pos)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoaScreen()));
    } else if (acropolis.contains(pos)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SymposiumScreen()));
    }
  }

  void _handleHover(Offset pos, Rect agora, Rect stoa, Rect acropolis) {
    AcropolisZone? zone;
    if (agora.contains(pos)) zone = AcropolisZone.agora;
    else if (stoa.contains(pos)) zone = AcropolisZone.stoa;
    else if (acropolis.contains(pos)) zone = AcropolisZone.acropolis;
    if (zone != _hovered) setState(() => _hovered = zone);
  }
}

// ---------------------------------------------------------------------------

class _CityMapPainter extends CustomPainter {
  final double pulseT, flickerT;
  final AcropolisZone? hovered;
  final Rect agoraRect, stoaRect, acropolisRect;

  const _CityMapPainter({required this.pulseT, required this.flickerT,
      required this.hovered, required this.agoraRect,
      required this.stoaRect, required this.acropolisRect});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.black);

    _stars(canvas, w, h);
    _moon(canvas, w, h);
    _terrain(canvas, w, h);

    // Wall interior fill
    final wall = _wallPath(w, h);
    canvas.drawPath(wall, Paint()..color = _wallFill);

    // Thin wall stroke — shadow then highlight
    canvas.drawPath(wall, Paint()
      ..color = _copperDk..style = PaintingStyle.stroke
      ..strokeWidth = _px * 4.5..strokeJoin = StrokeJoin.round);
    canvas.drawPath(wall, Paint()
      ..color = _copper..style = PaintingStyle.stroke
      ..strokeWidth = _px * 2.0..strokeJoin = StrokeJoin.round);
    canvas.drawPath(wall, Paint()
      ..color = _copperLt..style = PaintingStyle.stroke
      ..strokeWidth = _px * 0.7..strokeJoin = StrokeJoin.round);

    _wallTowers(canvas, w, h);
    _battlements(canvas, w, h);
    _route(canvas, w, h);
    _gate(canvas, w, h);
    _market(canvas, w, h);
    _temple(canvas, w, h);
    _hoverGlow(canvas, w, h);
    _labels(canvas, w, h);
  }

  // ── Asymmetric wall ──────────────────────────────────────────────────────
  Path _wallPath(double w, double h) {
    final p = Path();
    p.moveTo(w * 0.445, h * 0.902);
    // Bottom-left (wider curve)
    p.quadraticBezierTo(w * 0.365, h * 0.898, w * 0.275, h * 0.868);
    // Left lower — notable outward bulge (asymmetric tower)
    p.quadraticBezierTo(w * 0.175, h * 0.840, w * 0.148, h * 0.755);
    p.quadraticBezierTo(w * 0.120, h * 0.682, w * 0.158, h * 0.608);
    // Left mid — tighter inward then out
    p.quadraticBezierTo(w * 0.205, h * 0.538, w * 0.168, h * 0.462);
    p.quadraticBezierTo(w * 0.130, h * 0.390, w * 0.172, h * 0.318);
    p.quadraticBezierTo(w * 0.215, h * 0.238, w * 0.292, h * 0.166);
    // Top arc — slightly left-leaning
    p.quadraticBezierTo(w * 0.368, h * 0.086, w * 0.492, h * 0.078);
    p.quadraticBezierTo(w * 0.608, h * 0.086, w * 0.695, h * 0.152);
    // Right upper — smoother, different rhythm from left
    p.quadraticBezierTo(w * 0.762, h * 0.218, w * 0.795, h * 0.305);
    p.quadraticBezierTo(w * 0.828, h * 0.392, w * 0.805, h * 0.472);
    // Right mid — smoother bulge
    p.quadraticBezierTo(w * 0.782, h * 0.548, w * 0.815, h * 0.628);
    p.quadraticBezierTo(w * 0.848, h * 0.705, w * 0.808, h * 0.775);
    // Right lower — tighter
    p.quadraticBezierTo(w * 0.772, h * 0.848, w * 0.692, h * 0.875);
    p.quadraticBezierTo(w * 0.625, h * 0.898, w * 0.555, h * 0.902);
    // Gate notch
    p.lineTo(w * 0.555, h * 0.962);
    p.lineTo(w * 0.445, h * 0.962);
    p.lineTo(w * 0.445, h * 0.902);
    p.close();
    return p;
  }

  // ── Small tower marks at wall bends ──────────────────────────────────────
  void _wallTowers(Canvas canvas, double w, double h) {
    void twrMark(double fx, double fy, double sz) {
      _r(canvas, Paint()..color = _copperDk, fx*w-sz*1.6, fy*h-sz*1.6, sz*3.2, sz*3.2);
      _r(canvas, Paint()..color = _copper,   fx*w-sz*1.2, fy*h-sz*1.2, sz*2.4, sz*2.4);
      _r(canvas, Paint()..color = _copperLt, fx*w-sz*1.2, fy*h-sz*1.2, sz*0.8, sz*0.8);
    }
    twrMark(0.148, 0.748, _px * 2.8); // left lower big
    twrMark(0.152, 0.462, _px * 2.4); // left upper
    twrMark(0.812, 0.628, _px * 2.4); // right lower
    twrMark(0.808, 0.472, _px * 2.2); // right upper
    twrMark(0.492, 0.082, _px * 2.0); // top center
  }

  // ── Battlements ──────────────────────────────────────────────────────────
  void _battlements(Canvas canvas, double w, double h) {
    final p = Paint()..color = _copper;
    void m(double fx, double fy) =>
        _r(canvas, p, fx*w-_px*1.5, fy*h-_px*3.5, _px*3, _px*3.5);
    for (final pt in [[0.40,0.093],[0.46,0.082],[0.50,0.080],[0.54,0.082],[0.60,0.093]]) { m(pt[0],pt[1]); }
    for (final pt in [[0.175,0.260],[0.155,0.390],[0.162,0.520],[0.168,0.648],[0.182,0.768]]) { m(pt[0],pt[1]); }
    for (final pt in [[0.798,0.255],[0.818,0.385],[0.808,0.510],[0.825,0.640],[0.800,0.762]]) { m(pt[0],pt[1]); }
  }

  // ── Stars — top 38% only ─────────────────────────────────────────────────
  void _stars(Canvas canvas, double w, double h) {
    final rng = math.Random(42);
    for (int i = 0; i < 70; i++) {
      final x     = rng.nextDouble() * w;
      final y     = rng.nextDouble() * h * 0.38;
      final phase = rng.nextDouble();
      final sz    = 0.7 + rng.nextDouble() * 1.4;
      final flick = math.sin(flickerT * math.pi * 4 + phase * math.pi * 2);
      final alpha = (0.30 + 0.60 * ((flick + 1) / 2)).clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(x - sz/2, y - sz/2, sz, sz),
          Paint()..color = _copper.withValues(alpha: alpha));
    }
  }

  // ── Crescent moon — small and neat ───────────────────────────────────────
  void _moon(Canvas canvas, double w, double h) {
    final cx = w * 0.115;
    final cy = h * 0.095;
    final r  = w * 0.022;
    // Subtle glow
    canvas.drawCircle(Offset(cx, cy), r * 1.8,
        Paint()
          ..color = _orange.withValues(alpha: 0.05 + 0.03 * pulseT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Disc
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _copperLt);
    // Cut — precise shadow circle
    canvas.drawCircle(Offset(cx + r * 0.46, cy - r * 0.06), r * 0.82,
        Paint()..color = Colors.black);
  }

  // ── Terrain: pixel trees + rocks (outside wall, lower canvas) ────────────
  void _terrain(Canvas canvas, double w, double h) {
    // Trees — left exterior
    _tree(canvas, w * 0.085, h * 0.720);
    _tree(canvas, w * 0.060, h * 0.800);
    _tree(canvas, w * 0.095, h * 0.860);
    // Trees — right exterior
    _tree(canvas, w * 0.910, h * 0.730);
    _tree(canvas, w * 0.935, h * 0.812);
    _tree(canvas, w * 0.900, h * 0.878);
    // Trees — bottom corners
    _tree(canvas, w * 0.175, h * 0.938);
    _tree(canvas, w * 0.820, h * 0.942);

    // Rocks — left
    _rock(canvas, w * 0.070, h * 0.758);
    _rock(canvas, w * 0.045, h * 0.840);
    _rock(canvas, w * 0.110, h * 0.900);
    // Rocks — right
    _rock(canvas, w * 0.930, h * 0.770);
    _rock(canvas, w * 0.955, h * 0.855);
    _rock(canvas, w * 0.885, h * 0.915);
    // Bottom rocks
    _rock(canvas, w * 0.240, h * 0.968);
    _rock(canvas, w * 0.760, h * 0.970);
  }

  void _tree(Canvas canvas, double cx, double cy) {
    // Trunk
    _r(canvas, Paint()..color = _copperDk, cx-_px, cy, _px*2, _px*3);
    // Foliage layers (bottom to top)
    _r(canvas, Paint()..color = _treeDk,   cx-_px*4,  cy-_px*4,  _px*8, _px*3);
    _r(canvas, Paint()..color = _treeLt,   cx-_px*3,  cy-_px*4,  _px*2, _px*2);
    _r(canvas, Paint()..color = _treeDk,   cx-_px*3,  cy-_px*7,  _px*6, _px*3);
    _r(canvas, Paint()..color = _treeLt,   cx-_px*2,  cy-_px*7,  _px*2, _px*1.5);
    _r(canvas, Paint()..color = _treeDk,   cx-_px*2,  cy-_px*10, _px*4, _px*3);
    _r(canvas, Paint()..color = _treeDk,   cx-_px,    cy-_px*13, _px*2, _px*2.5);
    _r(canvas, Paint()..color = _copperDk, cx-_px*.5, cy-_px*15, _px,   _px*2);
  }

  void _rock(Canvas canvas, double cx, double cy) {
    _r(canvas, Paint()..color = _copperDk, cx-_px*3, cy-_px,   _px*7,  _px*2);
    _r(canvas, Paint()..color = _copperDk, cx-_px*2, cy-_px*2, _px*5,  _px*1.5);
    _r(canvas, Paint()..color = _copper,   cx-_px*2, cy-_px,   _px*1.5,_px);
  }

  // ── Dotted route ─────────────────────────────────────────────────────────
  void _route(Canvas canvas, double w, double h) {
    final dot = Paint()..color = _copper.withValues(alpha: 0.50);
    final pts = [
      Offset(w*.500,h*.870), Offset(w*.500,h*.808), Offset(w*.476,h*.742),
      Offset(w*.488,h*.672), Offset(w*.502,h*.600), Offset(w*.516,h*.522),
      Offset(w*.500,h*.448), Offset(w*.500,h*.375), Offset(w*.500,h*.302),
      Offset(w*.500,h*.238),
    ];
    for (int i = 0; i < pts.length-1; i++) {
      final p0 = pts[i]; final p1 = pts[i+1];
      final steps = ((p1-p0).distance / (_px*6)).floor();
      for (int j = 0; j <= steps; j++) {
        final t = steps==0 ? 0.0 : j/steps;
        _r(canvas, dot,
            p0.dx+(p1.dx-p0.dx)*t - _px, p0.dy+(p1.dy-p0.dy)*t - _px,
            _px*2, _px*2);
      }
    }
  }

  // ── Gate — thin, stylized, integrated into wall ──────────────────────────
  void _gate(Canvas canvas, double w, double h) {
    final hot  = hovered == AcropolisZone.agora;
    final c    = hot ? _orange   : _copper;
    final cLt  = hot ? const Color(0xFFFFD090) : _copperLt;
    final cDk  = hot ? _copper   : _copperDk;
    final cx   = w * 0.500;
    final wallY = h * 0.902; // wall line at gate
    final floorY = h * 0.962;
    final gateW  = _px * 13;
    final gateH  = floorY - wallY;

    // Gate void
    _r(canvas, Paint()..color = Colors.black, cx-gateW/2, wallY, gateW, gateH);

    // Thin elegant pillars (wall-integrated — same thickness as wall)
    final pilW = _px * 2.5;
    final pilH = _px * 18;
    final pilY = wallY - pilH + gateH;
    // Left pillar
    _r(canvas, Paint()..color = cDk, cx-gateW/2-pilW, pilY, pilW, pilH);
    _r(canvas, Paint()..color = c,   cx-gateW/2-pilW, pilY, pilW, pilH);
    // Right pillar
    _r(canvas, Paint()..color = cDk, cx+gateW/2, pilY, pilW, pilH);
    _r(canvas, Paint()..color = c,   cx+gateW/2, pilY, pilW, pilH);

    // Pillar capitals (small T-caps)
    _r(canvas, Paint()..color = cLt, cx-gateW/2-pilW-_px*1.5, pilY, pilW+_px*3, _px*2);
    _r(canvas, Paint()..color = cLt, cx+gateW/2-_px*1.5,       pilY, pilW+_px*3, _px*2);

    // Lintel beam (thin elegant bar)
    _r(canvas, Paint()..color = cLt, cx-gateW/2-pilW-_px*2, wallY-_px*3, gateW+pilW*2+_px*4, _px*1.5);
    _r(canvas, Paint()..color = c,   cx-gateW/2-pilW-_px*2, wallY-_px*1.5, gateW+pilW*2+_px*4, _px);

    // Decorative arch (pixel steps inside gate top)
    for (int i = 0; i <= 5; i++) {
      final t     = i / 5.0;
      final angle = math.pi * t;
      final ax    = cx + math.cos(math.pi - angle) * (gateW/2 - _px*1.5);
      final ay    = wallY + (1 - math.sin(angle)) * _px * 4.5;
      _r(canvas, Paint()..color = cDk, ax-_px, ay-_px, _px*2, _px*2);
    }

    // Small ornament above lintel (three dots)
    for (int i = -1; i <= 1; i++) {
      _r(canvas, Paint()..color = cDk, cx+i*_px*4-_px, wallY-_px*7, _px*2, _px*2);
    }

    // Ground threshold
    _r(canvas, Paint()..color = cDk, cx-gateW/2-_px, floorY, gateW+_px*2, _px*1.5);
  }

  // ── Market — non-symmetric fine booths ──────────────────────────────────
  void _market(Canvas canvas, double w, double h) {
    final hot = hovered == AcropolisZone.stoa;
    final c   = hot ? _orange   : _copper;
    final cLt = hot ? const Color(0xFFFFD090) : _copperLt;
    final cDk = hot ? _copper   : _copperDk;

    // Non-symmetric booth definitions: [centerX fraction, baseY fraction, width*px, height*px]
    final booths = [
      [0.320, 0.598, 10.0, 15.0],  // narrow, tall
      [0.422, 0.594, 15.0, 12.0],  // wide, shorter
      [0.532, 0.601, 11.0, 16.0],  // narrow, tallest
      [0.640, 0.596, 13.0, 13.0],  // medium
    ];

    for (int i = 0; i < booths.length; i++) {
      final bx   = booths[i][0] * w;
      final by   = booths[i][1] * h;
      final bw   = booths[i][2] * _px;
      final bh   = booths[i][3] * _px;
      final sx   = bx - bw / 2;
      final sy   = by - bh;

      // Back wall
      _r(canvas, Paint()..color = cDk, sx, sy, bw, bh);
      _r(canvas, Paint()..color = cDk.withValues(alpha: 0.5), sx+bw-_px*1.5, sy, _px*1.5, bh);

      // Window/opening
      _r(canvas, Paint()..color = _wallFill, sx+bw*.18, sy+bh*.12, bw*.64, bh*.40);

      // Tiny goods in window
      _r(canvas, Paint()..color = cLt, sx+bw*.22, sy+bh*.38, _px*2, _px*2);
      _r(canvas, Paint()..color = c.withValues(alpha: 0.9), sx+bw*.50, sy+bh*.36, _px*1.5, _px*2.5);
      _r(canvas, Paint()..color = cLt.withValues(alpha: 0.7), sx+bw*.70, sy+bh*.38, _px*2, _px*1.5);

      // Hanging item (small dangling pixel)
      _r(canvas, Paint()..color = cDk, sx+bw*.40, sy+bh*.54, _px, _px*3);
      _r(canvas, Paint()..color = cLt, sx+bw*.40-_px, sy+bh*.54+_px*2.5, _px*3, _px*2);

      // Awning — each booth has slightly different style
      _awning(canvas, sx-_px*1.5, sy-_px*5.5, bw+_px*3, _px*5.5, c, cLt, i);

      // Counter
      _r(canvas, Paint()..color = c,   sx-_px*.5, by-_px*2.5, bw+_px, _px*2.8);
      _r(canvas, Paint()..color = cLt, sx-_px*.5, by-_px*2.5, bw+_px, _px*0.8);
      _r(canvas, Paint()..color = cDk, sx-_px*.5, by+_px*0.3, bw+_px, _px*0.8);

      // Booth number marker (tiny label)
      _r(canvas, Paint()..color = cDk, bx-_px, sy+_px*1.5, _px*2, _px*2);
    }

    // Small canopy connecting sign above all booths
    final x0 = booths.first[0] * w - booths.first[2] * _px / 2 - _px * 3;
    final x1 = booths.last[0] * w + booths.last[2] * _px / 2 + _px * 3;
    _r(canvas, Paint()..color = c, x0, booths[0][1]*h - booths[0][3]*_px - _px*7, x1-x0, _px*1.5);
  }

  void _awning(Canvas canvas, double x, double y, double aw, double ah,
      Color c, Color cLt, int style) {
    if (style == 0) {
      // Diagonal stripe
      double ry = y; int row = 0;
      while (ry < y+ah) {
        final rh = (y+ah-ry).clamp(0.0, _px*1.8);
        _r(canvas, Paint()..color = row%2==0 ? c : cLt.withValues(alpha:.65), x, ry, aw, rh);
        ry += _px*1.8; row++;
      }
    } else if (style == 1) {
      // Flat with border
      _r(canvas, Paint()..color = c, x, y, aw, ah);
      _r(canvas, Paint()..color = cLt, x, y, aw, _px);
      _r(canvas, Paint()..color = cLt, x, y+ah-_px, aw, _px);
    } else if (style == 2) {
      // Horizontal stripes
      double ry = y; int row = 0;
      while (ry < y+ah) {
        final rh = (y+ah-ry).clamp(0.0, _px*1.4);
        _r(canvas, Paint()..color = row%2==0 ? cLt.withValues(alpha:.8) : c, x, ry, aw, rh);
        ry += _px*1.4; row++;
      }
    } else {
      // Stepped edge
      _r(canvas, Paint()..color = c, x, y, aw, ah);
      for (int i = 0; i < (aw/(_px*3)).floor(); i++) {
        _r(canvas, Paint()..color = cLt, x+i*_px*3, y, _px*1.5, ah);
      }
    }
    // Fringe drops (all styles)
    _r(canvas, Paint()..color = cLt, x, y, aw, _px*0.8);
    final drops = (aw/(_px*5)).floor();
    for (int d = 0; d < drops; d++) {
      _r(canvas, Paint()..color = c, x+d*_px*5+_px, y+ah, _px*2, _px*3);
    }
  }

  // ── Temple — semi-3D ─────────────────────────────────────────────────────
  void _temple(Canvas canvas, double w, double h) {
    final hot  = hovered == AcropolisZone.acropolis;
    final c    = hot ? _orange   : _copper;
    final cLt  = hot ? const Color(0xFFFFD090) : _copperLt;
    final cDk  = hot ? _copper   : _copperDk;
    final vDk  = cDk.withValues(alpha: 0.85); // very dark for side faces
    final cx   = w * 0.500;
    final baseY = h * 0.368;
    const tW   = _px * 50.0;
    const colH = _px * 20.0;
    // 3D depth offset
    const dX   = _px * 6.0;
    const dY   = -_px * 3.5;

    // ── Back (depth) elements drawn first ──
    // Back steps
    for (int s = 0; s < 3; s++) {
      final sw = tW + s * _px * 7;
      final sy = baseY - s * _px * 2.5;
      _r(canvas, Paint()..color = vDk, cx-sw/2+dX, sy+dY, sw, _px*2.5);
    }
    // Back column tops (entablature back)
    final platY = baseY - _px * 7.5; final platW = tW - _px * 4;
    final entY = platY - colH - _px * 4.5;
    _r(canvas, Paint()..color = vDk, cx-tW/2+dX, entY+dY, tW, _px*5);

    // ── Right side faces (connecting front to back) ──
    void sideQuad(double x, double y, double ht, Color col) {
      final path = Path()
        ..moveTo(x,    y)    ..lineTo(x+dX, y+dY)
        ..lineTo(x+dX, y+dY+ht) ..lineTo(x,    y+ht) ..close();
      canvas.drawPath(path, Paint()..color = col);
    }

    // Step right faces
    for (int s = 0; s < 3; s++) {
      final sw = tW + s * _px * 7;
      final sy = baseY - s * _px * 2.5;
      sideQuad(cx + sw/2, sy, _px*2.5, vDk);
    }
    // Right side building body
    sideQuad(cx + tW/2, entY, _px*5, vDk);

    // ── Front elements ──
    // Steps
    for (int s = 0; s < 3; s++) {
      final sw = tW + s * _px * 7;
      final sy = baseY - s * _px * 2.5;
      _r(canvas, Paint()..color = s==0 ? cLt : c, cx-sw/2, sy, sw, _px*2.5);
      _r(canvas, Paint()..color = cDk, cx-sw/2, sy+_px*2, sw, _px*0.5);
      // Top face of step (parallelogram)
      final tp = Path()
        ..moveTo(cx-sw/2, sy) ..lineTo(cx-sw/2+dX, sy+dY)
        ..lineTo(cx+sw/2+dX,  sy+dY) ..lineTo(cx+sw/2, sy) ..close();
      canvas.drawPath(tp, Paint()..color = cLt.withValues(alpha: 0.6));
    }

    // Platform
    _r(canvas, Paint()..color = cLt, cx-platW/2, platY, platW, _px*2.5);
    {
      final tp = Path()
        ..moveTo(cx-platW/2, platY) ..lineTo(cx-platW/2+dX, platY+dY)
        ..lineTo(cx+platW/2+dX, platY+dY) ..lineTo(cx+platW/2, platY) ..close();
      canvas.drawPath(tp, Paint()..color = cLt.withValues(alpha: 0.5));
    }

    // Columns (8) — front face only, with 3D capitals
    const nC = 8;
    final colArea = platW - _px * 4; final colSp = colArea / (nC-1);
    final colBase = platY - colH;
    for (int i = 0; i < nC; i++) {
      final colX = cx - colArea/2 + i * colSp;
      // Capital top face (tiny parallelogram)
      final capPath = Path()
        ..moveTo(colX-_px*2.5, colBase)
        ..lineTo(colX-_px*2.5+dX, colBase+dY)
        ..lineTo(colX+_px*2.5+dX, colBase+dY)
        ..lineTo(colX+_px*2.5, colBase) ..close();
      canvas.drawPath(capPath, Paint()..color = cLt.withValues(alpha: 0.5));
      // Capital front
      _r(canvas, Paint()..color = cLt, colX-_px*2.5, colBase, _px*5, _px*2.5);
      // Shaft with fluting suggestion
      _r(canvas, Paint()..color = c,   colX-_px*1.5, colBase+_px*2.5, _px*3, colH-_px*5);
      _r(canvas, Paint()..color = cDk, colX+_px*0.8, colBase+_px*2.5, _px*0.8, colH-_px*5);
      _r(canvas, Paint()..color = cLt.withValues(alpha:.4), colX-_px*1.5, colBase+_px*2.5, _px*0.6, colH-_px*5);
      // Base
      _r(canvas, Paint()..color = cLt, colX-_px*2.5, platY-_px*2.5, _px*5, _px*2.5);
    }

    // Entablature
    _r(canvas, Paint()..color = cLt, cx-tW/2, entY,        tW, _px*2.5);
    _r(canvas, Paint()..color = c,   cx-tW/2, entY+_px*2.5, tW, _px*2.5);
    // Triglyphs on frieze
    for (int t = 0; t < 7; t++) {
      final tx = cx-tW/2+_px*5 + t*(tW-_px*10)/6;
      _r(canvas, Paint()..color = cDk, tx,        entY+_px*2.5, _px*1.5, _px*2.5);
      _r(canvas, Paint()..color = cDk, tx+_px*3,  entY+_px*2.5, _px*1.5, _px*2.5);
    }
    // Entablature top face
    {
      final ep = Path()
        ..moveTo(cx-tW/2, entY) ..lineTo(cx-tW/2+dX, entY+dY)
        ..lineTo(cx+tW/2+dX, entY+dY) ..lineTo(cx+tW/2, entY) ..close();
      canvas.drawPath(ep, Paint()..color = cLt.withValues(alpha: 0.45));
    }

    // Pediment (pixel-stepped triangle) — front
    final pedBase = entY - _px * 0.5;
    const pedS = 12;
    for (int i = 0; i < pedS; i++) {
      final rowW = tW * (1 - i/pedS) + _px*2;
      _r(canvas, Paint()..color = i==0?cLt:c, cx-rowW/2, pedBase-i*_px*1.8, rowW, _px*2.1);
    }
    final peakY = pedBase - pedS * _px * 1.8;

    // Pediment right side face
    {
      final pp = Path()
        ..moveTo(cx+tW/2, pedBase)
        ..lineTo(cx+tW/2+dX, pedBase+dY)
        ..lineTo(cx+dX, peakY+dY)
        ..lineTo(cx, peakY) ..close();
      canvas.drawPath(pp, Paint()..color = vDk);
    }
    // Pediment top ridge (front peak to back peak)
    _r(canvas, Paint()..color = cDk, cx-_px, peakY, dX+_px*2, _px);

    // Pulsing star at peak
    final ga = (0.22 + 0.42 * pulseT).clamp(0.0, 1.0);
    canvas.drawCircle(Offset(cx, peakY-_px*7), _px*6,
        Paint()..color=(hot?_orange:_copper).withValues(alpha:ga)
          ..maskFilter=const MaskFilter.blur(BlurStyle.normal,9));
    _star4(canvas, cx, peakY-_px*7, hot?_orange:cLt, _px*2.8);
  }

  void _star4(Canvas canvas, double cx, double cy, Color c, double s) {
    final p = Paint()..color = c;
    _r(canvas,p,cx-s*.22,cy-s,   s*.44,s*2  );
    _r(canvas,p,cx-s,    cy-s*.22,s*2,  s*.44);
    _r(canvas,p,cx-s*.60,cy-s*.60,s*.30,s*.30);
    _r(canvas,p,cx+s*.30,cy-s*.60,s*.30,s*.30);
    _r(canvas,p,cx-s*.60,cy+s*.30,s*.30,s*.30);
    _r(canvas,p,cx+s*.30,cy+s*.30,s*.30,s*.30);
    _r(canvas,p,cx-s*.35,cy-s*.35,s*.70,s*.70);
  }

  void _hoverGlow(Canvas canvas, double w, double h) {
    if (hovered == null) return;
    final rect = switch (hovered!) {
      AcropolisZone.agora     => agoraRect,
      AcropolisZone.stoa      => stoaRect,
      AcropolisZone.acropolis => acropolisRect,
    };
    canvas.drawRect(rect.inflate(_px*2), Paint()
      ..color = _orange.withValues(alpha: (0.13+0.18*pulseT).clamp(0.0,1.0))
      ..style = PaintingStyle.stroke..strokeWidth = _px*1.8);
  }

  void _labels(Canvas canvas, double w, double h) {
    _lbl(canvas, 'AGORA',          w*.50, h*.957, _copper,  _px*2.1);
    _lbl(canvas, 'STOA',           w*.50, h*.678, _copper,  _px*2.1);
    _lbl(canvas, 'SYMPOSIUM',      w*.50, h*.118, _copperLt, _px*1.9);
    _lbl(canvas, 'A · C · R · O', w*.50, h*.028, _copper, _px*2.3, ls:7.0);
  }

  void _lbl(Canvas canvas, String text, double cx, double cy,
      Color color, double fs, {double ls = 2.0}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
          fontFamily: 'monospace', fontSize: fs, fontWeight: FontWeight.bold,
          color: color, letterSpacing: ls,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width/2, cy - tp.height/2));
  }

  void _r(Canvas canvas, Paint paint, double x, double y, double w, double h) {
    if (w <= 0 || h <= 0) return;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  @override
  bool shouldRepaint(_CityMapPainter old) =>
      old.pulseT != pulseT || old.flickerT != flickerT || old.hovered != hovered;
}
