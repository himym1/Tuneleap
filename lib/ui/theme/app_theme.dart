import 'package:flutter/material.dart';

import 'package:navidrome_player/ui/theme/app_color_loader.dart';

class AppColors {
  static late Color primary;
  static late Color secondary;
  static late Color accent;
  static late Color success;
  static late Color background;
  static late Color surface;
  static late Color surfaceContainer;
  static late Color onBackground;
  static late Color onSurface;
  static late Color onSurfaceVariant;
  static late Color error;
  static late Color onEmphasis;
  static late Color onEmphasisMuted;
  static late Color transparent;
  static late Color shadowSoft;
  static late Color shadowStrong;
  static late Color primarySoft;
  static late Color primarySoftAlt;
  static late Color primarySoftSubtle;
  static late Color errorSoft;
  static late Color scrollbarThumbHover;
  static late Color scrollbarThumb;
  static late Color navigationIndicator;
  static late Color scrollbarThumbDarkHover;
  static late Color scrollbarThumbDark;

  static void configure(AppColorPalette palette) {
    primary = palette.primary;
    secondary = palette.secondary;
    accent = palette.accent;
    success = palette.success;
    background = palette.background;
    surface = palette.surface;
    surfaceContainer = palette.surfaceContainer;
    onBackground = palette.onBackground;
    onSurface = palette.onSurface;
    onSurfaceVariant = palette.onSurfaceVariant;
    error = palette.error;
    onEmphasis = palette.onEmphasis;
    onEmphasisMuted = palette.onEmphasisMuted;
    transparent = palette.transparent;
    shadowSoft = palette.shadowSoft;
    shadowStrong = palette.shadowStrong;
    primarySoft = palette.primarySoft;
    primarySoftAlt = palette.primarySoftAlt;
    primarySoftSubtle = palette.primarySoftSubtle;
    errorSoft = palette.errorSoft;
    scrollbarThumbHover = palette.scrollbarThumbHover;
    scrollbarThumb = palette.scrollbarThumb;
    navigationIndicator = palette.navigationIndicator;
    scrollbarThumbDarkHover = palette.scrollbarThumbDarkHover;
    scrollbarThumbDark = palette.scrollbarThumbDark;
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.secondary,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.scrollbarThumbHover;
          }
          return AppColors.scrollbarThumb;
        }),
        trackColor: WidgetStateProperty.all(AppColors.transparent),
        crossAxisMargin: 2,
      ),
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
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.navigationIndicator,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.navigationIndicator,
      ),
      cardTheme: CardThemeData(color: AppColors.surface),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        thumbColor: AppColors.accent,
        inactiveTrackColor: AppColors.surfaceContainer,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.scrollbarThumbDarkHover;
          }
          return AppColors.scrollbarThumbDark;
        }),
        trackColor: WidgetStateProperty.all(AppColors.transparent),
        crossAxisMargin: 2,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.onSurface),
      ),
    );
  }
}

extension AppTextStyles on TextTheme {
  // ── Page-level ──
  TextStyle get pageTitle =>
      const TextStyle(fontSize: 28, fontWeight: FontWeight.w700);

  TextStyle get sectionTitle =>
      const TextStyle(fontSize: 20, fontWeight: FontWeight.w600);

  TextStyle get sectionSubheader =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  TextStyle get chipLabel =>
      const TextStyle(fontSize: 13);

  // ── Song list items ──
  TextStyle get songTitle =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

  TextStyle get songSubtitle =>
      const TextStyle(fontSize: 12);

  TextStyle get songDuration =>
      const TextStyle(fontSize: 12);

  // ── Settings (kept for backward compat) ──
  TextStyle get settingsPageTitle => pageTitle;

  TextStyle get settingsSectionTitle =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  TextStyle get settingsSectionSubtitle =>
      const TextStyle(fontSize: 13, height: 1.5);

  TextStyle get settingsVersionLabel => const TextStyle(fontSize: 13);

  // ── Mini player compact slider ──
  static SliderThemeData miniSliderTheme(BuildContext context) =>
      SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      );
}
