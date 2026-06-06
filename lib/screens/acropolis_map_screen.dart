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

// ── Agora-road palette ────────────────────────────────────────────────────────
const _marble   = Color(0xFFF4E8CC);
const _marbleHi = Color(0xFFFCF0D8);
const _terra    = Color(0xFFB66C4A);
const _terraHi  = Color(0xFFD99B7A);
const _stone    = Color(0xFFA48A60);
const _stoneDk  = Color(0xFF5E462C);
const _earthDk  = Color(0xFF4A3320);
const _earthBg  = Color(0xFF6F5034);
const _ink      = Color(0xFF3A2A1C);
const _gold     = Color(0xFFCC9C54);

enum AcropolisZone { agora, stoa, acropolis }

// ── Screen ────────────────────────────────────────────────────────────────────
class AcropolisMapScreen extends StatefulWidget {
  const AcropolisMapScreen({super.key});
  @override
  State<AcropolisMapScreen> createState() => _AcropolisMapScreenState();
}

class _AcropolisMapScreenState extends State<AcropolisMapScreen>
    with TickerProviderStateMixin {

  AcropolisZone? _hovered;
  AcropolisZone? _tappedZone;

  late AnimationController _pulse;
  late AnimationController _tapFlash;
  late AnimationController _entrance;
  late AnimationController _artSpring;
  double _mobileDragY   = 0.0;
  double _artSpringFrom = 0.0;

  // Parallax (normalised −1..1)
  double _nX = 0.0;
  double _nY = 0.0;

  // Sprites
  ui.Image? _templeImg;
  ui.Image? _stoaImg;
  ui.Image? _agoraImg;
  ui.Image? _earthTile;
  ui.Image? _roadTile;
  ui.Image? _cypress;
  ui.Image? _statue;
  ui.Image? _brokenCol;
  ui.Image? _olive;
  ui.Image? _amphora;
  ui.Image? _brazier;
  ui.Image? _roadVertImg;
  ui.Image? _flowerBushImg;
  ui.Image? _hermImg;

  @override
  void initState() {
    super.initState();
    _pulse    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _tapFlash = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _tapFlash.reset();
          if (mounted) setState(() => _tappedZone = null);
        }
      });
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _artSpring = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..addListener(() {
        final t = Curves.easeOut.transform(_artSpring.value);
        if (mounted) setState(() => _mobileDragY = _artSpringFrom * (1.0 - t));
      });
    _loadImages();
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

  Future<void> _loadImages() async {
    await Future.wait([
      _loadImg('assets/images/Sym2.png',          512, (v) => _templeImg  = v),
      _loadImg('assets/images/Stoa1.png',         512, (v) => _stoaImg    = v),
      _loadImg('assets/images/AgoraF2i.png',      512, (v) => _agoraImg   = v),
      _loadImg('assets/images/earth_tile.png',    256, (v) => _earthTile  = v),
      _loadImg('assets/images/road_tile.png',     256, (v) => _roadTile   = v),
      _loadImg('assets/images/cypress.png',       256, (v) => _cypress    = v),
      _loadImg('assets/images/statue.png',        256, (v) => _statue     = v),
      _loadImg('assets/images/broken_column.png', 256, (v) => _brokenCol  = v),
      _loadImg('assets/images/olive_bush.png',    256, (v) => _olive      = v),
      _loadImg('assets/images/amphora.png',       256, (v) => _amphora    = v),
      _loadImg('assets/images/brazier.png',        256,  (v) => _brazier      = v),
      _loadImg('assets/images/road_vertical.png', 1024, (v) => _roadVertImg  = v),
      _loadImg('assets/images/flower_bush.png',   256,  (v) => _flowerBushImg = v),
      _loadImg('assets/images/herm.png',          256,  (v) => _hermImg      = v),
    ]);
  }

  Future<void> _loadImg(String path, int maxPx, void Function(ui.Image) set) async {
    try {
      final data  = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(), targetWidth: maxPx);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => set(frame.image));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulse.dispose(); _tapFlash.dispose(); _entrance.dispose(); _artSpring.dispose();
    for (final img in [
      _templeImg, _stoaImg, _agoraImg, _earthTile, _roadTile,
      _cypress, _statue, _brokenCol, _olive, _amphora, _brazier,
      _roadVertImg, _flowerBushImg, _hermImg,
    ]) { img?.dispose(); }
    super.dispose();
  }

  // ── Hit testing ───────────────────────────────────────────────────────────
  Rect _imgRect(double w, double h, double xF, double baseF, double wF) {
    final bw = (w * wF).clamp(80.0, 280.0);
    return Rect.fromLTWH(w * xF - bw / 2, h * baseF - bw, bw, bw);
  }

  AcropolisZone? _zoneAt(Offset p, double w, double h) {
    final mob = w < 600;
    if (_imgRect(w, h, 0.19, 0.58, mob ? 0.25  : 0.196).inflate(12).contains(p)) return AcropolisZone.agora;
    if (_imgRect(w, h, 0.50, 0.57, mob ? 0.29  : 0.23 ).inflate(12).contains(p)) return AcropolisZone.stoa;
    if (_imgRect(w, h, 0.81, 0.59, mob ? 0.24  : 0.22 ).inflate(12).contains(p)) return AcropolisZone.acropolis;
    return null;
  }

  void _tapZone(AcropolisZone zone) {
    setState(() => _tappedZone = zone);
    _tapFlash.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _tappedZone = null);
      switch (zone) {
        case AcropolisZone.agora:
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgoraScreen()));
        case AcropolisZone.stoa:
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoaScreen()));
        case AcropolisZone.acropolis:
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SymposiumScreen()));
      }
    });
  }

  void _onTap(Offset pos, double w, double h) {
    final zone = _zoneAt(pos, w, h);
    if (zone == null) return;
    _tapZone(zone);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _earthBg,
      endDrawer: const SideMenu(),
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _tapFlash, _entrance, _artSpring]),
        builder: (_, __) => LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final isMobile = w < 600;
          final roadY = h * 0.56;
          final bandH = isMobile
              ? (h * 0.20).clamp(110.0, 170.0)
              : (h * 0.27).clamp(150.0, 320.0);
          final entT  = _entrance.value;

          if (isMobile) return _buildMobileVertical(w, h, entT);

          return MouseRegion(
            cursor:  _hovered != null ? SystemMouseCursors.click : MouseCursor.defer,
            onHover: (e) {
              final nx = (e.localPosition.dx / w - 0.5) * 2;
              final ny = (e.localPosition.dy / h - 0.5) * 2;
              final zone = _zoneAt(e.localPosition, w, h);
              if (nx != _nX || ny != _nY || zone != _hovered) {
                setState(() { _nX = nx; _nY = ny; _hovered = zone; });
              }
            },
            onExit: (_) => setState(() { _hovered = null; _nX = 0; _nY = 0; }),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _onTap(d.localPosition, w, h),
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                // ① Earth tiles + road band
                CustomPaint(
                  size: Size(w, h),
                  painter: _BgPainter(
                    earthTile: _earthTile, roadTile: _roadTile,
                    roadY: roadY, bandH: bandH, isMobile: isMobile,
                  ),
                ),
                // ② Warm sun haze
                Positioned.fill(child: CustomPaint(painter: _HazePainter())),
                // ③ Back scenery (parallax layer 1)
                Transform.translate(
                  offset: Offset(_nX * 6, _nY * 4),
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _SceneryPainter(
                      w: w, h: h, isMobile: isMobile, front: false,
                      cypress: _cypress, statue: _statue,
                      brokenCol: _brokenCol, olive: _olive,
                    ),
                  ),
                ),
                // ④ Building stops
                ..._buildStops(w, h, entT, isMobile),
                // ⑤ Front scenery (parallax layer 2, counter-direction for depth)
                Transform.translate(
                  offset: Offset(_nX * -14, _nY * -8),
                  child: CustomPaint(
                    size: Size(w, h),
                    painter: _SceneryPainter(
                      w: w, h: h, isMobile: isMobile, front: true,
                      amphora: _amphora, olive: _olive, brazier: _brazier,
                    ),
                  ),
                ),
                // ⑥ Vignette
                Positioned.fill(child: CustomPaint(painter: _VignettePainter())),
                // ⑦ Title block
                Positioned(
                  top: 0, left: 44, right: 44,
                  child: _Header(alpha: Curves.easeOut.transform(entT)),
                ),
                // ⑧ Hint
                Positioned(
                  bottom: 20, left: 0, right: 0,
                  child: Opacity(
                    opacity: Curves.easeOut.transform(entT),
                    child: Text(
                      'TAP A BUILDING TO START',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.pixelifySans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE9D6AC).withValues(alpha: 0.85),
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ),
                // ⑨ Side-menu
                Positioned(top: 6, right: 16, child: const SideMenuButton()),
              ]),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildStops(double w, double h, double entT, bool isMobile) {
    final data = [
      (
        zone: AcropolisZone.agora,
        xF: 0.19, baseF: 0.58,
        wF:   isMobile ? 0.25  : 0.196,
        minW: isMobile ? 82.0  : 78.0,
        maxW: isMobile ? 122.0 : 238.0,
        title: 'THE AGORA', sub: 'Browse',
        img: _agoraImg, delay: 0.0,
      ),
      (
        zone: AcropolisZone.stoa,
        xF: 0.50, baseF: 0.57,
        wF:   isMobile ? 0.29  : 0.23,
        minW: isMobile ? 96.0  : 99.0,
        maxW: isMobile ? 140.0 : 288.0,
        title: 'THE STOA', sub: 'Forum',
        img: _stoaImg, delay: 0.18,
      ),
      (
        zone: AcropolisZone.acropolis,
        xF: 0.81, baseF: 0.59,
        wF:   isMobile ? 0.24  : 0.22,
        minW: isMobile ? 82.0  : 92.0,
        maxW: isMobile ? 122.0 : 280.0,
        title: 'SYMPOSIUM', sub: 'The Assembly',
        img: _templeImg, delay: 0.36,
      ),
    ];

    return data.map((s) {
      final bw  = (w * s.wF).clamp(s.minW, s.maxW);
      final cx  = w * s.xF;
      // +12: sinks base 12px into the road (matches template's calc(-100% + 12px))
      final top = h * s.baseF - bw + 12;
      final hot = _hovered == s.zone || _tappedZone == s.zone;
      final a   = Curves.easeOut.transform(
          ((entT - s.delay) / 0.40).clamp(0.0, 1.0));

      return Positioned(
        left: cx - bw / 2, top: top, width: bw,
        child: Opacity(
          opacity: a,
          child: _Stop(
            title: s.title, sub: s.sub,
            img: s.img, bw: bw,
            hot: hot, pulseT: _pulse.value,
          ),
        ),
      );
    }).toList();
  }

  // ── Mobile vertical layout — winding road + absolute building positions ──────
  Widget _buildMobileVertical(double w, double h, double entT) {
    final alpha = Curves.easeOut.transform(entT);

    // contentMidFrac = vertical centre of visible art as fraction of image height
    // (measured from alpha bounds: Sym 20–94.7%, Stoa 34.4–85.4%, Agora 28.7–83.7%)
    // top = h*yF - contentMidFrac*bw  →  visible art centred on plaza circle
    final stops = [
      (zone: AcropolisZone.acropolis, title: 'SYMPOSIUM', sub: 'The Assembly',
       img: _templeImg, xF: 0.45, yF: 0.22, bwF: 0.35, bwMin: 124.0, bwMax: 208.0, mid: 0.574, delay: 0.28),
      (zone: AcropolisZone.stoa,      title: 'THE STOA',  sub: 'Forum',
       img: _stoaImg,   xF: 0.63, yF: 0.52, bwF: 0.44, bwMin: 156.0, bwMax: 260.0, mid: 0.599, delay: 0.14),
      (zone: AcropolisZone.agora,     title: 'THE AGORA', sub: 'Browse',
       img: _agoraImg,  xF: 0.40, yF: 0.82, bwF: 0.42, bwMin: 150.0, bwMax: 250.0, mid: 0.562, delay: 0.0),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) {
        _artSpring.stop();
        setState(() =>
            _mobileDragY = (_mobileDragY + d.delta.dy * 0.45).clamp(-65.0, 65.0));
      },
      onVerticalDragEnd: (_) {
        _artSpringFrom = _mobileDragY;
        _artSpring.forward(from: 0);
      },
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        // ① Earth tile base
        IgnorePointer(
          child: CustomPaint(
            size: Size(w, h),
            painter: _BgPainter(
              earthTile: _earthTile, roadTile: null,
              roadY: 0, bandH: 0, isMobile: true, showRoad: false,
            ),
          ),
        ),
        // ② Warm haze
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _HazePainter())),
        ),
        // ③ Winding road — road_vertical.png fills viewport (background-size:100% 100%)
        if (_roadVertImg != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RawImage(
                image: _roadVertImg!,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        // ④ Back scenery — parallax drifts same direction as drag
        Transform.translate(
          offset: Offset(0, _mobileDragY * 0.3),
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(w, h),
              painter: _MobileSceneryPainter(
                w: w, h: h, front: false,
                cypress: _cypress, statue: _statue,
                flowerBush: _flowerBushImg, herm: _hermImg,
                amphora: _amphora, olive: _olive,
              ),
            ),
          ),
        ),
        // ⑤ Buildings — absolutely positioned, back-to-front (Stoa → Sym → Agora)
        ...stops.map((s) {
          final bw  = (w * s.bwF).clamp(s.bwMin, s.bwMax);
          final a   = Curves.easeOut.transform(
              ((entT - s.delay) / 0.40).clamp(0.0, 1.0));
          final hot = _tappedZone == s.zone;
          return Positioned(
            left:  w * s.xF - bw / 2,
            top:   h * s.yF - s.mid * bw,
            width: bw,
            child: Opacity(
              opacity: a,
              child: Transform.translate(
                offset: Offset(0, (1.0 - a) * 16),
                child: GestureDetector(
                  onTap: () => _tapZone(s.zone),
                  onTapDown: (_) => setState(() => _tappedZone = s.zone),
                  onTapCancel: () => setState(() {
                    if (_tappedZone == s.zone) _tappedZone = null;
                  }),
                  child: AnimatedSlide(
                    // whole card sinks down on press (matches CSS :active)
                    offset: Offset(0, hot ? 0.025 : 0),
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedSlide(
                          // art lifts slightly against the press
                          offset: Offset(0, hot ? -0.05 : 0),
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          child: ColorFiltered(
                            colorFilter: hot
                                ? const ColorFilter.matrix(<double>[
                                    1.06, 0, 0, 0, 0,
                                    0, 1.06, 0, 0, 0,
                                    0, 0, 1.06, 0, 0,
                                    0, 0, 0, 1,    0,
                                  ])
                                : const ColorFilter.matrix(<double>[
                                    1, 0, 0, 0, 0,
                                    0, 1, 0, 0, 0,
                                    0, 0, 1, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                            child: s.img != null
                                ? RawImage(
                                    image: s.img,
                                    width: bw,
                                    filterQuality: FilterQuality.none,
                                    fit: BoxFit.contain,
                                  )
                                : SizedBox(width: bw, height: bw * 0.8),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFCF0D8), Color(0xFFECDAB0)],
                            ),
                            border: Border.all(
                                color: const Color(0xFF5E462C), width: 2),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0xFF5E462C),
                                  offset: Offset(0, 3)),
                              BoxShadow(
                                  color: Color(0x593A2A1C),
                                  offset: Offset(0, 5),
                                  blurRadius: 9),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.pixelifySans(
                                  fontSize: (bw * 0.09).clamp(11.0, 15.0),
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                s.sub,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.pixelifySans(
                                  fontSize: (bw * 0.07).clamp(8.0, 11.0),
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF7A5A3A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        // ⑥ Front scenery — parallax drifts counter to drag
        Transform.translate(
          offset: Offset(0, _mobileDragY * -0.5),
          child: IgnorePointer(
            child: CustomPaint(
              size: Size(w, h),
              painter: _MobileSceneryPainter(
                w: w, h: h, front: true,
                cypress: _cypress, statue: _statue,
                flowerBush: _flowerBushImg, herm: _hermImg,
                amphora: _amphora, olive: _olive,
              ),
            ),
          ),
        ),
        // ⑦ Vignette
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _VignettePainter())),
        ),
        // ⑧ Header
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Opacity(
              opacity: alpha,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Header(alpha: 1.0),
              ),
            ),
          ),
        ),
        // ⑨ Pulsing hint
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Opacity(
              opacity: (0.5 + 0.45 * _pulse.value) * alpha,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'TAP A BUILDING TO START',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.pixelifySans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE9D6AC),
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ),
        ),
        // ⑩ Side menu
        Positioned(top: 6, right: 16, child: const SideMenuButton()),
      ]),
    );
  }
}

