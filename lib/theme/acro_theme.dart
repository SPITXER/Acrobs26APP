import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AcroColors {
  static const gold = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFE8D5A3);
  static const goldDark = Color(0xFF8B6914);
  static const marble = Color(0xFFF5F2EC);
  static const marbleDark = Color(0xFFE0DBD0);
  static const stone = Color(0xFF2C2820);
  static const stoneMid = Color(0xFF5C5248);
  static const stoneLight = Color(0xFF9C9080);
  static const ink = Color(0xFF1A1510);
  static const parch = Color(0xFFFAF7F0);
  static const red = Color(0xFF8B2E2E);
  static const redLight = Color(0xFFC4504A);
  static const green = Color(0xFF2D7D4F);
  static const blue = Color(0xFF1E4F8C);
  static const darkBg = Color(0xFF0F0E17);
  static const darkCard = Color(0xFF09080F);
}

class AcroTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AcroColors.gold,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.dmSansTextTheme(),
        scaffoldBackgroundColor: AcroColors.parch,
        appBarTheme: AppBarTheme(
          backgroundColor: AcroColors.parch,
          foregroundColor: AcroColors.ink,
          elevation: 0,
          titleTextStyle: GoogleFonts.playfairDisplay(
            color: AcroColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  static TextStyle get playfair => GoogleFonts.playfairDisplay();
  static TextStyle get dmSans => GoogleFonts.dmSans();
}
