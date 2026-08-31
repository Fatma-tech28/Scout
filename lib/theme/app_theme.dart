import 'package:flutter/material.dart';

/// Central color system for the app — light theme.
///
/// The "brand blues" are the exact palette supplied by the client
/// (F0F3FA -> 395886), used across gauges, chart fills and now the app
/// shell itself. Turquoise and pink remain the accent colors for the
/// control page, tuned for contrast against light surfaces.
class AppColors {
  AppColors._();

  // --- Brand blue ramp (lightest -> darkest) ---
  static const Color blue50 = Color(0xFFF0F3FA);
  static const Color blue100 = Color(0xFFD5DEEF);
  static const Color blue200 = Color(0xFFB1C9EF);
  static const Color blue300 = Color(0xFF8AAEE0);
  static const Color blue400 = Color(0xFF628ECB);
  static const Color blue500 = Color(0xFF395886);

  // --- Light shell ---
  static const Color background = Color(0xFFF4F7FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFF0F3FA);
  static const Color surfaceOutline = Color(0xFFDDE4F1);

  // --- Accents (deepened slightly for AA contrast on white) ---
  static const Color turquoise = Color(0xFF0FA394);
  static const Color turquoiseDim = Color(0xFFCFF3EE);
  static const Color pink = Color(0xFFE0227A);
  static const Color pinkDim = Color(0xFFFBDCEA);

  // --- Status ---
  static const Color danger = Color(0xFFE0293F);
  static const Color warning = Color(0xFFC97A00);
  static const Color success = Color(0xFF15A46E);

  // --- Text ---
  static const Color textPrimary = Color(0xFF1E2740);
  static const Color textSecondary = Color(0xFF64708C);
  static const Color textOnLight = Color(0xFF1E2740);

  static const List<Color> gaugeGradient = [blue200, blue300, blue400, blue500];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        primary: AppColors.turquoise,
        secondary: AppColors.pink,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamily: 'Roboto',
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.turquoise,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