// ── Building stop ─────────────────────────────────────────────────────────────
class _Stop extends StatelessWidget {
  final String title, sub;
  final ui.Image? img;
  final double bw, pulseT;
  final bool hot;

  const _Stop({
    required this.title, required this.sub,
    required this.img, required this.bw,
    required this.hot, required this.pulseT,
  });

  @override
  Widget build(BuildContext context) {
    // Template hover: stop shifts up 4px, art shifts up 8px, plaque lifts to 0 from 4px
    return AnimatedSlide(
      offset: Offset(0, hot ? -4 / (bw > 0 ? bw : 1) : 0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSlide(
            offset: Offset(0, hot ? -8 / (bw > 0 ? bw : 1) : 0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: Stack(alignment: Alignment.center, children: [
              if (hot)
                Container(
                  width: bw * 1.1, height: bw * 1.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _terraHi.withValues(alpha: 0.10 + 0.12 * pulseT),
                        blurRadius: 30, spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ColorFiltered(
                colorFilter: hot
                    ? const ColorFilter.matrix(<double>[
                        1.06, 0, 0, 0, 0,
                        0, 1.06, 0, 0, 0,
                        0, 0, 1.06, 0, 0,
                        0, 0, 0, 1,    0,
                      ])
                    : const ColorFilter.matrix(<double>[
                        1, 0, 0, 0, 0,
                        0, 1, 0, 0, 0,
                        0, 0, 1, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: img != null
                    ? RawImage(
                        image: img, width: bw, height: bw,
                        filterQuality: FilterQuality.none,
                        fit: BoxFit.contain,
                      )
                    : SizedBox(width: bw, height: bw),
              ),
            ]),
          ),
          const SizedBox(height: 4),
        // Marble plaque — styled to match the template's .plaque
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFCF0D8), Color(0xFFECDAB0)],
            ),
            border: Border.all(color: const Color(0xFF5E462C), width: 2),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              const BoxShadow(
                color: Color(0xFF5E462C),
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: const Color(0xFF3A2A1C).withValues(alpha: 0.35),
                offset: const Offset(0, 6),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.pixelifySans(
                  fontSize: (bw * 0.09).clamp(11.0, 15.0),
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.pixelifySans(
                  fontSize: (bw * 0.07).clamp(8.0, 11.0),
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF7A5A3A),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final double alpha;
  const _Header({required this.alpha});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final mob = w < 600;
    final titleSize = (w * 0.045).clamp(mob ? 30.0 : 22.0, 52.0);
    return Opacity(
      opacity: alpha,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: mob ? 12 : 8),
          Text(
            'ΑΓΟΡΑ  ·  EST. ANTIQUITY',
            style: GoogleFonts.pixelifySans(
              fontSize: (w * 0.012).clamp(mob ? 10.5 : 9.0, 12.0),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4A30),
              letterSpacing: (w * 0.012).clamp(mob ? 10.5 : 9.0, 12.0) * 0.35,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'A · C · R · O',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFCF0D8),
              letterSpacing: titleSize * 0.02,
              shadows: const [
                Shadow(color: Color(0xFFB89368), offset: Offset(0, 2)),
                Shadow(color: Color(0xFF7A5A3A), offset: Offset(0, 4)),
                Shadow(color: Color(0x8C281A0E), offset: Offset(0, 10), blurRadius: 22),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your path.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: (w * 0.018).clamp(mob ? 15.0 : 13.0, 19.0),
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD4B87A),
              shadows: const [
                Shadow(color: Color(0xFF3A2A1C), offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background painter — earth tiles + road band ──────────────────────────────
class _BgPainter extends CustomPainter {
  final ui.Image? earthTile, roadTile;
  final double roadY, bandH;
  final bool isMobile;
  final bool showRoad;

  const _BgPainter({
    this.earthTile, this.roadTile,
    required this.roadY, required this.bandH,
    this.isMobile = false,
    this.showRoad = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base fill
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF7A5838));

    // Earth tile repeat
    if (earthTile != null) {
      final displayPx = isMobile ? 96.0 : 64.0;
      final sx = displayPx / earthTile!.width;
      final sy = displayPx / earthTile!.height;
      canvas.save();
      canvas.scale(sx, sy);
      final cols = (w / displayPx).ceil() + 1;
      final rows = (h / displayPx).ceil() + 1;
      final p = Paint()
        ..filterQuality = FilterQuality.none
        ..color = const Color(0xBBFFFFFF);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          canvas.drawImage(
            earthTile!,
            Offset(c * earthTile!.width.toDouble(), r * earthTile!.height.toDouble()),
            p,
          );
        }
      }
      canvas.restore();
    }

    if (!showRoad) return;

    // Road band — rotated −1.2°, bleeds past edges
    canvas.save();
    canvas.translate(w / 2, roadY);
    canvas.rotate(-1.2 * math.pi / 180);
    final bw = w * 1.5;

    if (roadTile != null) {
      final tW = roadTile!.width.toDouble();
      final tH = roadTile!.height.toDouble();
      final drawH = bandH;
      final drawW = tW * (drawH / tH); // maintain tile aspect
      final cols  = (bw / drawW).ceil() + 1;
      final startX = -bw / 2;
      for (var c = 0; c < cols; c++) {
        canvas.drawImageRect(
          roadTile!,
          Rect.fromLTWH(0, 0, tW, tH),
          Rect.fromLTWH(startX + c * drawW, -bandH / 2, drawW, drawH),
          Paint()..filterQuality = FilterQuality.none,
        );
      }
    } else {
      canvas.drawRect(
        Rect.fromLTWH(-bw / 2, -bandH / 2, bw, bandH),
        Paint()..color = const Color(0xFFD4C4A0),
      );
    }

    // Edge lines
    final edge = Paint()..color = const Color(0xFF8A7A5A)..strokeWidth = 2;
    canvas.drawLine(Offset(-bw / 2, -bandH / 2), Offset(bw / 2, -bandH / 2), edge);
    canvas.drawLine(Offset(-bw / 2,  bandH / 2), Offset(bw / 2,  bandH / 2), edge);

    // Soft shadows at road edges
    canvas.drawRect(
      Rect.fromLTWH(-bw / 2, -bandH / 2 - 10, bw, 10),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, -bandH / 2 - 10), Offset(0, -bandH / 2),
        [Colors.transparent, const Color(0x33000000)]),
    );
    canvas.drawRect(
      Rect.fromLTWH(-bw / 2, bandH / 2, bw, 14),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, bandH / 2), Offset(0, bandH / 2 + 14),
        [const Color(0x33000000), Colors.transparent]),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BgPainter o) =>
      o.earthTile != earthTile || o.roadTile != roadTile ||
      o.roadY != roadY || o.bandH != bandH ||
      o.isMobile != isMobile || o.showRoad != showRoad;
}

// ── Warm sun haze ─────────────────────────────────────────────────────────────
class _HazePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Top-left warm sun bloom — rgba(255,244,214, 0.55) matching template
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = ui.Gradient.radial(
        Offset(w * 0.22, -h * 0.10), w * 1.2,
        [const Color(0x8CFFF4D6), Colors.transparent], [0.0, 0.55],
      ),
    );
    // Bottom-right warm shadow — rgba(74,51,32, 0.45) matching template
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = ui.Gradient.radial(
        Offset(w * 0.80, h * 1.20), w * 1.2,
        [const Color(0x734A3320), Colors.transparent], [0.0, 0.55],
      ),
    );
  }

  @override
  bool shouldRepaint(_HazePainter _) => false;
}

