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
            // Wider stoa rect to cover spread booths (0.285–0.688 cx)
            final stoaRect      = Rect.fromLTWH(w * 0.20, h * 0.50, w * 0.60, h * 0.18);
            final acropolisRect = Rect.fromLTWH(w * 0.30, h * 0.10, w * 0.40, h * 0.28);
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

    final wall = _wallPath(w, h);
    canvas.drawPath(wall, Paint()..color = _wallFill);

    // Thin wall — shadow then main line then highlight
    canvas.drawPath(wall, Paint()
      ..color = _copperDk..style = PaintingStyle.stroke
      ..strokeWidth = _px * 3.0..strokeJoin = StrokeJoin.round);
    canvas.drawPath(wall, Paint()
      ..color = _copper..style = PaintingStyle.stroke
      ..strokeWidth = _px * 1.1..strokeJoin = StrokeJoin.round);
    canvas.drawPath(wall, Paint()
      ..color = _copperLt..style = PaintingStyle.stroke
      ..strokeWidth = _px * 0.45..strokeJoin = StrokeJoin.round);

    _wallTowers(canvas, w, h);
    _battlements(canvas, w, h);
    _route(canvas, w, h);
    _gate(canvas, w, h);
    _market(canvas, w, h);
    _temple(canvas, w, h);
    _hoverGlow(canvas, w, h);
    _labels(canvas, w, h);
  }

  // ── Asymmetric wall — left is more angular/concave, right more convex ────
  Path _wallPath(double w, double h) {
    final p = Path();
    p.moveTo(w * 0.448, h * 0.902);
    // Bottom-left — wide natural sweep
    p.quadraticBezierTo(w * 0.348, h * 0.895, w * 0.245, h * 0.854);
    // Left lower — sharp angular notch (dramatically concave)
    p.quadraticBezierTo(w * 0.128, h * 0.812, w * 0.108, h * 0.705);
    p.quadraticBezierTo(w * 0.090, h * 0.615, w * 0.140, h * 0.535);
    // Left mid — tight inward then sharp out
    p.quadraticBezierTo(w * 0.222, h * 0.456, w * 0.125, h * 0.368);
    p.quadraticBezierTo(w * 0.062, h * 0.282, w * 0.148, h * 0.195);
    p.quadraticBezierTo(w * 0.235, h * 0.108, w * 0.322, h * 0.072);
    // Top arc — noticeably left-offset
    p.quadraticBezierTo(w * 0.408, h * 0.044, w * 0.514, h * 0.042);
    p.quadraticBezierTo(w * 0.622, h * 0.048, w * 0.714, h * 0.105);
    // Right upper — rounder, gentler than left
    p.quadraticBezierTo(w * 0.785, h * 0.165, w * 0.822, h * 0.252);
    p.quadraticBezierTo(w * 0.860, h * 0.342, w * 0.832, h * 0.435);
    // Right mid — smoother bulge (different rhythm from left)
    p.quadraticBezierTo(w * 0.806, h * 0.512, w * 0.848, h * 0.602);
    p.quadraticBezierTo(w * 0.882, h * 0.692, w * 0.832, h * 0.760);
    // Right lower — tighter, less dramatic
    p.quadraticBezierTo(w * 0.780, h * 0.838, w * 0.678, h * 0.865);
    p.quadraticBezierTo(w * 0.615, h * 0.895, w * 0.552, h * 0.902);
    // Gate notch
    p.lineTo(w * 0.552, h * 0.960);
    p.lineTo(w * 0.448, h * 0.960);
    p.lineTo(w * 0.448, h * 0.902);
    p.close();
    return p;
  }

  // ── Tower marks at wall bends ─────────────────────────────────────────────
  void _wallTowers(Canvas canvas, double w, double h) {
    void twrMark(double fx, double fy, double sz) {
      _r(canvas, Paint()..color = _copperDk, fx*w-sz*1.6, fy*h-sz*1.6, sz*3.2, sz*3.2);
      _r(canvas, Paint()..color = _copper,   fx*w-sz*1.2, fy*h-sz*1.2, sz*2.4, sz*2.4);
      _r(canvas, Paint()..color = _copperLt, fx*w-sz*1.2, fy*h-sz*1.2, sz*0.8, sz*0.8);
    }
    twrMark(0.108, 0.700, _px * 2.6);
    twrMark(0.130, 0.445, _px * 2.2);
    twrMark(0.840, 0.602, _px * 2.2);
    twrMark(0.832, 0.435, _px * 2.0);
    twrMark(0.514, 0.050, _px * 1.8);
  }

  // ── Battlements ──────────────────────────────────────────────────────────
  void _battlements(Canvas canvas, double w, double h) {
    final p = Paint()..color = _copper;
    void m(double fx, double fy) =>
        _r(canvas, p, fx*w-_px*1.4, fy*h-_px*3.0, _px*2.8, _px*3.0);
    for (final pt in [[0.40,0.054],[0.46,0.046],[0.51,0.044],[0.56,0.047],[0.62,0.058]]) { m(pt[0],pt[1]); }
    for (final pt in [[0.168,0.248],[0.140,0.372],[0.148,0.498],[0.148,0.622],[0.158,0.750]]) { m(pt[0],pt[1]); }
    for (final pt in [[0.802,0.244],[0.826,0.374],[0.816,0.500],[0.836,0.628],[0.812,0.752]]) { m(pt[0],pt[1]); }
  }

  // ── Stars — top 22% only, mix of dots and cross-shaped ───────────────────
  void _stars(Canvas canvas, double w, double h) {
    final rng = math.Random(42);
    for (int i = 0; i < 68; i++) {
      final x     = rng.nextDouble() * w;
      final y     = rng.nextDouble() * h * 0.22;
      final phase = rng.nextDouble();
      final sz    = 0.5 + rng.nextDouble() * 1.3;
      final flick = math.sin(flickerT * math.pi * 4 + phase * math.pi * 2);
      final alpha = (0.30 + 0.60 * ((flick + 1) / 2)).clamp(0.0, 1.0);

      if (rng.nextDouble() > 0.58) {
        // Cross-shaped star (4 arms)
        final ca = _copper.withValues(alpha: alpha * 0.82);
        _r(canvas, Paint()..color = ca, x - sz*0.28, y - sz*1.5, sz*0.56, sz*3.0);
        _r(canvas, Paint()..color = ca, x - sz*1.5,  y - sz*0.28, sz*3.0,  sz*0.56);
        // Bright centre pixel
        _r(canvas, Paint()..color = _copperLt.withValues(alpha: alpha),
            x - sz*0.18, y - sz*0.18, sz*0.36, sz*0.36);
      } else {
        // Simple square dot
        canvas.drawRect(Rect.fromLTWH(x - sz/2, y - sz/2, sz, sz),
            Paint()..color = _copper.withValues(alpha: alpha));
      }
    }
  }

  // ── Pixelated crescent moon — fine pixel grid, small ─────────────────────
  void _moon(Canvas canvas, double w, double h) {
    final ox = w * 0.086 - _px * 3.8;
    final oy = h * 0.060 - _px * 3.8;
    const u  = _px * 1.05;  // fine pixel unit
    const g  = u * 1.28;    // grid step

    // 7×7 left-facing crescent (lit on left, cutout on right)
    const crescent = [
      [0, 0, 1, 1, 1, 0, 0],
      [0, 1, 1, 1, 1, 0, 0],
      [1, 1, 1, 0, 0, 0, 0],
      [1, 1, 0, 0, 0, 0, 0],
      [1, 1, 1, 0, 0, 0, 0],
      [0, 1, 1, 1, 1, 0, 0],
      [0, 0, 1, 1, 1, 0, 0],
    ];

    // Soft glow behind
    canvas.drawCircle(
      Offset(ox + g * 1.5, oy + g * 3.0),
      g * 4.2,
      Paint()
        ..color = _orange.withValues(alpha: 0.030 + 0.018 * pulseT)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    for (int row = 0; row < 7; row++) {
      for (int col = 0; col < 7; col++) {
        if (crescent[row][col] == 1) {
          // Outer-edge pixels get highlight, inner get base copper
          final isEdge = row == 0 || row == 6 || col == 0 ||
              (row == 1 && col <= 1) || (row == 5 && col <= 1);
          _r(canvas,
            Paint()..color = isEdge
                ? _copperLt
                : _copper.withValues(alpha: 0.88),
            ox + col * g, oy + row * g, u, u);
        }
      }
    }
  }

  // ── Terrain: artisanal trees + rocks outside wall, denser at bottom ───────
  void _terrain(Canvas canvas, double w, double h) {
    // Left exterior trees
    _tree(canvas, w * 0.082, h * 0.712);
    _tree(canvas, w * 0.055, h * 0.796);
    _tree(canvas, w * 0.092, h * 0.858);
    _treeSmall(canvas, w * 0.036, h * 0.748);
    _treeSmall(canvas, w * 0.065, h * 0.832);
    _treeSmall(canvas, w * 0.025, h * 0.870);

    // Right exterior trees
    _tree(canvas, w * 0.914, h * 0.720);
    _tree(canvas, w * 0.940, h * 0.806);
    _tree(canvas, w * 0.904, h * 0.868);
    _treeSmall(canvas, w * 0.958, h * 0.755);
    _treeSmall(canvas, w * 0.930, h * 0.842);
    _treeSmall(canvas, w * 0.972, h * 0.872);

    // Bottom corners
    _tree(canvas, w * 0.170, h * 0.938);
    _tree(canvas, w * 0.828, h * 0.942);
    _treeSmall(canvas, w * 0.132, h * 0.966);
    _treeSmall(canvas, w * 0.862, h * 0.968);
    _treeSmall(canvas, w * 0.195, h * 0.970);
    _treeSmall(canvas, w * 0.808, h * 0.974);

    // Left exterior rocks
    _rock(canvas, w * 0.066, h * 0.750);
    _rock(canvas, w * 0.040, h * 0.838);
    _rock(canvas, w * 0.106, h * 0.896);
    _rockSmall(canvas, w * 0.026, h * 0.805);
    _rockSmall(canvas, w * 0.078, h * 0.925);
    _rockSmall(canvas, w * 0.048, h * 0.872);

    // Right exterior rocks
    _rock(canvas, w * 0.934, h * 0.760);
    _rock(canvas, w * 0.960, h * 0.846);
    _rock(canvas, w * 0.888, h * 0.916);
    _rockSmall(canvas, w * 0.975, h * 0.812);
    _rockSmall(canvas, w * 0.918, h * 0.946);
    _rockSmall(canvas, w * 0.950, h * 0.878);

    // Bottom rocks
    _rock(canvas, w * 0.236, h * 0.966);
    _rock(canvas, w * 0.764, h * 0.970);
    _rockSmall(canvas, w * 0.208, h * 0.986);
    _rockSmall(canvas, w * 0.792, h * 0.988);
    _rockSmall(canvas, w * 0.252, h * 0.980);
    _rockSmall(canvas, w * 0.748, h * 0.982);

    // Ground tufts (fine brush details)
    _tuft(canvas, w * 0.045, h * 0.876);
    _tuft(canvas, w * 0.118, h * 0.918);
    _tuft(canvas, w * 0.148, h * 0.952);
    _tuft(canvas, w * 0.878, h * 0.886);
    _tuft(canvas, w * 0.952, h * 0.898);
    _tuft(canvas, w * 0.845, h * 0.955);
    _tuft(canvas, w * 0.215, h * 0.958);
    _tuft(canvas, w * 0.784, h * 0.962);
  }

  void _tree(Canvas canvas, double cx, double cy) {
    _r(canvas, Paint()..color = _copperDk, cx-_px,    cy,        _px*2,   _px*3);
    _r(canvas, Paint()..color = _treeDk,   cx-_px*4,  cy-_px*4,  _px*8,   _px*3);
    _r(canvas, Paint()..color = _treeLt,   cx-_px*3,  cy-_px*4,  _px*2,   _px*2);
    _r(canvas, Paint()..color = _treeDk,   cx-_px*3,  cy-_px*7,  _px*6,   _px*3);
    _r(canvas, Paint()..color = _treeLt,   cx-_px*2,  cy-_px*7,  _px*2,   _px*1.5);
    _r(canvas, Paint()..color = _treeDk,   cx-_px*2,  cy-_px*10, _px*4,   _px*3);
    _r(canvas, Paint()..color = _treeDk,   cx-_px,    cy-_px*13, _px*2,   _px*2.5);
    _r(canvas, Paint()..color = _copperDk, cx-_px*.5, cy-_px*15, _px,     _px*2);
  }

  void _treeSmall(Canvas canvas, double cx, double cy) {
    _r(canvas, Paint()..color = _copperDk, cx-_px*.5, cy,        _px,     _px*2);
    _r(canvas, Paint()..color = _treeDk,   cx-_px*2.5,cy-_px*2.5,_px*5,   _px*2.5);
    _r(canvas, Paint()..color = _treeLt,   cx-_px*1.5,cy-_px*2.5,_px*1.5, _px*1.5);
    _r(canvas, Paint()..color = _treeDk,   cx-_px*2,  cy-_px*5,  _px*4,   _px*2.5);
    _r(canvas, Paint()..color = _treeDk,   cx-_px,    cy-_px*7.5,_px*2,   _px*2);
    _r(canvas, Paint()..color = _copperDk, cx-_px*.5, cy-_px*9.5,_px,     _px*1.5);
  }

  void _rock(Canvas canvas, double cx, double cy) {
    _r(canvas, Paint()..color = _copperDk, cx-_px*3,   cy-_px,    _px*7,   _px*2);
    _r(canvas, Paint()..color = _copperDk, cx-_px*2,   cy-_px*2.5,_px*5,   _px*2);
    _r(canvas, Paint()..color = _copperDk, cx-_px*1.5, cy-_px*3.5,_px*3,   _px*1.5);
    _r(canvas, Paint()..color = _copper,   cx-_px*2,   cy-_px,    _px*1.5, _px*0.8);
  }

  void _rockSmall(Canvas canvas, double cx, double cy) {
    _r(canvas, Paint()..color = _copperDk, cx-_px*2,   cy-_px*.5, _px*4.5, _px*1.5);
    _r(canvas, Paint()..color = _copperDk, cx-_px*1.5, cy-_px*2,  _px*3.5, _px*1.5);
    _r(canvas, Paint()..color = _copper,   cx-_px*1.5, cy-_px*.5, _px,     _px*0.7);
  }

  void _tuft(Canvas canvas, double cx, double cy) {
    _r(canvas, Paint()..color = _treeDk, cx-_px*1.5, cy-_px*2,   _px,     _px*2);
    _r(canvas, Paint()..color = _treeDk, cx,          cy-_px*2.5, _px,     _px*2.5);
    _r(canvas, Paint()..color = _treeDk, cx+_px*1.5,  cy-_px*1.5, _px,     _px*1.5);
    _r(canvas, Paint()..color = _treeLt, cx,           cy-_px*3,   _px*0.6, _px*0.6);
  }

  // ── Dotted route — fine pixels, snakes through gate → each booth → temple ─
  void _route(Canvas canvas, double w, double h) {
    final dot = Paint()..color = _copper.withValues(alpha: 0.46);
    // Enters gate, fans left to booth 1, travels right through all 5 booths,
    // converges to centre, then climbs to temple
    final pts = [
      Offset(w*.500, h*.948),  // gate floor
      Offset(w*.500, h*.908),  // gate void top
      Offset(w*.500, h*.868),  // inside city, above gate
      Offset(w*.285, h*.600),  // through booth 1 (far left)
      Offset(w*.378, h*.596),  // through booth 2
      Offset(w*.488, h*.601),  // through booth 3 (centre)
      Offset(w*.602, h*.595),  // through booth 4
      Offset(w*.688, h*.590),  // through booth 5 (far right)
      Offset(w*.500, h*.532),  // converge to centre after market
      Offset(w*.500, h*.450),  // upper city
      Offset(w*.500, h*.372),  // temple base approach
      Offset(w*.500, h*.305),  // through temple steps
      Offset(w*.500, h*.248),  // temple colonnade
      Offset(w*.500, h*.188),  // temple upper
    ];
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i]; final p1 = pts[i + 1];
      final steps = ((p1 - p0).distance / (_px * 4.5)).floor().clamp(1, 250);
      for (int j = 0; j <= steps; j++) {
        final t = j / steps;
        _r(canvas, dot,
            p0.dx + (p1.dx - p0.dx) * t - _px * 0.65,
            p0.dy + (p1.dy - p0.dy) * t - _px * 0.65,
            _px * 1.3, _px * 1.3);
      }
    }
  }

  // ── Gate — fine pixel details, torches, layered arch ────────────────────
  void _gate(Canvas canvas, double w, double h) {
    final hot   = hovered == AcropolisZone.agora;
    final c     = hot ? _orange : _copper;
    final cLt   = hot ? const Color(0xFFFFD090) : _copperLt;
    final cDk   = hot ? _copper : _copperDk;
    final cx    = w * 0.500;
    final wallY = h * 0.902;
    final floorY = h * 0.960;
    final gateW  = _px * 11.5;
    final gateH  = floorY - wallY;

    // Gate void
    _r(canvas, Paint()..color = Colors.black, cx - gateW / 2, wallY, gateW, gateH);

    // Threshold steps (3 tiny pixel steps)
    for (int s = 0; s < 3; s++) {
      final sw = gateW - s * _px * 1.8;
      _r(canvas, Paint()..color = cDk, cx - sw / 2, floorY - (s + 1) * _px * 2.2, sw, _px * 2.2);
      _r(canvas, Paint()..color = cLt, cx - sw / 2, floorY - (s + 1) * _px * 2.2, sw, _px * 0.5);
    }

    // Pillars — fine, fluted
    final pilW = _px * 2.0;
    final pilH = _px * 18.0;
    final pilY = wallY - pilH * 0.30 + gateH;
    // Left pillar
    _r(canvas, Paint()..color = cDk.withValues(alpha: .55), cx - gateW / 2 - pilW - _px * 0.5, pilY, _px * 0.5, pilH * 0.78);
    _r(canvas, Paint()..color = c,   cx - gateW / 2 - pilW, pilY, pilW, pilH * 0.78);
    _r(canvas, Paint()..color = cLt.withValues(alpha: .55), cx - gateW / 2 - pilW, pilY, _px * 0.4, pilH * 0.78);
    // Left flute line
    _r(canvas, Paint()..color = cDk.withValues(alpha: .45), cx - gateW / 2 - _px * 0.8, pilY + _px * 2, _px * 0.5, pilH * 0.68);
    // Right pillar
    _r(canvas, Paint()..color = cDk.withValues(alpha: .55), cx + gateW / 2 + _px * 0.5, pilY, _px * 0.5, pilH * 0.78);
    _r(canvas, Paint()..color = c,   cx + gateW / 2, pilY, pilW, pilH * 0.78);
    _r(canvas, Paint()..color = cLt.withValues(alpha: .55), cx + gateW / 2, pilY, _px * 0.4, pilH * 0.78);
    _r(canvas, Paint()..color = cDk.withValues(alpha: .45), cx + gateW / 2 + pilW - _px * 0.4, pilY + _px * 2, _px * 0.5, pilH * 0.68);

    // Capitals (T-caps)
    _r(canvas, Paint()..color = cLt, cx - gateW / 2 - pilW - _px * 1.6, pilY, pilW + _px * 3.2, _px * 1.6);
    _r(canvas, Paint()..color = cLt, cx + gateW / 2 - _px * 1.6,        pilY, pilW + _px * 3.2, _px * 1.6);

    // Lintel — layered depth
    final linX = cx - gateW / 2 - pilW - _px * 2.2;
    final linW = gateW + pilW * 2 + _px * 4.4;
    _r(canvas, Paint()..color = cDk, linX, wallY - _px * 4.2, linW, _px * 4.2);
    _r(canvas, Paint()..color = c,   linX, wallY - _px * 2.8, linW, _px * 1.8);
    _r(canvas, Paint()..color = cLt, linX, wallY - _px * 4.2, linW, _px * 0.7);
    // Carved glyph slab on lintel centre
    _r(canvas, Paint()..color = cDk.withValues(alpha: .8), cx - _px * 1.4, wallY - _px * 3.6, _px * 2.8, _px * 1.8);
    _r(canvas, Paint()..color = cLt.withValues(alpha: .35), cx - _px * 1.0, wallY - _px * 3.6, _px * 1.4, _px * 0.5);

    // Arch — 9 pixel steps, fine
    for (int i = 0; i <= 9; i++) {
      final t     = i / 9.0;
      final angle = math.pi * t;
      final ax    = cx + math.cos(math.pi - angle) * (gateW / 2 - _px * 1.0);
      final ay    = wallY + (1 - math.sin(angle)) * _px * 5.0;
      _r(canvas, Paint()..color = cDk, ax - _px * 0.7, ay - _px * 0.7, _px * 1.4, _px * 1.4);
      if (i % 2 == 0) {
        _r(canvas, Paint()..color = cLt.withValues(alpha: .28), ax - _px * 0.35, ay - _px * 0.7, _px * 0.35, _px * 0.35);
      }
    }

    // Torch brackets — outer sides of pillars
    // Left torch
    _r(canvas, Paint()..color = cDk, cx - gateW / 2 - pilW - _px * 3.8, wallY - _px * 7.5, _px * 1.8, _px * 4.5);
    _r(canvas, Paint()..color = cLt, cx - gateW / 2 - pilW - _px * 3.8, wallY - _px * 8.8, _px * 1.8, _px * 1.4);
    _r(canvas, Paint()..color = _orange.withValues(alpha: 0.48 + 0.30 * flickerT),
        cx - gateW / 2 - pilW - _px * 4.0, wallY - _px * 11.5, _px * 2.2, _px * 3.0);
    _r(canvas, Paint()..color = _copperLt.withValues(alpha: 0.25 + 0.20 * flickerT),
        cx - gateW / 2 - pilW - _px * 3.6, wallY - _px * 12.5, _px * 1.2, _px * 1.0);
    // Right torch
    _r(canvas, Paint()..color = cDk, cx + gateW / 2 + pilW + _px * 2.0, wallY - _px * 7.5, _px * 1.8, _px * 4.5);
    _r(canvas, Paint()..color = cLt, cx + gateW / 2 + pilW + _px * 2.0, wallY - _px * 8.8, _px * 1.8, _px * 1.4);
    _r(canvas, Paint()..color = _orange.withValues(alpha: 0.48 + 0.30 * (1 - flickerT)),
        cx + gateW / 2 + pilW + _px * 1.8, wallY - _px * 11.5, _px * 2.2, _px * 3.0);
    _r(canvas, Paint()..color = _copperLt.withValues(alpha: 0.25 + 0.20 * (1 - flickerT)),
        cx + gateW / 2 + pilW + _px * 2.2, wallY - _px * 12.5, _px * 1.2, _px * 1.0);

    // Three ornament dots above lintel
    for (int i = -1; i <= 1; i++) {
      _r(canvas, Paint()..color = cDk, cx + i * _px * 3.2 - _px * 0.55, wallY - _px * 5.5, _px * 1.1, _px * 1.1);
    }

    // Ground threshold line
    _r(canvas, Paint()..color = cDk, cx - gateW / 2 - _px, floorY, gateW + _px * 2, _px * 1.1);
  }

  // ── Market — 5 booths, spread wide + non-symmetrical ─────────────────────
  void _market(Canvas canvas, double w, double h) {
    final hot = hovered == AcropolisZone.stoa;
    final c   = hot ? _orange   : _copper;
    final cLt = hot ? const Color(0xFFFFD090) : _copperLt;
    final cDk = hot ? _copper   : _copperDk;

    // [centerX, baseY, widthPx, heightPx]
    final booths = [
      [0.285, 0.600,  9.0, 16.0],
      [0.378, 0.596, 15.0, 12.0],
      [0.488, 0.603, 10.0, 17.0],
      [0.602, 0.597, 13.0, 14.0],
      [0.688, 0.592,  8.0, 11.0],
    ];

    // Overhead banner connecting all booths
    final bx0 = booths.first[0] * w - booths.first[2] * _px / 2 - _px * 4;
    final bx1 = booths.last[0]  * w + booths.last[2]  * _px / 2 + _px * 4;
    final bannerY = booths[0][1] * h - booths[0][3] * _px - _px * 9;
    _r(canvas, Paint()..color = c,   bx0, bannerY,          bx1 - bx0, _px * 1.0);
    _r(canvas, Paint()..color = cLt, bx0, bannerY,          bx1 - bx0, _px * 0.4);
    _r(canvas, Paint()..color = cDk, bx0, bannerY + _px,    bx1 - bx0, _px * 0.4);
    // Banner pendant drops
    final pendW = (bx1 - bx0) / 9;
    for (int d = 0; d < 9; d++) {
      _r(canvas, Paint()..color = cDk, bx0 + d * pendW + pendW * 0.35, bannerY + _px * 1.0, _px * 0.7, _px * 2.5);
      _r(canvas, Paint()..color = c,   bx0 + d * pendW + pendW * 0.35, bannerY + _px * 3.0, _px * 1.4, _px * 1.4);
    }

    for (int i = 0; i < booths.length; i++) {
      final bx = booths[i][0] * w;
      final by = booths[i][1] * h;
      final bw = booths[i][2] * _px;
      final bh = booths[i][3] * _px;
      final sx = bx - bw / 2;
      final sy = by - bh;

      // Subtle drop shadow
      _r(canvas, Paint()..color = cDk.withValues(alpha: .55), sx + _px * 0.6, sy + _px * 0.6, bw, bh);
      // Back wall
      _r(canvas, Paint()..color = cDk, sx, sy, bw, bh);
      // Side shadow stripe
      _r(canvas, Paint()..color = cDk.withValues(alpha: .40), sx + bw - _px * 1.4, sy, _px * 1.4, bh);

      // Window
      _r(canvas, Paint()..color = _wallFill, sx + bw * .18, sy + bh * .12, bw * .64, bh * .42);

      // Goods — varied per booth
      _boothGoods(canvas, sx, sy, bw, bh, c, cLt, cDk, i);

      // Hanging cord + sign above each booth
      final signW = bw * 0.52;
      _r(canvas, Paint()..color = cDk, bx - _px * 0.3, sy - _px * 4.5, _px * 0.6, _px * 4.5);
      _r(canvas, Paint()..color = cDk, bx - signW / 2 - _px * 0.4, sy - _px * 0.2, signW + _px * 0.8, _px * 2.8);
      _r(canvas, Paint()..color = c,   bx - signW / 2, sy - _px * 0.2, signW, _px * 2.4);
      _r(canvas, Paint()..color = cLt, bx - signW / 2, sy - _px * 0.2, signW, _px * 0.4);

      // Awning
      _awning(canvas, sx - _px * 1.5, sy - _px * 5.5, bw + _px * 3, _px * 5.5, c, cLt, i);

      // Counter
      _r(canvas, Paint()..color = c,   sx - _px * .5, by - _px * 2.8, bw + _px, _px * 2.8);
      _r(canvas, Paint()..color = cLt, sx - _px * .5, by - _px * 2.8, bw + _px, _px * 0.6);
      _r(canvas, Paint()..color = cDk, sx - _px * .5, by - _px * 0.4, bw + _px, _px * 0.6);

      // Jar/barrel beside alternate booths
      if (i.isEven) {
        _jar(canvas, sx - _px * 4.0, by - _px * 4.5, c, cDk);
      } else {
        _jar(canvas, sx + bw + _px * 1.8, by - _px * 4.5, c, cDk);
      }
    }
  }

  void _boothGoods(Canvas canvas, double sx, double sy, double bw, double bh,
      Color c, Color cLt, Color cDk, int i) {
    final wx = sx + bw * .18;
    final wy = sy + bh * .12;
    final ww = bw * .64;
    final wh = bh * .42;

    if (i == 0) {
      // Scrolls
      _r(canvas, Paint()..color = cLt, wx + ww * .10, wy + wh * .10, _px * 2.0, wh * .72);
      _r(canvas, Paint()..color = cLt, wx + ww * .38, wy + wh * .20, _px * 1.6, wh * .60);
      _r(canvas, Paint()..color = cLt.withValues(alpha: .55), wx + ww * .62, wy + wh * .15, _px * 1.8, wh * .66);
      _r(canvas, Paint()..color = cDk, wx + ww * .10, wy + wh * .10, _px * 2.0, _px * 0.5);
      _r(canvas, Paint()..color = cDk, wx + ww * .10, wy + wh * .82 - _px * .5, _px * 2.0, _px * 0.5);
    } else if (i == 1) {
      // Pots
      _r(canvas, Paint()..color = c, wx + ww * .10, wy + wh * .50, _px * 2.8, wh * .40);
      _r(canvas, Paint()..color = cLt, wx + ww * .10, wy + wh * .50, _px * 2.8, _px * 0.5);
      _r(canvas, Paint()..color = c, wx + ww * .43, wy + wh * .32, _px * 3.2, wh * .58);
      _r(canvas, Paint()..color = cLt, wx + ww * .43, wy + wh * .32, _px * 3.2, _px * 0.5);
      _r(canvas, Paint()..color = c, wx + ww * .76, wy + wh * .55, _px * 2.0, wh * .35);
    } else if (i == 2) {
      // Cloth/fabric (horizontal bands)
      for (int row = 0; row < 4; row++) {
        _r(canvas, Paint()..color = row.isEven ? cLt.withValues(alpha: .85) : cDk.withValues(alpha: .75),
            wx, wy + row * wh / 4 + _px * .4, ww, wh * .22);
      }
    } else if (i == 3) {
      // Weapons/tools
      _r(canvas, Paint()..color = cLt, wx + ww * .10, wy + wh * .05, _px * 0.8, wh * .90);
      _r(canvas, Paint()..color = cLt, wx + ww * .10 - _px, wy + wh * .05, _px * 2.8, _px * 0.8);
      _r(canvas, Paint()..color = c,   wx + ww * .40, wy + wh * .15, _px * 1.4, wh * .70);
      _r(canvas, Paint()..color = c,   wx + ww * .64, wy + wh * .10, _px * 3.0, _px * 2.0);
      _r(canvas, Paint()..color = cLt, wx + ww * .64, wy + wh * .10, _px * 3.0, _px * 0.5);
      _r(canvas, Paint()..color = c,   wx + ww * .64, wy + wh * .10, _px * 3.0, wh * .62);
    } else {
      // Hanging items (5th booth — smallest)
      for (int j = 0; j < 2; j++) {
        final hx = wx + ww * (0.18 + j * 0.48);
        _r(canvas, Paint()..color = cDk, hx, wy,             _px * 0.5, wh * .32);
        _r(canvas, Paint()..color = cLt, hx - _px, wy + wh * .32, _px * 2.4, _px * 1.8);
        _r(canvas, Paint()..color = c,   hx - _px * .5, wy + wh * .32 + _px * 1.8, _px * 1.4, _px * 2.4);
      }
    }
  }

  void _jar(Canvas canvas, double cx, double cy, Color c, Color cDk) {
    _r(canvas, Paint()..color = cDk, cx - _px,        cy,          _px * 2.5, _px * 5.0);
    _r(canvas, Paint()..color = cDk, cx - _px * 1.5,  cy + _px * 1.5, _px * 3.5, _px * 3.0);
    _r(canvas, Paint()..color = c,   cx - _px * 1.5,  cy + _px * 1.5, _px * 0.5, _px * 2.0);
    _r(canvas, Paint()..color = cDk, cx - _px * 0.5,  cy - _px,    _px * 1.5,  _px * 1.5);
  }

  void _awning(Canvas canvas, double x, double y, double aw, double ah,
      Color c, Color cLt, int style) {
    if (style == 0) {
      double ry = y; int row = 0;
      while (ry < y + ah) {
        final rh = (y + ah - ry).clamp(0.0, _px * 1.6);
        _r(canvas, Paint()..color = row % 2 == 0 ? c : cLt.withValues(alpha: .62), x, ry, aw, rh);
        ry += _px * 1.6; row++;
      }
    } else if (style == 1) {
      _r(canvas, Paint()..color = c, x, y, aw, ah);
      _r(canvas, Paint()..color = cLt, x, y, aw, _px * 0.7);
      _r(canvas, Paint()..color = cLt, x, y + ah - _px * 0.7, aw, _px * 0.7);
    } else if (style == 2) {
      double ry = y; int row = 0;
      while (ry < y + ah) {
        final rh = (y + ah - ry).clamp(0.0, _px * 1.2);
        _r(canvas, Paint()..color = row % 2 == 0 ? cLt.withValues(alpha: .78) : c, x, ry, aw, rh);
        ry += _px * 1.2; row++;
      }
    } else if (style == 3) {
      _r(canvas, Paint()..color = c, x, y, aw, ah);
      for (int i = 0; i < (aw / (_px * 2.8)).floor(); i++) {
        _r(canvas, Paint()..color = cLt, x + i * _px * 2.8, y, _px * 1.1, ah);
      }
    } else {
      _r(canvas, Paint()..color = _copperDk.withValues(alpha: .78), x, y, aw, ah);
      for (int i = 0; i < (aw / (_px * 3.5)).floor(); i++) {
        _r(canvas, Paint()..color = cLt.withValues(alpha: .55), x + i * _px * 3.5, y, _px * 1.8, ah);
      }
    }
    // Fringe
    _r(canvas, Paint()..color = cLt, x, y, aw, _px * 0.65);
    final drops = (aw / (_px * 4.5)).floor();
    for (int d = 0; d < drops; d++) {
      _r(canvas, Paint()..color = c, x + d * _px * 4.5 + _px * 0.8, y + ah, _px * 1.7, _px * 2.8);
    }
  }

  // ── Temple — more depth with shadow + visible side faces ─────────────────
  void _temple(Canvas canvas, double w, double h) {
    final hot  = hovered == AcropolisZone.acropolis;
    final c    = hot ? _orange   : _copper;
    final cLt  = hot ? const Color(0xFFFFD090) : _copperLt;
    final cDk  = hot ? _copper   : _copperDk;
    final vDk  = cDk.withValues(alpha: 0.92);
    final cx   = w * 0.500;
    final baseY = h * 0.368;
    const tW   = _px * 50.0;
    const colH = _px * 20.0;
    // Deeper 3-D offset
    const dX   = _px * 9.0;
    const dY   = -_px * 5.0;

    // Drop shadow beneath temple (blurred)
    canvas.drawPath(
      Path()
        ..moveTo(cx - tW / 2 + dX, baseY + _px * 3 + dY)
        ..lineTo(cx + tW / 2 + dX * 1.4, baseY + _px * 3 + dY)
        ..lineTo(cx + tW / 2,  baseY + _px * 3)
        ..lineTo(cx - tW / 2,  baseY + _px * 3)
        ..close(),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Back (depth) step faces ──
    for (int s = 0; s < 3; s++) {
      final sw = tW + s * _px * 7;
      final sy = baseY - s * _px * 2.5;
      _r(canvas, Paint()..color = vDk, cx - sw / 2 + dX, sy + dY, sw, _px * 2.5);
    }
    final platY = baseY - _px * 7.5;
    final platW = tW - _px * 4;
    final entY  = platY - colH - _px * 4.5;
    _r(canvas, Paint()..color = vDk, cx - tW / 2 + dX, entY + dY, tW, _px * 5);

    // Rear cella wall visible through columns
    _r(canvas, Paint()..color = _wallFill.withValues(alpha: .82),
        cx - tW / 2 + dX + _px * 2, entY + _px * 5 + dY, tW - _px * 4, colH - _px * 2);

    // ── Right side face helper ──
    void sideQuad(double x, double y, double ht, Color col) {
      final path = Path()
        ..moveTo(x,    y)       ..lineTo(x + dX, y + dY)
        ..lineTo(x + dX, y + dY + ht) ..lineTo(x, y + ht) ..close();
      canvas.drawPath(path, Paint()..color = col);
    }

    // Step right faces
    for (int s = 0; s < 3; s++) {
      final sw = tW + s * _px * 7;
      final sy = baseY - s * _px * 2.5;
      sideQuad(cx + sw / 2, sy, _px * 2.5, vDk);
    }
    sideQuad(cx + tW / 2, entY, _px * 5, vDk);
    // Side of column row (right outer face)
    for (int i = 0; i < 2; i++) {
      sideQuad(cx + tW / 2 - _px * (2 + i * 5), platY - colH, colH, vDk.withValues(alpha: .60));
    }

    // ── Front steps ──
    for (int s = 0; s < 3; s++) {
      final sw = tW + s * _px * 7;
      final sy = baseY - s * _px * 2.5;
      _r(canvas, Paint()..color = s == 0 ? cLt : c, cx - sw / 2, sy, sw, _px * 2.5);
      _r(canvas, Paint()..color = cDk, cx - sw / 2, sy + _px * 2, sw, _px * 0.5);
      final tp = Path()
        ..moveTo(cx - sw / 2, sy) ..lineTo(cx - sw / 2 + dX, sy + dY)
        ..lineTo(cx + sw / 2 + dX, sy + dY) ..lineTo(cx + sw / 2, sy) ..close();
      canvas.drawPath(tp, Paint()..color = cLt.withValues(alpha: 0.55));
    }

    // Platform
    _r(canvas, Paint()..color = cLt, cx - platW / 2, platY, platW, _px * 2.5);
    canvas.drawPath(
      Path()
        ..moveTo(cx - platW / 2, platY) ..lineTo(cx - platW / 2 + dX, platY + dY)
        ..lineTo(cx + platW / 2 + dX, platY + dY) ..lineTo(cx + platW / 2, platY) ..close(),
      Paint()..color = cLt.withValues(alpha: 0.50),
    );

    // Columns (8)
    const nC = 8;
    final colArea = platW - _px * 4;
    final colSp   = colArea / (nC - 1);
    final colBase = platY - colH;
    for (int i = 0; i < nC; i++) {
      final colX = cx - colArea / 2 + i * colSp;
      // Capital top face
      canvas.drawPath(
        Path()
          ..moveTo(colX - _px * 2.5, colBase)
          ..lineTo(colX - _px * 2.5 + dX, colBase + dY)
          ..lineTo(colX + _px * 2.5 + dX, colBase + dY)
          ..lineTo(colX + _px * 2.5, colBase) ..close(),
        Paint()..color = cLt.withValues(alpha: 0.48),
      );
      // Capital
      _r(canvas, Paint()..color = cLt, colX - _px * 2.5, colBase, _px * 5, _px * 2.5);
      // Shaft with fluting
      _r(canvas, Paint()..color = c,   colX - _px * 1.5, colBase + _px * 2.5, _px * 3, colH - _px * 5);
      _r(canvas, Paint()..color = cDk, colX + _px * 0.8, colBase + _px * 2.5, _px * 0.8, colH - _px * 5);
      _r(canvas, Paint()..color = cLt.withValues(alpha: .38), colX - _px * 1.5, colBase + _px * 2.5, _px * 0.55, colH - _px * 5);
      // Column right side face
      canvas.drawPath(
        Path()
          ..moveTo(colX + _px * 1.5, colBase + _px * 2.5)
          ..lineTo(colX + _px * 1.5 + dX * .28, colBase + _px * 2.5 + dY * .28)
          ..lineTo(colX + _px * 1.5 + dX * .28, colBase + _px * 2.5 + (colH - _px * 5) + dY * .28)
          ..lineTo(colX + _px * 1.5, colBase + _px * 2.5 + (colH - _px * 5)) ..close(),
        Paint()..color = vDk.withValues(alpha: .45),
      );
      // Base
      _r(canvas, Paint()..color = cLt, colX - _px * 2.5, platY - _px * 2.5, _px * 5, _px * 2.5);
    }

    // Entablature
    _r(canvas, Paint()..color = cLt, cx - tW / 2, entY, tW, _px * 2.5);
    _r(canvas, Paint()..color = c,   cx - tW / 2, entY + _px * 2.5, tW, _px * 2.5);
    // Triglyphs
    for (int t = 0; t < 7; t++) {
      final tx = cx - tW / 2 + _px * 5 + t * (tW - _px * 10) / 6;
      _r(canvas, Paint()..color = cDk, tx,         entY + _px * 2.5, _px * 1.5, _px * 2.5);
      _r(canvas, Paint()..color = cDk, tx + _px*3, entY + _px * 2.5, _px * 1.5, _px * 2.5);
    }
    canvas.drawPath(
      Path()
        ..moveTo(cx - tW / 2, entY) ..lineTo(cx - tW / 2 + dX, entY + dY)
        ..lineTo(cx + tW / 2 + dX,  entY + dY) ..lineTo(cx + tW / 2, entY) ..close(),
      Paint()..color = cLt.withValues(alpha: 0.44),
    );
    sideQuad(cx + tW / 2, entY, _px * 5, vDk);

    // Pediment (stepped triangle)
    final pedBase = entY - _px * 0.5;
    const pedS    = 12;
    for (int i = 0; i < pedS; i++) {
      final rowW = tW * (1 - i / pedS) + _px * 2;
      _r(canvas, Paint()..color = i == 0 ? cLt : c, cx - rowW / 2, pedBase - i * _px * 1.8, rowW, _px * 2.1);
    }
    final peakY = pedBase - pedS * _px * 1.8;

    // Pediment right side face
    canvas.drawPath(
      Path()
        ..moveTo(cx + tW / 2, pedBase)
        ..lineTo(cx + tW / 2 + dX, pedBase + dY)
        ..lineTo(cx + dX, peakY + dY)
        ..lineTo(cx, peakY) ..close(),
      Paint()..color = vDk,
    );
    // Ridge
    _r(canvas, Paint()..color = cDk, cx - _px, peakY, dX + _px * 2, _px);

    // Pulsing peak star
    final ga = (0.22 + 0.42 * pulseT).clamp(0.0, 1.0);
    canvas.drawCircle(Offset(cx, peakY - _px * 7), _px * 6,
        Paint()..color = (hot ? _orange : _copper).withValues(alpha: ga)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    _star4(canvas, cx, peakY - _px * 7, hot ? _orange : cLt, _px * 2.8);
  }

  void _star4(Canvas canvas, double cx, double cy, Color c, double s) {
    final p = Paint()..color = c;
    _r(canvas, p, cx-s*.22, cy-s,    s*.44, s*2  );
    _r(canvas, p, cx-s,     cy-s*.22, s*2,   s*.44);
    _r(canvas, p, cx-s*.60, cy-s*.60, s*.30, s*.30);
    _r(canvas, p, cx+s*.30, cy-s*.60, s*.30, s*.30);
    _r(canvas, p, cx-s*.60, cy+s*.30, s*.30, s*.30);
    _r(canvas, p, cx+s*.30, cy+s*.30, s*.30, s*.30);
    _r(canvas, p, cx-s*.35, cy-s*.35, s*.70, s*.70);
  }

  void _hoverGlow(Canvas canvas, double w, double h) {
    if (hovered == null) return;
    final rect = switch (hovered!) {
      AcropolisZone.agora     => agoraRect,
      AcropolisZone.stoa      => stoaRect,
      AcropolisZone.acropolis => acropolisRect,
    };
    canvas.drawRect(rect.inflate(_px * 2), Paint()
      ..color = _orange.withValues(alpha: (0.13 + 0.18 * pulseT).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke..strokeWidth = _px * 1.8);
  }

  void _labels(Canvas canvas, double w, double h) {
    _lbl(canvas, 'AGORA',          w*.50, h*.957, _copper,   _px*2.1);
    _lbl(canvas, 'STOA',           w*.50, h*.678, _copper,   _px*2.1);
    _lbl(canvas, 'SYMPOSIUM',      w*.50, h*.118, _copperLt, _px*1.9);
    _lbl(canvas, 'A · C · R · O', w*.50, h*.022, _copper,   _px*2.3, ls: 7.0);
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
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _r(Canvas canvas, Paint paint, double x, double y, double w, double h) {
    if (w <= 0 || h <= 0) return;
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  @override
  bool shouldRepaint(_CityMapPainter old) =>
      old.pulseT != pulseT || old.flickerT != flickerT || old.hovered != hovered;
}
