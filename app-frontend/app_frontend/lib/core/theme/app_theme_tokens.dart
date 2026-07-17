import 'package:flutter/material.dart';

class AppThemeTokens {
  const AppThemeTokens._();

  static const Color ink = Color(0xFF23170F);
  static const Color inkSoft = Color(0xFF6C5141);
  static const Color inkMuted = Color(0xFF9A806E);
  static const Color canvas = Color(0xFFFFF7EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFFEEE0);
  static const Color line = Color(0xFFF0D7C4);

  static const Color primary = Color(0xFFFF7A1A);
  static const Color primaryDark = Color(0xFFC84A00);
  static const Color blue = Color(0xFF246BFD);
  static const Color amber = Color(0xFFFFB21A);
  static const Color red = Color(0xFFE5484D);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color mint = Color(0xFFEAF8D8);
  static const Color sky = Color(0xFFE8F3FF);
  static const Color sand = Color(0xFFFFF6DD);

  // Softer, more consistent corner radii for a calmer, less boxy look.
  static const double radiusXs = 8;
  static const double radiusSm = 11;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 22;
  static const double radiusPill = 999;

  // Single spacing scale used across cards, lists and sheets so the whole app
  // breathes consistently instead of every widget picking its own gaps.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
}