// ── Scenery painter ───────────────────────────────────────────────────────────
class _SceneryPainter extends CustomPainter {
  final double w, h;
  final bool isMobile, front;
  final ui.Image? cypress, statue, brokenCol, olive, amphora, brazier;

  const _SceneryPainter({
    required this.w, required this.h,
    required this.isMobile, required this.front,
    this.cypress, this.statue, this.brokenCol, this.olive,
    this.amphora, this.brazier,
  });

  // Draws a sprite with its BASE at (cx, baseY). min/max match template's CSS clamp().
  void _sp(Canvas canvas, ui.Image? img, double cx, double baseY, double spriteW,
      {bool hideMobile = false, double minW = 20.0, double maxW = 120.0}) {
    if (img == null || (hideMobile && isMobile)) return;
    final sw = spriteW.clamp(minW, maxW);
    final sh = sw * img.height / img.width;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(cx - sw / 2, baseY - sh, sw, sh),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Positions mirror template CONFIG exactly:
    //   back scenery  — bottom-anchor at top% (50–52%)
    //   front scenery — bottom-anchor at top% (74–83%)
    if (!front) {
      _sp(canvas, cypress,   w * 0.07, h * 0.50, w * 0.07,  minW: isMobile ? 54 : 46, maxW: 92);
      _sp(canvas, statue,    w * 0.33, h * 0.50, w * 0.06,  minW: 40, maxW: 78,  hideMobile: true);
      _sp(canvas, brokenCol, w * 0.66, h * 0.51, w * 0.05,  minW: 34, maxW: 66,  hideMobile: true);
      _sp(canvas, cypress,   w * 0.93, h * 0.49, w * 0.07,  minW: isMobile ? 54 : 46, maxW: 96);
      _sp(canvas, olive,     w * 0.42, h * 0.52, w * 0.05,  minW: 34, maxW: 66,  hideMobile: true);
    } else {
      _sp(canvas, amphora, w * 0.11, h * 0.78, w * 0.045, minW: isMobile ? 38 : 30, maxW: 58);
      _sp(canvas, olive,   w * 0.27, h * 0.82, w * 0.07,  minW: isMobile ? 54 : 44, maxW: 86);
      _sp(canvas, brazier, w * 0.37, h * 0.74, w * 0.04,  minW: 26, maxW: 52,  hideMobile: true);
      _sp(canvas, brazier, w * 0.63, h * 0.74, w * 0.04,  minW: 26, maxW: 52,  hideMobile: true);
      _sp(canvas, olive,   w * 0.73, h * 0.83, w * 0.07,  minW: isMobile ? 58 : 48, maxW: 90);
      _sp(canvas, amphora, w * 0.90, h * 0.79, w * 0.045, minW: 30, maxW: 56,  hideMobile: true);
    }
  }

