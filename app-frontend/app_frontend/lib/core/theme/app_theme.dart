import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandInk = Color(0xFF241542);
  static const Color brandTeal = Color(0xFF6A38F2);
  static const Color brandCoral = Color(0xFF9157F8);
  static const Color brandPlum = Color(0xFF7C3AED);
  static const Color brandGold = Color(0xFFC58BFF);
  static const Color brandSky = Color(0xFFE8D9FF);
  static const Color panel = Color(0xFFF6F1FF);
  static const Color textDark = Color(0xFF23193D);
  static const Color textMuted = Color(0xFF5E4F83);
  static const Color textSoft = Color(0xFF7D70A2);
  static const Color glassTint = Color(0xFFF9F4FF);
  static const Color glassLine = Color(0xFFB995FF);
  static const Color noticeSuccess = Color(0xFF1F9D63);
  static const Color noticeError = Color(0xFFD14343);
  static const Color noticeWarning = Color(0xFFE68619);
  static const BorderRadius snackRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius panelRadius = BorderRadius.all(Radius.circular(22));
  static const BorderRadius tileRadius = BorderRadius.all(Radius.circular(18));

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brandTeal,
          brightness: Brightness.light,
        ).copyWith(
          primary: brandTeal,
          secondary: brandCoral,
          surface: Colors.white,
          tertiary: brandGold,
          onSurface: textDark,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: scheme,
      scaffoldBackgroundColor: panel,
      iconTheme: const IconThemeData(size: 20, color: textDark),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textDark,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        contentTextStyle: const TextStyle(
          color: textDark,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        shape: const RoundedRectangleBorder(borderRadius: snackRadius),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.90),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: panelRadius,
          side: BorderSide(color: glassLine.withValues(alpha: 0.16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.97),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.97),
        modalBackgroundColor: Colors.white.withValues(alpha: 0.97),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.86),
        indicatorColor: brandSky.withValues(alpha: 0.7),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 12.2,
              color: textDark,
            );
          }
          return const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: textMuted,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF4C3E6E),
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF7C71A3),
          fontWeight: FontWeight.w500,
        ),
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
          borderSide: BorderSide(color: brandTeal.withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandTeal, width: 1.6),
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
          elevation: 2,
          shadowColor: brandTeal.withValues(alpha: 0.28),
          minimumSize: const Size.fromHeight(44),
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
          minimumSize: const Size.fromHeight(42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(42),
          backgroundColor: brandCoral.withValues(alpha: 0.16),
          foregroundColor: brandInk,
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
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.98),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: brandTeal.withValues(alpha: 0.16)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.18,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textDark,
          height: 1.27,
        ),
        titleSmall: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: textDark,
          height: 1.27,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: textDark,
          height: 1.42,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textDark,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          fontSize: 12.5,
          color: textMuted,
          height: 1.4,
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

  static BoxDecoration sectionCardDecoration({double radius = 22}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassLine.withValues(alpha: 0.18)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.94),
          glassTint.withValues(alpha: 0.82),
          panel.withValues(alpha: 0.66),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: brandInk.withValues(alpha: 0.08),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.52),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  static BoxDecoration metricCardDecoration({required Color accent}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: 0.28)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.96),
          accent.withValues(alpha: 0.12),
          accent.withValues(alpha: 0.05),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration tileDecoration() {
    return BoxDecoration(
      borderRadius: tileRadius,
      border: Border.all(color: glassLine.withValues(alpha: 0.18)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.95),
          glassTint.withValues(alpha: 0.82),
          panel.withValues(alpha: 0.64),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: brandInk.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7F2FF), Color(0xFFEDE1FF), Color(0xFFE7D7FF)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E1463), Color(0xFF6A38F2), Color(0xFFA86BFF)],
  );
}
