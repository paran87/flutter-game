import 'package:flutter/material.dart';

/// Shared palette. Gameplay colours are chosen to stay distinguishable for
/// common colour-vision deficiencies (ballpoint blue vs. vermilion red, also
/// differing in lightness) and are always paired with a label or shape.
abstract final class AppColors {
  static const paper = Color(0xFFF7F2E8);
  static const paperShade = Color(0xFFEDE5D5);
  static const paperEdge = Color(0xFFE2D8C4);
  static const ink = Color(0xFF1E1C1A);
  static const inkSoft = Color(0xFF4A4640);
  static const inkFaint = Color(0xFF8C857A);
  static const card = Color(0xFFFFFCF6);

  /// Player 1 — ballpoint blue.
  static const p1 = Color(0xFF1D4ED8);
  static const p1Light = Color(0xFFDCE6FF);

  /// Player 2 — vermilion red.
  static const p2 = Color(0xFFD7263D);
  static const p2Light = Color(0xFFFFDDE1);

  static const penalty = Color(0xFFC2410C);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const gold = Color(0xFFE0A526);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const pill = 999.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.p1,
    brightness: Brightness.light,
    surface: AppColors.paper,
  ).copyWith(primary: AppColors.ink, onPrimary: AppColors.paper);

  const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
      color: AppColors.ink,
      height: 1,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: AppColors.inkSoft),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: AppColors.inkSoft),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: AppColors.ink,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: AppColors.inkFaint,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: AppColors.ink,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.paper
            : AppColors.inkFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.p1
            : AppColors.paperShade,
      ),
    ),
  );
}
