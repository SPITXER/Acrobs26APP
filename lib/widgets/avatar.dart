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
