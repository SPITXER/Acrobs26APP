import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'agora_screen.dart';
import 'stoa_screen.dart';

const double _px = 2.0;

enum AcropolisZone { agora, stoa, acropolis }

const _copper   = Color(0xFFB87333);
const _copperLt = Color(0xFFD4956A);
const _copperDk = Color(0xFF7A4520);
const _orange   = Color(0xFFFF8C42);
const _wallFill = Color(0xFF0F0500);

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
    _flicker = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..repeat(reverse: true);
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
            final agoraRect     = Rect.fromLTWH(w * 0.38, h * 0.80, w * 0.24, h * 0.10);
            final stoaRect      = Rect.fromLTWH(w * 0.28, h * 0.49, w * 0.44, h * 0.20);
            final acropolisRect = Rect.fromLTWH(w * 0.32, h * 0.13, w * 0.36, h * 0.24);
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
                      hovered: _hovered, agoraRect: agoraRect,
                      stoaRect: stoaRect, acropolisRect: acropolisRect,
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
            const Text('MENU', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _copper, letterSpacing: 2.5, fontWeight: FontWeight.bold)),
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
            _menuItem('◈  PROFILE'), _menuDivider(),
            _menuItem('📜  RULES'),  _menuDivider(),
            _menuItem('⚙  SETTINGS'), _menuDivider(),
            _menuItem('⬡  EXIT'),
          ]),
        ),
      ],
    ]);
  }

  Widget _menuItem(String label) => InkWell(
    onTap: () => setState(() => _menuOpen = false),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _copperLt, letterSpacing: 1.5))),
  );

  Widget _menuDivider() => Container(height: 1, color: const Color(0x40B87333));

  void _handleTap(Offset pos, Rect agora, Rect stoa, Rect acropolis) {
    if (agora.contains(pos)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgoraScreen()));
    } else if (stoa.contains(pos)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoaScreen()));
    } else if (acropolis.contains(pos)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Symposium — coming soon'), backgroundColor: _wallFill, duration: Duration(seconds: 2)));
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
    final wall = _wallPath(w, h);
    canvas.drawPath(wall, Paint()..color = _wallFill);
    canvas.drawPath(wall, Paint()..color = _copperDk..style = PaintingStyle.stroke..strokeWidth = _px * 9..strokeJoin = StrokeJoin.round);
    canvas.drawPath(wall, Paint()..color = _copper..style = PaintingStyle.stroke..strokeWidth = _px * 5..strokeJoin = StrokeJoin.round);
    canvas.drawPath(wall, Paint()..color = _copperLt..style = PaintingStyle.stroke..strokeWidth = _px * 1.5..strokeJoin = StrokeJoin.round);
    _battlements(canvas, w, h);
    _route(canvas, w, h);
    _gate(canvas, w, h);
    _market(canvas, w, h);
    _temple(canvas, w, h);
    _hoverGlow(canvas, w, h);
    _labels(canvas, w, h);
  }

  Path _wallPath(double w, double h) {
    final p = Path();
    p.moveTo(w * 0.44, h * 0.91);
    p.quadraticBezierTo(w * 0.37, h * 0.905, w * 0.30, h * 0.875);
    p.quadraticBezierTo(w * 0.22, h * 0.845, w * 0.20, h * 0.775);
    p.quadraticBezierTo(w * 0.175, h * 0.700, w * 0.195, h * 0.625);
    p.quadraticBezierTo(w * 0.215, h * 0.545, w * 0.185, h * 0.465);
    p.quadraticBezierTo(w * 0.170, h * 0.385, w * 0.200, h * 0.305);
    p.quadraticBezierTo(w * 0.225, h * 0.225, w * 0.295, h * 0.155);
    p.quadraticBezierTo(w * 0.375, h * 0.085, w * 0.500, h * 0.075);
    p.quadraticBezierTo(w * 0.625, h * 0.085, w * 0.705, h * 0.155);
    p.quadraticBezierTo(w * 0.775, h * 0.225, w * 0.800, h * 0.305);
    p.quadraticBezierTo(w * 0.830, h * 0.385, w * 0.815, h * 0.465);
    p.quadraticBezierTo(w * 0.785, h * 0.545, w * 0.805, h * 0.625);
    p.quadraticBezierTo(w * 0.825, h * 0.700, w * 0.800, h * 0.775);
    p.quadraticBezierTo(w * 0.780, h * 0.845, w * 0.700, h * 0.875);
    p.quadraticBezierTo(w * 0.630, h * 0.905, w * 0.560, h * 0.910);
    p.lineTo(w * 0.56, h * 0.965); p.lineTo(w * 0.44, h * 0.965); p.lineTo(w * 0.44, h * 0.910);
    p.close();
    return p;
  }

  void _stars(Canvas canvas, double w, double h) {
    final rng = math.Random(42);
    for (int i = 0; i < 90; i++) {
      final x = rng.nextDouble() * w; final y = rng.nextDouble() * h;
      final phase = rng.nextDouble(); final sz = 0.8 + rng.nextDouble() * 1.6;
      final flick = math.sin(flickerT * math.pi * 4 + phase * math.pi * 2);
      final alpha = (0.35 + 0.55 * ((flick + 1) / 2)).clamp(0.0, 1.0);
      canvas.drawRect(Rect.fromLTWH(x - sz/2, y - sz/2, sz, sz), Paint()..color = _copper.withValues(alpha: alpha));
    }
  }

  void _moon(Canvas canvas, double w, double h) {
    final cx = w * 0.13; final cy = h * 0.13; final r = w * 0.048;
    canvas.drawCircle(Offset(cx, cy), r * 2.0,
        Paint()..color = _orange.withValues(alpha: 0.06 + 0.04 * pulseT)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _copperLt);
    canvas.drawCircle(Offset(cx + r * 0.48, cy - r * 0.08), r * 0.84, Paint()..color = Colors.black);
  }

  void _battlements(Canvas canvas, double w, double h) {
    final p = Paint()..color = _copper;
    void m(double fx, double fy) => _r(canvas, p, fx*w-_px*2, fy*h-_px*4, _px*4, _px*4);
    for (final pt in [[0.38,0.095],[0.44,0.082],[0.50,0.079],[0.56,0.082],[0.62,0.095]]) { m(pt[0],pt[1]); }
    for (final pt in [[0.200,0.250],[0.188,0.380],[0.185,0.505],[0.193,0.630],[0.205,0.755]]) { m(pt[0],pt[1]); }
    for (final pt in [[0.800,0.250],[0.812,0.380],[0.815,0.505],[0.807,0.630],[0.795,0.755]]) { m(pt[0],pt[1]); }
  }

  void _route(Canvas canvas, double w, double h) {
    final dot = Paint()..color = _copper.withValues(alpha: 0.55);
    final pts = [
      Offset(w*.500,h*.875), Offset(w*.500,h*.800), Offset(w*.470,h*.730),
      Offset(w*.485,h*.660), Offset(w*.500,h*.590), Offset(w*.515,h*.510),
      Offset(w*.500,h*.440), Offset(w*.500,h*.370), Offset(w*.500,h*.300), Offset(w*.500,h*.240),
    ];
    for (int i = 0; i < pts.length-1; i++) {
      final p0 = pts[i]; final p1 = pts[i+1];
      final steps = ((p1-p0).distance / (_px*5.5)).floor();
      for (int j = 0; j <= steps; j++) {
        final t = steps==0?0.0:j/steps;
        _r(canvas,dot, p0.dx+(p1.dx-p0.dx)*t-_px, p0.dy+(p1.dy-p0.dy)*t-_px, _px*2,_px*2);
      }
    }
  }

  void _gate(Canvas canvas, double w, double h) {
    final hot = hovered==AcropolisZone.agora;
    final c=hot?_orange:_copper; final cLt=hot?const Color(0xFFFFD090):_copperLt; final cDk=hot?_copper:_copperDk;
    final cx=w*.500; final cy=h*.870;
    _twr(canvas,cx-_px*20,cy-_px*18,_px*13,_px*18,c,cLt,cDk);
    _twr(canvas,cx+_px*7, cy-_px*18,_px*13,_px*18,c,cLt,cDk);
    final aX=cx-_px*7; final aW=_px*14; final aH=_px*12;
    _r(canvas,Paint()..color=Colors.black,aX,cy-aH,aW,aH);
    for (int i=0;i<=7;i++) {
      final t=i/7.0;
      final ax=aX+aW/2+math.cos(math.pi-math.pi*t)*(aW/2-_px);
      final ay=cy-aH+(1-math.sin(math.pi*t))*_px*5;
      _r(canvas,Paint()..color=cDk,ax-_px,ay-_px,_px*2.5,_px*2.5);
    }
    for (int i=1;i<=2;i++) { _r(canvas,Paint()..color=cDk.withValues(alpha:.5),aX+aW*i/3-_px*.5,cy-aH+_px*4,_px,aH-_px*4); }
    _r(canvas,Paint()..color=cLt,aX-_px*3,cy-aH-_px*2.5,aW+_px*6,_px*2.5);
    _r(canvas,Paint()..color=cDk,cx-_px*11,cy,_px*22,_px*2);
    _r(canvas,Paint()..color=c,  cx-_px*9, cy+_px*2,_px*18,_px*2);
  }

  void _twr(Canvas canvas,double x,double y,double tw,double th,Color c,Color cLt,Color cDk) {
    _r(canvas,Paint()..color=c,  x,y,tw,th);
    _r(canvas,Paint()..color=cDk,x+tw-_px*2.5,y,_px*2.5,th);
    _r(canvas,Paint()..color=cLt,x,y,_px*1.5,th);
    _r(canvas,Paint()..color=Colors.black,x+tw*.42,y+th*.30,_px*2,_px*5);
    _r(canvas,Paint()..color=Colors.black,x+tw*.30,y+th*.40,_px*4,_px*2);
    for (int i=0;i<3;i++) { _r(canvas,Paint()..color=cLt,x+i*(tw/3)+_px,y-_px*4,_px*3.5,_px*4); }
    for (int row=1;row<(th/(_px*5)).floor();row++) {
      _r(canvas,Paint()..color=cDk.withValues(alpha:.3),x,y+row*_px*5,tw,_px*.7);
    }
  }

  void _market(Canvas canvas, double w, double h) {
    final hot=hovered==AcropolisZone.stoa;
    final c=hot?_orange:_copper; final cLt=hot?const Color(0xFFFFD090):_copperLt; final cDk=hot?_copper:_copperDk;
    final cx=w*.500; final cy=h*.590;
    const sW=_px*15; const sH=_px*14; const gap=_px*4; const cnt=4;
    const totW=cnt*sW+(cnt-1)*gap;
    final sx0=cx-totW/2;
    _r(canvas,Paint()..color=c,sx0-_px*2,cy-sH-_px*6,totW+_px*4,_px*2);
    for (int i=0;i<cnt;i++) {
      final sx=sx0+i*(sW+gap); final sy=cy-sH;
      _r(canvas,Paint()..color=cDk,sx,sy,sW,sH);
      _r(canvas,Paint()..color=Colors.black.withValues(alpha:.3),sx+sW-_px*2,sy,_px*2,sH);
      _r(canvas,Paint()..color=_wallFill,sx+sW*.2,sy+sH*.15,sW*.6,sH*.42);
      _r(canvas,Paint()..color=cLt,sx+sW*.25,sy+sH*.44,_px*3,_px*2.5);
      _r(canvas,Paint()..color=c.withValues(alpha:.8),sx+sW*.55,sy+sH*.43,_px*2.5,_px*3);
      _awning(canvas,sx-_px*2,sy-_px*6,sW+_px*4,_px*6,c,cLt);
      _r(canvas,Paint()..color=c,  sx-_px,cy-_px*2.5,sW+_px*2,_px*3);
      _r(canvas,Paint()..color=cLt,sx-_px,cy-_px*2.5,sW+_px*2,_px);
      _r(canvas,Paint()..color=cDk,sx-_px,cy+_px*.5, sW+_px*2,_px);
    }
  }

  void _awning(Canvas canvas,double x,double y,double aw,double ah,Color c,Color cLt) {
    double ry=y; int row=0;
    while (ry<y+ah) {
      final rowH=(y+ah-ry).clamp(0.0,_px*1.5);
      _r(canvas,Paint()..color=row%2==0?c:cLt.withValues(alpha:.7),x,ry,aw,rowH);
      ry+=_px*1.5; row++;
    }
    _r(canvas,Paint()..color=cLt,x,y,aw,_px);
    final drops=(aw/(_px*5)).floor();
    for (int d=0;d<drops;d++) { _r(canvas,Paint()..color=c,x+d*_px*5+_px,y+ah,_px*2.5,_px*3); }
  }

  void _temple(Canvas canvas, double w, double h) {
    final hot=hovered==AcropolisZone.acropolis;
    final c=hot?_orange:_copper; final cLt=hot?const Color(0xFFFFD090):_copperLt; final cDk=hot?_copper:_copperDk;
    final cx=w*.500; final baseY=h*.365;
    const tW=_px*52; const colH=_px*22.0;
    for (int s=0;s<3;s++) {
      final sw=tW+s*_px*7;
      _r(canvas,Paint()..color=s==0?cLt:c,cx-sw/2,baseY-s*_px*2.5,sw,_px*2.5);
      _r(canvas,Paint()..color=cDk,cx-sw/2,baseY-s*_px*2.5+_px*2,sw,_px*.5);
    }
    final platY=baseY-_px*7.5; final platW=tW-_px*4;
    _r(canvas,Paint()..color=cLt,cx-platW/2,platY,platW,_px*2.5);
    const nC=8; final colArea=platW-_px*4; final colSp=colArea/(nC-1); final colBase=platY-colH;
    for (int i=0;i<nC;i++) {
      final colX=cx-colArea/2+i*colSp;
      _r(canvas,Paint()..color=cLt,colX-_px*2.5,colBase,_px*5,_px*2.5);
      _r(canvas,Paint()..color=c,  colX-_px*1.5,colBase+_px*2.5,_px*3,colH-_px*5);
      _r(canvas,Paint()..color=cDk,colX+_px*1,  colBase+_px*2.5,_px,  colH-_px*5);
      _r(canvas,Paint()..color=cLt,colX-_px*2.5,platY-_px*2.5,_px*5,_px*2.5);
    }
    final entY=colBase-_px*4.5;
    _r(canvas,Paint()..color=cLt,cx-tW/2,entY,tW,_px*2.5);
    _r(canvas,Paint()..color=c,  cx-tW/2,entY+_px*2.5,tW,_px*2.5);
    for (int t=0;t<7;t++) {
      final tx=cx-tW/2+_px*5+t*(tW-_px*10)/6;
      _r(canvas,Paint()..color=cDk,tx,entY+_px*2.5,_px*1.5,_px*2.5);
      _r(canvas,Paint()..color=cDk,tx+_px*3,entY+_px*2.5,_px*1.5,_px*2.5);
    }
    final pedBase=entY-_px*.5;
    const pedS=12;
    for (int i=0;i<pedS;i++) {
      final rowW=tW*(1-i/pedS)+_px*2;
      _r(canvas,Paint()..color=i==0?cLt:c,cx-rowW/2,pedBase-i*_px*1.8,rowW,_px*2.1);
    }
    final peakY=pedBase-pedS*_px*1.8;
    final ga=(0.25+0.45*pulseT).clamp(0.0,1.0);
    canvas.drawCircle(Offset(cx,peakY-_px*7),_px*7,
        Paint()..color=(hot?_orange:_copper).withValues(alpha:ga)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));
    _star4(canvas,cx,peakY-_px*7,hot?_orange:cLt,_px*3);
  }

  void _star4(Canvas canvas,double cx,double cy,Color c,double s) {
    final p=Paint()..color=c;
    _r(canvas,p,cx-s*.22,cy-s,   s*.44,s*2  );
    _r(canvas,p,cx-s,    cy-s*.22,s*2,  s*.44);
    _r(canvas,p,cx-s*.6, cy-s*.6, s*.3, s*.3 );
    _r(canvas,p,cx+s*.3, cy-s*.6, s*.3, s*.3 );
    _r(canvas,p,cx-s*.6, cy+s*.3, s*.3, s*.3 );
    _r(canvas,p,cx+s*.3, cy+s*.3, s*.3, s*.3 );
    _r(canvas,p,cx-s*.35,cy-s*.35,s*.7, s*.7 );
  }

  void _hoverGlow(Canvas canvas, double w, double h) {
    if (hovered==null) return;
    final rect=switch(hovered!){
      AcropolisZone.agora=>agoraRect, AcropolisZone.stoa=>stoaRect, AcropolisZone.acropolis=>acropolisRect};
    canvas.drawRect(rect.inflate(_px*2),Paint()
      ..color=_orange.withValues(alpha:(0.15+0.20*pulseT).clamp(0.0,1.0))
      ..style=PaintingStyle.stroke..strokeWidth=_px*2);
  }

  void _labels(Canvas canvas, double w, double h) {
    _lbl(canvas,'AGORA',         w*.50,h*.955,_copper,  _px*2.2);
    _lbl(canvas,'STOA',          w*.50,h*.680,_copper,  _px*2.2);
    _lbl(canvas,'SYMPOSIUM',     w*.50,h*.120,_copperLt,_px*2.0);
    _lbl(canvas,'A · C · R · O',w*.50,h*.030,_copper,  _px*2.4,ls:7.0);
  }

  void _lbl(Canvas canvas,String text,double cx,double cy,Color color,double fs,{double ls=2.0}) {
    final tp=TextPainter(text:TextSpan(text:text,style:TextStyle(
        fontFamily:'monospace',fontSize:fs,fontWeight:FontWeight.bold,
        color:color,letterSpacing:ls,shadows:const[Shadow(color:Colors.black,blurRadius:4)])),
        textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(cx-tp.width/2,cy-tp.height/2));
  }

  void _r(Canvas canvas,Paint paint,double x,double y,double w,double h) {
    if (w<=0||h<=0) return;
    canvas.drawRect(Rect.fromLTWH(x,y,w,h),paint);
  }

  @override
  bool shouldRepaint(_CityMapPainter old) =>
      old.pulseT!=pulseT||old.flickerT!=flickerT||old.hovered!=hovered;
}
