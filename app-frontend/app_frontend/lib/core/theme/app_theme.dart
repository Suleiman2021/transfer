import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandInk = Color(0xFF11203B);
  static const Color brandTeal = Color(0xFF0F766E);
  static const Color brandCoral = Color(0xFFE76F51);
  static const Color brandGold = Color(0xFFF4A261);
  static const Color brandSky = Color(0xFFBEE3DB);
  static const Color panel = Color(0xFFF8F5EF);
  static const Color textDark = Color(0xFF1F2937);
  static const Color noticeSuccess = Color(0xFF1F9D63);
  static const Color noticeError = Color(0xFFD14343);
  static const Color noticeWarning = Color(0xFFE68619);
  static const BorderRadius snackRadius = BorderRadius.all(Radius.circular(14));

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brandTeal,
          brightness: Brightness.light,
        ).copyWith(
          primary: brandTeal,
          secondary: brandCoral,
          surface: Colors.white,
          onSurface: textDark,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: scheme,
      scaffoldBackgroundColor: panel,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        contentTextStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        shape: const RoundedRectangleBorder(borderRadius: snackRadius),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.96),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: const TextStyle(color: Color(0xFF52606D)),
        errorStyle: const TextStyle(
          color: Color(0xFFCB3A31),
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.25,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandInk.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCB3A31), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCB3A31), width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandTeal,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: brandTeal.withValues(alpha: 0.28),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandInk,
          side: BorderSide(color: brandInk.withValues(alpha: 0.12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: brandSky,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: brandInk.withValues(alpha: 0.08)),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.22,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.28,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: textDark,
          height: 1.3,
        ),
        titleSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: textDark,
          height: 1.3,
        ),
        bodyLarge: TextStyle(
          color: textDark,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: textDark,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          color: Color(0xFF4B5563),
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          height: 1.2,
        ),
        labelMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.2,
        ),
      ),
    );
  }

  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF2D6), Color(0xFFDCF7EE), Color(0xFFD6E8FF)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12355B), Color(0xFF0F766E), Color(0xFFE76F51)],
  );
}