  @override
  bool shouldRepaint(_SceneryPainter o) =>
      o.w != w || o.h != h || o.front != front ||
      o.cypress != cypress || o.statue != statue ||
      o.brokenCol != brokenCol || o.olive != olive ||
      o.amphora != amphora || o.brazier != brazier;
}

// ── Mobile scenery — back + front layers, positions from reference mobile.js ───
class _MobileSceneryPainter extends CustomPainter {
  final double w, h;
  final bool front;
  final ui.Image? cypress, statue, flowerBush, herm, amphora, olive;

  const _MobileSceneryPainter({
    required this.w, required this.h, required this.front,
    this.cypress, this.statue, this.flowerBush, this.herm,
    this.amphora, this.olive,
  });

  // Bottom-centre anchored: base of image at (w*xF, h*yF)
  void _sp(Canvas canvas, ui.Image? img,
      double xF, double yF, double vwF, double minW, double maxW) {
    if (img == null) return;
    final sw = (w * vwF).clamp(minW, maxW);
    final sh = sw * img.height / img.width;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(w * xF - sw / 2, h * yF - sh, sw, sh),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!front) {
      _sp(canvas, cypress,    0.33, 0.13, 0.11, 40, 72);
      _sp(canvas, statue,     0.69, 0.12, 0.11, 40, 72);  // swapped: statue top-right
      _sp(canvas, cypress,    0.20, 0.40, 0.14, 46, 92);  // swapped: tree left-mid
      _sp(canvas, flowerBush, 0.80, 0.38, 0.15, 48, 98);
      _sp(canvas, herm,       0.25, 0.67, 0.12, 40, 80);
      _sp(canvas, cypress,    0.84, 0.65, 0.18, 58, 120);
    } else {
      _sp(canvas, amphora,    0.12, 0.96, 0.12, 40, 74);
      _sp(canvas, flowerBush, 0.78, 0.94, 0.20, 62, 112);
      _sp(canvas, amphora,    0.87, 0.71, 0.11, 34, 62);
      _sp(canvas, olive,      0.15, 0.60, 0.12, 40, 76);
    }
  }

  @override
  bool shouldRepaint(_MobileSceneryPainter o) =>
      o.w != w || o.h != h || o.front != front ||
      o.cypress != cypress || o.statue != statue ||
      o.flowerBush != flowerBush || o.herm != herm ||
      o.amphora != amphora || o.olive != olive;
}

// ── Vignette ──────────────────────────────────────────────────────────────────
class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.80,
        [Colors.transparent, const Color(0x1A000000), const Color(0x44000000)],
        [0.0, 0.70, 1.0],
      ),
    );
  }

  @override
  bool shouldRepaint(_VignettePainter _) => false;
}
