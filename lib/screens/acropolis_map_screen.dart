import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../services/app_state.dart';
import '../widgets/side_menu.dart';
import '../widgets/signup_dialog.dart';
import 'agora_screen.dart';
import 'stoa_screen.dart';
import 'symposium_screen.dart';

const double _px = 2.0;

enum AcropolisZone { agora, stoa, acropolis }

const _copper   = Color(0xFFB87333);
const _copperLt = Color(0xFFD4956A);
const _copperDk = Color(0xFF7A4520);
const _orange   = Color(0xFFFF8C42);
const _gold     = Color(0xFFCA8A04);  // UI/UX Pro Max luxury gold — star highlights & moon rim
const _wallFill = Color(0xFF0F0500);
const _treeDk   = Color(0xFF3D1800);
const _treeLt   = Color(0xFF7A4520);
const _sandLt   = Color(0xFFF0DDB8);
const _sand     = Color(0xFFD4B87A);
const _sandMd   = Color(0xFFBE9A60);
const _sandDk   = Color(0xFF7A5030);

class AcropolisMapScreen extends StatefulWidget {
  const AcropolisMapScreen({super.key});
  @override
  State<AcropolisMapScreen> createState() => _AcropolisMapScreenState();
}

class _AcropolisMapScreenState extends State<AcropolisMapScreen>
    with TickerProviderStateMixin {
  AcropolisZone? _hovered;
  AcropolisZone? _tappedZone;
  bool _menuOpen = false;
  late AnimationController _pulse;
  late AnimationController _flicker;
  late AnimationController _tapFlash;
  late AnimationController _templeFade;
  late AnimationController _stoaFade;
  late AnimationController _agoraFade;
  late AnimationController _shimmer;
  late AnimationController _entrance;
  ui.Image? _templeImg;
  ui.Image? _stoaImg;
  ui.Image? _agoraImg;

  @override
  void initState() {
    super.initState();
    _pulse   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _flicker = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..repeat(reverse: true);
    _tapFlash  = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))
      ..addStatusListener((s) { if (s == AnimationStatus.completed) { _tapFlash.reset(); setState(() => _tappedZone = null); } });
    _templeFade = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _stoaFade   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _agoraFade  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _shimmer  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _loadTempleImage();
    _loadStoaImage();
    _loadAgoraImage();
    // Register the 5-minute signup prompt — fires above any active screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().registerSignupDialogCallback(() {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SignupPromptDialog(),
        );
      });
    });
  }

  Future<void> _loadTempleImage() async {
    final data = await rootBundle.load('assets/images/Sym2.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(), targetWidth: 512, targetHeight: 512);
    final frame = await codec.getNextFrame();
    if (mounted) { setState(() => _templeImg = frame.image); _templeFade.forward(); }
  }

  Future<void> _loadStoaImage() async {
    final data = await rootBundle.load('assets/images/Stoa1.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(), targetWidth: 512, targetHeight: 512);
    final frame = await codec.getNextFrame();
    if (mounted) { setState(() => _stoaImg = frame.image); _stoaFade.forward(); }
  }

  Future<void> _loadAgoraImage() async {
    final data = await rootBundle.load('assets/images/AgoraF2i.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(), targetWidth: 512, targetHeight: 512);
    final frame = await codec.getNextFrame();
    if (mounted) { setState(() => _agoraImg = frame.image); _agoraFade.forward(); }
  }

  @override
  void dispose() {
    _pulse.dispose(); _flicker.dispose();
    _tapFlash.dispose(); _templeFade.dispose(); _stoaFade.dispose(); _agoraFade.dispose();
    _shimmer.dispose(); _entrance.dispose();
    _templeImg?.dispose(); _stoaImg?.dispose(); _agoraImg?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: const SideMenu(),
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _flicker, _tapFlash, _templeFade, _stoaFade, _agoraFade, _shimmer, _entrance]),
        builder: (context, _) {
          final reducedMotion = MediaQuery.of(context).disableAnimations;
          return LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final _agoraSide    = w * 0.144;
            final agoraRect     = Rect.fromCenter(center: Offset(w * 0.30, h * 0.73), width: _agoraSide, height: _agoraSide);
            final _stoaSide     = w * 0.221;
            final stoaRect      = Rect.fromCenter(
              center: Offset(w * 0.63, h * 0.58),
              width: _stoaSide, height: _stoaSide);
            final acropolisRect = Rect.fromLTWH(w * 0.28, h * 0.04, w * 0.44, h * 0.36);
            return Stack(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
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
                      templeImg: _templeImg, stoaImg: _stoaImg, agoraImg: _agoraImg,
                      templeAlpha: _templeFade.value, stoaAlpha: _stoaFade.value, agoraAlpha: _agoraFade.value,
                      tapFlashT: _tapFlash.value, tappedZone: _tappedZone,
                      shimmerT: _shimmer.value, entranceT: _entrance.value,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ),
              ),
              Positioned(top: 6, right: 60, child: const SideMenuButton()),
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
            Text('MENU', style: GoogleFonts.spaceMono(fontSize: 11,
                color: _copper, letterSpacing: 2.5, fontWeight: FontWeight.bold)),
            const SizedBox(width: 7),
            Text(_menuOpen ? '▲' : '▼', style: GoogleFonts.spaceMono(color: _copper, fontSize: 9)),
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
        child: Text(label, style: GoogleFonts.spaceMono(
            fontSize: 11, color: _copperLt, letterSpacing: 1.5))),
  );
  Widget _md() => Container(height: 1, color: const Color(0x40B87333));

  void _handleTap(Offset pos, Rect agora, Rect stoa, Rect acropolis) {
    AcropolisZone? zone;
    if (agora.contains(pos))     zone = AcropolisZone.agora;
    else if (stoa.contains(pos)) zone = AcropolisZone.stoa;
    else if (acropolis.contains(pos)) zone = AcropolisZone.acropolis;
    if (zone != null) { setState(() => _tappedZone = zone); _tapFlash.forward(from: 0); }
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
  final ui.Image? templeImg;
  final ui.Image? stoaImg;
  final ui.Image? agoraImg;
  final double templeAlpha, stoaAlpha, agoraAlpha;
  final double tapFlashT;
  final AcropolisZone? tappedZone;
  final double shimmerT;
  final double entranceT;
  final bool reducedMotion;

  _CityMapPainter({required this.pulseT, required this.flickerT,
      required this.hovered, required this.agoraRect,
      required this.stoaRect, required this.acropolisRect,
      this.templeImg, this.stoaImg, this.agoraImg,
      this.templeAlpha = 1.0, this.stoaAlpha = 1.0, this.agoraAlpha = 1.0,
      this.tapFlashT = 0.0, this.tappedZone,
      this.shimmerT = 0.0, this.entranceT = 1.0,
      this.reducedMotion = false});

  // Eased alpha for staggered entrance — start 0→1 over a 0.22-wide window
  double _eAlpha(double start) =>
    Curves.easeOut.transform(((entranceT - start) / 0.22).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.black);
    _groundPlane(canvas, w, h);
    _sky(canvas, w, h);

    _stars(canvas, w, h);
    _moon(canvas, w, h);
    _terrain(canvas, w, h);
    _atmosphericHaze(canvas, w, h);

    if (agoraImg != null) _drawAgoraImage(canvas, w, h, agoraImg!);
    if (stoaImg != null) {
      _drawStoaImage(canvas, w, h, stoaImg!);
    } else {
      _market(canvas, w, h);
    }
    if (templeImg != null) {
      _drawTempleImage(canvas, w, h, templeImg!);
    } else {
      _temple(canvas, w, h);
    }
    _hoverGlow(canvas, w, h);
    _labels(canvas, w, h);
  }

  // ── Asymmetric wall — left is more angular/concave, right more convex ────
  Path _wallPath(double w, double h) {
    final p = Path();
    p.moveTo(w * 0.448, h * 0.902);
    // Bottom-left — wide natural sweep
    p.quadraticBezierTo(w * 0.2218, h * 0.895, w * 0.245, h * 0.854);
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

  // ── Warm ground plane — separates city floor from pure-black void ─────────
  void _groundPlane(Canvas canvas, double w, double h) {
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.72, w, h * 0.28),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, h), Offset(0, h * 0.72),
        const [Color(0xFF0A0500), Color(0x000A0500)],
      ),
    );
  }

  // ── Atmospheric perspective — cool haze recedes distant temple, ───────────
  // ── warm closeness pulls the agora zone forward ───────────────────────────
  void _atmosphericHaze(Canvas canvas, double w, double h) {
    // Cool/dark haze over the upper city (temple is far away/high up)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.42),
      Paint()..shader = ui.Gradient.linear(
        Offset(w / 2, 0), Offset(w / 2, h * 0.42),
        const [Color(0x1A04020E), Color(0x00000000)],
      ),
    );
    // Faint warm bloom over lower city (agora feels closer/warmer)
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.30),
      Paint()..shader = ui.Gradient.linear(
        Offset(w / 2, h * 0.92), Offset(w / 2, h * 0.62),
        const [Color(0x0E120600), Color(0x00000000)],
      ),
    );
  }

  // ── Sky gradient + curvy horizon just above treeline ─────────────────────
  void _sky(Canvas canvas, double w, double h) {
    // Horizon curve sits just above the tallest trees (~h*0.66).
    // Wavy, organic — rises and dips gently left to right.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.705);
    // Horizon wave: right edge → sweeps left with gentle undulation
    path.quadraticBezierTo(w * 0.82, h * 0.652, w * 0.62, h * 0.662);
    path.quadraticBezierTo(w * 0.42, h * 0.672, w * 0.22, h * 0.648);
    path.quadraticBezierTo(w * 0.08, h * 0.634, 0, h * 0.668);
    path.close();

    // Pitch black at top → very subtle twilight near horizon. Mostly black.
    canvas.drawPath(path, Paint()
      ..shader = ui.Gradient.linear(
        Offset(w / 2, 0),
        Offset(w / 2, h * 0.690),
        const [
          Color(0xFF000000),   // pitch black
          Color(0xFF000000),   // pitch black — hold longer
          Color(0xFF020208),   // barely-there dark blue-black
          Color(0xFF060412),   // very dark, faint hint of indigo
          Color(0xFF0A0618),   // softest twilight, almost black
        ],
        [0.0, 0.40, 0.65, 0.85, 1.0],
      ));

    // Feathered horizon — soft black blur band to dissolve the hard edge
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.610, w, h * 0.090),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.610), Offset(0, h * 0.700),
          const [Color(0x00000000), Color(0xFF000000)],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  // ── Stars — top 32%, staggered twinkle ───────────────────────────────────
  void _stars(Canvas canvas, double w, double h) {
    final starEntrance = _eAlpha(0.14);
    if (starEntrance == 0) return;
    final rng = math.Random(42);
    for (int i = 0; i < 45; i++) {  // 45 stars — OLED-optimised (was 68)
      final x     = rng.nextDouble() * w;
      final y     = rng.nextDouble() * h * 0.32;
      final phase = rng.nextDouble();
      final speed = 2.0 + rng.nextDouble() * 4.0;
      final sz    = 0.5 + rng.nextDouble() * 1.3;
      // reducedMotion: static brightness, no flicker
      final flick = reducedMotion ? 0.0 : math.sin(flickerT * math.pi * speed + phase * math.pi * 2);
      final alpha = ((0.22 + 0.50 * ((flick + 1) / 2)) * starEntrance).clamp(0.0, 0.72);

      if (rng.nextDouble() > 0.58) {
        final ca = _copper.withValues(alpha: alpha * 0.82);
        _r(canvas, Paint()..color = ca, x - sz*0.28, y - sz*1.5, sz*0.56, sz*3.0);
        _r(canvas, Paint()..color = ca, x - sz*1.5,  y - sz*0.28, sz*3.0,  sz*0.56);
        // Gold centre pixel — richer than plain copperLt
        _r(canvas, Paint()..color = _gold.withValues(alpha: alpha),
            x - sz*0.18, y - sz*0.18, sz*0.36, sz*0.36);
      } else {
        canvas.drawRect(Rect.fromLTWH(x - sz/2, y - sz/2, sz, sz),
            Paint()..color = _copper.withValues(alpha: alpha));
      }
    }
  }

  // ── Smooth crescent moon ──────────────────────────────────────────────────
  void _moon(Canvas canvas, double w, double h) {
    final moonEntrance = _eAlpha(0.28);
    if (moonEntrance == 0) return;
    final cx = w * 0.50;
    final cy = h * 0.10;
    const r  = _px * 7.8;
    canvas.saveLayer(Rect.fromCircle(center: Offset(cx, cy), radius: r * 3),
        Paint()..color = Color.fromRGBO(255, 255, 255, moonEntrance));

    // Soft pulsing ambient glow — static when reducedMotion
    final moonGlow = reducedMotion ? 0.028 : 0.022 + 0.014 * pulseT;
    canvas.drawCircle(Offset(cx, cy), r * 1.9,
      Paint()
        ..color = _gold.withValues(alpha: moonGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Tilt counter-clockwise ~38° so the crescent leans to the left
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.66);
    final outer = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    final inner = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(r * 0.36, 0), radius: r * 0.80));
    final crescent = Path.combine(PathOperation.difference, outer, inner);

    canvas.drawPath(crescent,
        Paint()..color = _copper.withValues(alpha: 0.92));
    canvas.drawPath(crescent,
        Paint()
          ..color = _gold.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _px * 0.55
          ..strokeCap = StrokeCap.round);
    canvas.restore(); // crescent rotation
    canvas.restore(); // entrance layer
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

  // ── Shimmer sweep placeholder shown while an image loads ─────────────────
  void _shimmerPlaceholder(Canvas canvas, Rect dest, double intensity) {
    // Dim base glow
    canvas.drawCircle(dest.center, dest.width * 0.30,
      Paint()
        ..color = _copperDk.withValues(alpha: 0.18 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    // Sweeping highlight — travels left to right across the placeholder
    final sweep = dest.left - dest.width * 0.3 + dest.width * 1.6 * shimmerT;
    canvas.save();
    canvas.clipRect(dest.inflate(dest.width * 0.12));
    canvas.drawRect(
      Rect.fromLTWH(sweep - dest.width * 0.22, dest.top, dest.width * 0.44, dest.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(sweep - dest.width * 0.22, 0), Offset(sweep + dest.width * 0.22, 0),
          [Colors.transparent, _copper.withValues(alpha: 0.28 * intensity), Colors.transparent],
        ),
    );
    canvas.restore();
  }

  // ── Greek market compound image ───────────────────────────────────────────
  void _drawStoaImage(Canvas canvas, double w, double h, ui.Image img) {
    final side = w * 0.221;
    final dest = Rect.fromCenter(
      center: Offset(w * 0.63, h * 0.58), width: side, height: side);
    final src  = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    // Shimmer placeholder while loading
    if (stoaAlpha < 1.0) _shimmerPlaceholder(canvas, dest, 1 - stoaAlpha);
    canvas.saveLayer(dest, Paint()..color = Color.fromRGBO(255, 255, 255, stoaAlpha));
    canvas.drawImageRect(img, src, dest,
        Paint()..blendMode = BlendMode.screen..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  // ── Agora image icon ─────────────────────────────────────────────────────
  void _drawAgoraImage(Canvas canvas, double w, double h, ui.Image img) {
    final side = w * 0.144;
    final dest = Rect.fromCenter(
      center: Offset(w * 0.30, h * 0.73), width: side, height: side);
    final src  = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    if (agoraAlpha < 1.0) _shimmerPlaceholder(canvas, dest, 1 - agoraAlpha);
    canvas.saveLayer(dest, Paint()..color = Color.fromRGBO(255, 255, 255, agoraAlpha));
    canvas.drawImageRect(img, src, dest,
        Paint()..blendMode = BlendMode.screen..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  // ── Stoa — 5 mini Greek temples, spread wide ─────────────────────────────
  void _market(Canvas canvas, double w, double h) {
    final hot = hovered == AcropolisZone.stoa;
    final c   = hot ? _orange              : _sand;
    final cLt = hot ? const Color(0xFFFFD090) : _sandLt;
    final cDk = hot ? _copper              : _sandDk;
    final cMd = hot ? _copperLt            : _sandMd;

    const positions = [
      [0.238, 0.648],  // far left — low
      [0.352, 0.538],  // left-centre — high
      [0.500, 0.612],  // centre — mid
      [0.650, 0.552],  // right-centre — high
      [0.775, 0.638],  // far right — low
    ];
    for (final p in positions) {
      _miniTemple(canvas, p[0] * w, p[1] * h, c, cLt, cDk, cMd);
    }
  }

  void _miniTemple(Canvas canvas, double cx, double baseY,
      Color c, Color cLt, Color cDk, Color cMd) {
    const tw    = _px * 22.0;  // face width at top step
    const colH  = _px * 14.0;  // column height
    const nCols = 4;

    // ── 3 steps — widest at bottom ────────────────────────────────────────
    for (int s = 0; s < 3; s++) {
      final sw = tw + (2 - s) * _px * 4.5;
      final sy = baseY - (s + 1) * _px * 2.5;
      _r(canvas, Paint()..color = s == 0 ? c : cLt, cx - sw / 2, sy, sw, _px * 2.5);
      _r(canvas, Paint()..color = cDk, cx - sw / 2, sy + _px * 2.0, sw, _px * 0.5);
    }

    // ── Stylobate (platform) ───────────────────────────────────────────────
    final platTop = baseY - _px * 7.5;
    _r(canvas, Paint()..color = cLt, cx - tw / 2, platTop - _px * 2.0, tw, _px * 2.0);
    _r(canvas, Paint()..color = cDk.withValues(alpha: 0.38),
        cx - tw / 2, platTop - _px * 0.5, tw, _px * 0.5);

    // ── Dark interior void behind columns ──────────────────────────────────
    final colBase = platTop - _px * 2.0;
    final colTop  = colBase - colH;
    _r(canvas, Paint()..color = _wallFill.withValues(alpha: 0.90),
        cx - tw / 2 + _px * 1.8, colTop, tw - _px * 3.6, colH + _px * 2.0);

    // ── Columns ────────────────────────────────────────────────────────────
    final colArea = tw - _px * 4.0;
    final colSp   = colArea / (nCols - 1);
    for (int i = 0; i < nCols; i++) {
      final colX = cx - colArea / 2 + i * colSp;
      // Abacus (flat cap slab)
      _r(canvas, Paint()..color = cLt, colX - _px * 2.2, colTop, _px * 4.4, _px * 1.4);
      // Echinus (curved cap — faked with a narrower layer)
      _r(canvas, Paint()..color = cMd, colX - _px * 1.8, colTop + _px * 1.0, _px * 3.6, _px * 1.0);
      // Shaft
      _r(canvas, Paint()..color = c, colX - _px * 1.4, colTop + _px * 2.0, _px * 2.8, colH - _px * 4.5);
      // Flute shadow
      _r(canvas, Paint()..color = cDk.withValues(alpha: 0.40),
          colX + _px * 0.5, colTop + _px * 2.0, _px * 0.5, colH - _px * 4.5);
      // Highlight
      _r(canvas, Paint()..color = cLt.withValues(alpha: 0.30),
          colX - _px * 1.4, colTop + _px * 2.0, _px * 0.45, colH - _px * 4.5);
      // Column base
      _r(canvas, Paint()..color = cLt, colX - _px * 2.0, colBase - _px * 2.0, _px * 4.0, _px * 2.0);
    }

    // ── Entablature ────────────────────────────────────────────────────────
    final entY = colTop - _px * 5.0;
    // Architrave
    _r(canvas, Paint()..color = c,   cx - tw / 2, entY + _px * 2.5, tw, _px * 2.5);
    _r(canvas, Paint()..color = cLt, cx - tw / 2, entY + _px * 2.5, tw, _px * 0.6);
    // Frieze
    _r(canvas, Paint()..color = cMd, cx - tw / 2, entY, tw, _px * 2.5);
    // Triglyphs (3 pairs of slots)
    for (int t = 0; t < 3; t++) {
      final tx = cx - tw / 2 + _px * 2.5 + t * (tw - _px * 5.0) / 2 - _px * 0.9;
      _r(canvas, Paint()..color = cDk, tx,           entY + _px * 0.3, _px * 0.8, _px * 2.2);
      _r(canvas, Paint()..color = cDk, tx + _px * 1.5, entY + _px * 0.3, _px * 0.8, _px * 2.2);
    }
    // Cornice
    _r(canvas, Paint()..color = cLt, cx - tw / 2 - _px * 0.5, entY - _px * 0.5, tw + _px, _px * 1.0);

    // ── Pediment ──────────────────────────────────────────────────────────
    const pedRows = 7;
    final pedBaseY = entY - _px * 0.5;
    for (int i = 0; i < pedRows; i++) {
      final rowW = (tw + _px) * (1.0 - i / pedRows) + _px;
      _r(canvas, Paint()..color = i == 0 ? cLt : c,
          cx - rowW / 2, pedBaseY - i * _px * 1.6, rowW, _px * 1.9);
    }
    // Acroterion at peak
    final peakY = pedBaseY - pedRows * _px * 1.6;
    _r(canvas, Paint()..color = cLt, cx - _px * 1.0, peakY - _px * 2.5, _px * 2.0, _px * 2.5);
    _r(canvas, Paint()..color = cLt, cx - _px * 1.8, peakY - _px * 3.5, _px * 3.6, _px * 1.0);
  }

  // ── Sym1 image replacing the drawn temple ────────────────────────────────
  void _drawTempleImage(Canvas canvas, double w, double h, ui.Image img) {
    final side = math.min(w * 0.504, h * 0.432);
    final cx   = w * 0.500;
    final topY = h * 0.03;
    final dest = Rect.fromLTWH(cx - side / 2, topY, side, side);
    final src  = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    if (templeAlpha < 1.0) _shimmerPlaceholder(canvas, dest, 1 - templeAlpha);
    canvas.saveLayer(dest, Paint()..color = Color.fromRGBO(255, 255, 255, templeAlpha));
    canvas.drawImageRect(img, src, dest,
        Paint()..blendMode = BlendMode.screen..filterQuality = FilterQuality.medium);
    canvas.restore();
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
    final zone = tappedZone ?? hovered;
    if (zone == null) return;
    final rect = switch (zone) {
      AcropolisZone.agora     => agoraRect,
      AcropolisZone.stoa      => stoaRect,
      AcropolisZone.acropolis => acropolisRect,
    };
    // Ease the pulse — static when reducedMotion
    final eased = reducedMotion ? 0.5 : Curves.easeInOut.transform(pulseT);
    canvas.drawCircle(rect.center, rect.shortestSide * 0.60,
      Paint()
        ..color = _orange.withValues(alpha: (0.05 + 0.15 * eased).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34));
    // Tap burst — sharp bright flash that fades quickly
    if (tapFlashT > 0) {
      final burst = (tapFlashT * (1 - tapFlashT) * 4.0 * 0.65).clamp(0.0, 1.0);
      canvas.drawCircle(rect.center, rect.shortestSide * 0.80,
        Paint()
          ..color = _orange.withValues(alpha: burst)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42));
    }
  }

  void _labels(Canvas canvas, double w, double h) {
    final labelEntrance = _eAlpha(0.62);
    if (labelEntrance == 0) return;
    final aHot = hovered == AcropolisZone.agora     || tappedZone == AcropolisZone.agora;
    final sHot = hovered == AcropolisZone.stoa      || tappedZone == AcropolisZone.stoa;
    final tHot = hovered == AcropolisZone.acropolis || tappedZone == AcropolisZone.acropolis;
    // Use _copperLt as default (8.7:1 contrast vs black — WCAG AA+)
    _lbl(canvas, 'AGORA',          w*.300, h*.800, aHot ? _orange : _copperLt, _px*2.1, op: labelEntrance);
    _lbl(canvas, 'STOA',           w*.630, h*.665, sHot ? _orange : _copperLt, _px*2.1, op: labelEntrance);
    _lbl(canvas, 'SYMPOSIUM',      w*.500, h*.118, tHot ? _orange : _copperLt, _px*1.9, op: labelEntrance);
    _lbl(canvas, 'A · C · R · O', w*.500, h*.022, _copperLt,                   _px*2.3, ls: 7.0, op: labelEntrance);
  }

  void _lbl(Canvas canvas, String text, double cx, double cy,
      Color color, double fs, {double ls = 2.0, double op = 1.0}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: GoogleFonts.spaceMono(
          fontSize: fs, fontWeight: FontWeight.bold,
          color: color.withValues(alpha: op),
          letterSpacing: ls,
          shadows: const [Shadow(color: Colors.black, blurRadius: 5)])),
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
      old.pulseT != pulseT || old.flickerT != flickerT ||
      old.hovered != hovered || old.tappedZone != tappedZone ||
      old.tapFlashT != tapFlashT ||
      old.templeImg != templeImg || old.stoaImg != stoaImg || old.agoraImg != agoraImg ||
      old.templeAlpha != templeAlpha || old.stoaAlpha != stoaAlpha || old.agoraAlpha != agoraAlpha ||
      old.shimmerT != shimmerT || old.entranceT != entranceT ||
      old.reducedMotion != reducedMotion;
}
