import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1E1B4B);
  static const secondary = Color(0xFF4338CA);
  static const accent = Color(0xFF22C55E);
  static const background = Color(0xFF0F0F23);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceContainer = Color(0xFF252540);
  static const onBackground = Color(0xFFF8FAFC);
  static const onSurface = Color(0xFFE2E8F0);
  static const onSurfaceVariant = Color(0xFF94A3B8);
  static const error = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.secondary,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.dark(
      primary: AppColors.secondary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.onBackground,
      onSecondary: AppColors.background,
      onSurface: AppColors.onSurface,
      onError: AppColors.onBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Poppins',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.secondary.withValues(alpha: 0.3),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.secondary.withValues(alpha: 0.3),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        thumbColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceContainer,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.onSurface),
      ),
    );
  }
}
