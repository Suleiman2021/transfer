import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';

class AppTheme {
  static const Color brandInk = AppThemeTokens.ink;
  static const Color brandTeal = AppThemeTokens.primary;
  static const Color brandCoral = AppThemeTokens.blue;
  static const Color brandPlum = AppThemeTokens.violet;
  static const Color brandGold = AppThemeTokens.amber;
  static const Color brandSky = AppThemeTokens.mint;
  static const Color panel = AppThemeTokens.canvas;
  static const Color textDark = AppThemeTokens.ink;
  static const Color textMuted = AppThemeTokens.inkSoft;
  static const Color textSoft = AppThemeTokens.inkMuted;
  static const Color glassTint = AppThemeTokens.surfaceAlt;
  static const Color glassLine = AppThemeTokens.line;
  static const Color noticeSuccess = AppThemeTokens.primary;
  static const Color noticeError = AppThemeTokens.red;
  static const Color noticeWarning = AppThemeTokens.amber;
  static const BorderRadius snackRadius = BorderRadius.all(
    Radius.circular(AppThemeTokens.radiusSm),
  );
  static const BorderRadius panelRadius = BorderRadius.all(
    Radius.circular(AppThemeTokens.radiusSm),
  );
  static const BorderRadius tileRadius = BorderRadius.all(
    Radius.circular(AppThemeTokens.radiusSm),
  );

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brandTeal,
          brightness: Brightness.light,
        ).copyWith(
          primary: brandTeal,
          secondary: brandCoral,
          tertiary: brandGold,
          surface: Colors.white,
          surfaceContainerHighest: AppThemeTokens.surfaceAlt,
          onSurface: textDark,
          error: noticeError,
        );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: scheme,
    );

    return base.copyWith(
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
        backgroundColor: textDark,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        shape: const RoundedRectangleBorder(borderRadius: snackRadius),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: panelRadius,
          side: const BorderSide(color: glassLine),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.radiusMd),
          side: const BorderSide(color: glassLine),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppThemeTokens.radiusLg),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: brandSky,
        surfaceTintColor: Colors.transparent,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Cairo',
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: selected ? 12.2 : 12,
            color: selected ? textDark : textMuted,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 13.2,
        ),
        hintStyle: const TextStyle(
          color: textSoft,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          color: noticeError,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.25,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          borderSide: const BorderSide(color: glassLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          borderSide: const BorderSide(color: glassLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          borderSide: const BorderSide(color: brandTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          borderSide: const BorderSide(color: noticeError, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          borderSide: const BorderSide(color: noticeError, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandTeal,
          foregroundColor: textDark,
          elevation: 0,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandInk,
          side: const BorderSide(color: glassLine),
          minimumSize: const Size.fromHeight(42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(42),
          backgroundColor: brandSky,
          foregroundColor: brandInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: brandSky,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        side: const BorderSide(color: glassLine),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
        ),
      ),
      dividerTheme: const DividerThemeData(color: glassLine),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          side: const WidgetStatePropertyAll(BorderSide(color: glassLine)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
            ),
          ),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.18,
        ),
        headlineMedium: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.25,
        ),
        titleMedium: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.27,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: textDark,
          height: 1.27,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          color: textDark,
          height: 1.42,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: textDark,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: const TextStyle(
          fontSize: 12.5,
          color: textMuted,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1.2,
        ),
        labelMedium: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1.2,
        ),
      ),
    );
  }

  static BoxDecoration sectionCardDecoration({double radius = 8}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassLine),
      boxShadow: [
        BoxShadow(
          color: brandInk.withValues(alpha: 0.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration metricCardDecoration({required Color accent}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppThemeTokens.radiusSm),
      border: Border.all(color: accent.withValues(alpha: 0.22)),
      boxShadow: [
        BoxShadow(
          color: brandInk.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  static BoxDecoration tileDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: tileRadius,
      border: Border.all(color: glassLine),
      boxShadow: [
        BoxShadow(
          color: brandInk.withValues(alpha: 0.035),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF7EF), Color(0xFFFFF3E8), Color(0xFFFFE9D6)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A1A), Color(0xFFFF9F2E), Color(0xFFFFC266)],
  );
}
