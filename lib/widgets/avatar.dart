import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import '../theme/acro_theme.dart';

enum AvatarStyle { gold, stone, red, green, blue }

// Deterministically picks one of the 3 ghost characters from a seed string.
// Same seed → same ghost every time.
class AcroAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final AvatarStyle style;

  /// When provided the avatar shows a ghost image instead of initials.
  /// Any unique string works — uid, name, etc.
  final String? seed;

  const AcroAvatar({
    super.key,
    required this.initials,
    this.size = 34,
    this.style = AvatarStyle.gold,
    this.seed,
  });

  static const _ghosts = [
    'assets/images/ghost_aristotle_copper.png',
    'assets/images/ghost_plato_silver.png',
    'assets/images/ghost_socrates_gold.png',
  ];

  /// Returns the ghost asset path for any seed string.
  static String ghostAssetFor(String seed) =>
      _ghosts[seed.hashCode.abs() % _ghosts.length];

  Color get _bg {
    switch (style) {
      case AvatarStyle.stone: return AcroColors.stoneMid;
      case AvatarStyle.red:   return AcroColors.red;
      case AvatarStyle.green: return AcroColors.green;
      case AvatarStyle.blue:  return AcroColors.blue;
      default:                return AcroColors.gold;
    }
  }

  Color get _fg {
    switch (style) {
      case AvatarStyle.stone: return AcroColors.goldLight;
      case AvatarStyle.blue:  return const Color(0xFFA8C4E8);
      default:                return AcroColors.stone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = seed?.trim() ?? '';
    if (s.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(
          ghostAssetFor(s),
          width: size,
          height: size,
          fit: BoxFit.contain, // show full ghost: face + tentacles
        ),
      );
    }
    // Fallback: coloured circle with initials
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
      child: Center(
        child: Text(initials,
            style: TextStyle(
                color: _fg,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// Ghost avatar with floating bob and eye-blink animations.
// Used in video tiles when the camera is off.
//
// Eye coordinates derived from the 1320×1620 source images rendered via
// BoxFit.contain in a square size×size container:
//   rendered width  = size × 0.8148  (= 1320/1620)
//   x-offset (centre) = size × 0.0926
//   eye top (y)    ≈ size × 0.148   (240 / 1620)
//   eye height     ≈ size × 0.154   (250 / 1620)
//   left-eye left  ≈ size × 0.203   ((180/1320)×0.8148 + 0.0926)
//   left-eye width ≈ size × 0.185
//   right-eye left ≈ size × 0.500   ((660/1320)×0.8148 + 0.0926)
//   right-eye width≈ size × 0.191
class AnimatedGhostAvatar extends StatefulWidget {
  final String initials;
  final double size;
  final AvatarStyle style;
  final String seed;

  const AnimatedGhostAvatar({
    super.key,
    required this.initials,
    required this.seed,
    this.size = 34,
    this.style = AvatarStyle.gold,
  });

  @override
  State<AnimatedGhostAvatar> createState() => _AnimatedGhostAvatarState();
}

class _AnimatedGhostAvatarState extends State<AnimatedGhostAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatY;
  late final AnimationController _blinkCtrl;
  late final Animation<double> _blinkH;
  Timer? _blinkTimer;
  final _rand = Random();

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _floatY = Tween<double>(begin: -5.0, end: 5.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _blinkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _blinkH = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeIn));

    _scheduleBlink();
  }

  void _scheduleBlink() {
    final ms = 2000 + _rand.nextInt(3000);
    _blinkTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _blinkCtrl.forward().then((_) {
        if (!mounted) return;
        _blinkCtrl.reverse().then((_) {
          if (mounted) _scheduleBlink();
        });
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _floatCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _blinkCtrl]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatY.value),
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              AcroAvatar(
                initials: widget.initials,
                seed: widget.seed,
                size: s,
                style: widget.style,
              ),
              // Left eyelid
              Positioned(
                left:   s * 0.203,
                top:    s * 0.148,
                width:  s * 0.185,
                height: s * 0.154 * _blinkH.value,
                child: const ColoredBox(color: Colors.black),
              ),
              // Right eyelid
              Positioned(
                left:   s * 0.500,
                top:    s * 0.148,
                width:  s * 0.191,
                height: s * 0.154 * _blinkH.value,
                child: const ColoredBox(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
