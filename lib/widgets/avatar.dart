import 'package:flutter/material.dart';
import '../theme/acro_theme.dart';

enum AvatarStyle { gold, stone, red, green, blue }

class AcroAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final AvatarStyle style;

  const AcroAvatar({
    super.key,
    required this.initials,
    this.size = 34,
    this.style = AvatarStyle.gold,
  });

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
