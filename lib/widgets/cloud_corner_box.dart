import 'package:flutter/material.dart';

/// A card/box widget that paints a pixel-art Greek cloud swirl at the
/// top-right corner (flowing up-right) and bottom-left corner (flowing
/// down-left). Drop-in replacement for a styled Container.
class CloudCornerBox extends StatelessWidget {
  final Widget child;
  final Color  backgroundColor;
  final Color  borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double? width;

  const CloudCornerBox({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFF0B0F1A),
    this.borderColor     = const Color(0x38B87333), // gold ~22%
    this.borderWidth     = 1.0,
    this.borderRadius    = const BorderRadius.all(Radius.circular(4)),
    this.padding         = const EdgeInsets.all(20),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main box
        Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: child,
        ),

        // Top-right cloud swirl
        const Positioned(
          top: -38, right: -38,
          child: SizedBox(
            width: 76, height: 76,
            child: CustomPaint(painter: _SwirlPainter(topRight: true)),
          ),
        ),

        // Bottom-left cloud swirl (180° mirror)
        const Positioned(
          bottom: -38, left: -38,
          child: SizedBox(
            width: 76, height: 76,
            child: CustomPaint(painter: _SwirlPainter(topRight: false)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SwirlPainter extends CustomPainter {
  final bool topRight;
  const _SwirlPainter({required this.topRight});

  // Pixel unit size
  static const double u = 3.4;
  // The corner of the card sits at the centre of the 76×76 canvas
  static const double _k = 38.0;

  // colours: 0=brightGold  1=copper  2=darkCopper  3=deepBronze
  static const _col = [
    Color(0xFFD4A853),
    Color(0xFFB87333),
    Color(0xFF8B5A22),
    Color(0xFF5C3A12),
  ];

  // Pixel positions relative to corner (0,0).
  // For top-right: +dx = right (outside), –dy = up (outside).
  // For bottom-left every sign is negated (180° rotation).
  static const List<List<int>> _px = [
    // Tight core at corner
    [-1,-1, 0], [ 0,-1, 0], [ 1,-1, 0],
    [-1, 0, 0], [ 0, 0, 3], [ 1, 0, 1],
    [-1, 1, 1], [ 0, 1, 1],

    // Spiral arm going UP
    [ 0,-2, 0], [ 1,-2, 0],
    [ 0,-3, 0], [ 1,-3, 1],
    [ 0,-4, 0], [ 1,-4, 1], [ 2,-4, 2],
    [ 0,-5, 1], [ 1,-5, 1], [ 2,-5, 2],
    [ 0,-6, 1], [ 1,-6, 2],

    // Spiral arm going RIGHT
    [ 2,-1, 0], [ 3,-1, 1],
    [ 2, 0, 0], [ 3, 0, 1], [ 4, 0, 2],
    [ 2,-2, 1], [ 3,-2, 1], [ 4,-2, 2],
    [ 3,-3, 1], [ 4,-3, 2], [ 5,-3, 2],
    [ 4,-4, 1], [ 5,-4, 2],
    [ 5,-1, 2], [ 6,-1, 2],
    [ 5, 0, 2],

    // Diagonal arc connecting the two arms
    [ 2,-3, 0], [ 3,-4, 1], [ 4,-5, 2],
    [ 1,-2, 1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _px) {
      final ddx = topRight ? p[0] : -p[0];
      final ddy = topRight ? p[1] : -p[1];
      canvas.drawRect(
        Rect.fromLTWH(_k + ddx * u, _k + ddy * u, u, u),
        Paint()..color = _col[p[2]],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
