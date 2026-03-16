import 'package:flutter/material.dart';

import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';

class AppColors {
  // ── Brand / semantic tokens (from JSON) ──
  static late Color primary;
  static late Color secondary;
  static late Color accent;
  static late Color success;
  static late Color error;
  static late Color onEmphasis;
  static late Color onEmphasisMuted;
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
    error = palette.error;
    onEmphasis = palette.onEmphasis;
    onEmphasisMuted = palette.onEmphasisMuted;
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
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.secondary,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        color: base.colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: BorderSide(color: base.colorScheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          borderSide: BorderSide(color: base.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          borderSide: BorderSide(color: base.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.scrollbarThumbHover;
          }
          return AppColors.scrollbarThumb;
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        crossAxisMargin: 2,
      ),
      extensions: [AppSemanticColors._fromScheme(base.colorScheme)],
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.secondary,
      brightness: Brightness.dark,
      fontFamily: 'Poppins',
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        color: base.colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: BorderSide(color: base.colorScheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          borderSide: BorderSide(color: base.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          borderSide: BorderSide(color: base.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        thumbColor: AppColors.accent,
        inactiveTrackColor: base.colorScheme.surfaceContainerHighest,
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
        trackColor: WidgetStateProperty.all(Colors.transparent),
        crossAxisMargin: 2,
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
        ),
      ),
      extensions: [AppSemanticColors._fromScheme(base.colorScheme)],
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

  // ── Stats / values ──
  TextStyle get statValue =>
      const TextStyle(fontSize: 20, fontWeight: FontWeight.w700);

  TextStyle get segmentLabel =>
      const TextStyle(fontSize: 12);

  // ── Song list items ──
  TextStyle get songTitle =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

  TextStyle get songSubtitle =>
      const TextStyle(fontSize: 12);

  TextStyle get songDuration =>
      const TextStyle(fontSize: 12);

  // ── Player-specific ──
  TextStyle get playerSongName =>
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  TextStyle get playerLargeSongName =>
      const TextStyle(fontSize: 24, fontWeight: FontWeight.w700);

  TextStyle get playerMediumTitle =>
      const TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

  TextStyle get playerQueueHeader =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  TextStyle get playerTimestamp =>
      const TextStyle(fontSize: 12);

  TextStyle get playerSubtitle =>
      const TextStyle(fontSize: 14);

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

// ── ThemeExtension: semantic colors accessible via context.colors ──

class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color success;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color onBackground;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color error;
  final Color onEmphasis;
  final Color onEmphasisMuted;
  final Color shadowSoft;
  final Color shadowStrong;
  final Color primarySoft;
  final Color primarySoftAlt;
  final Color primarySoftSubtle;
  final Color errorSoft;
  final Color navigationIndicator;

  const AppSemanticColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.success,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.onBackground,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.error,
    required this.onEmphasis,
    required this.onEmphasisMuted,
    required this.shadowSoft,
    required this.shadowStrong,
    required this.primarySoft,
    required this.primarySoftAlt,
    required this.primarySoftSubtle,
    required this.errorSoft,
    required this.navigationIndicator,
  });

  /// Brand tokens from AppColors + surface/on* from Material ColorScheme.
  factory AppSemanticColors._fromScheme(ColorScheme scheme) =>
      AppSemanticColors(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        accent: AppColors.accent,
        success: AppColors.success,
        background: scheme.surface,
        surface: scheme.surfaceContainerLow,
        surfaceContainer: scheme.surfaceContainerHigh,
        onBackground: scheme.onSurface,
        onSurface: scheme.onSurface,
        onSurfaceVariant: scheme.onSurfaceVariant,
        error: AppColors.error,
        onEmphasis: AppColors.onEmphasis,
        onEmphasisMuted: AppColors.onEmphasisMuted,
        shadowSoft: AppColors.shadowSoft,
        shadowStrong: AppColors.shadowStrong,
        primarySoft: AppColors.primarySoft,
        primarySoftAlt: AppColors.primarySoftAlt,
        primarySoftSubtle: AppColors.primarySoftSubtle,
        errorSoft: AppColors.errorSoft,
        navigationIndicator: AppColors.navigationIndicator,
      );

  @override
  AppSemanticColors copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? success,
    Color? background,
    Color? surface,
    Color? surfaceContainer,
    Color? onBackground,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? error,
    Color? onEmphasis,
    Color? onEmphasisMuted,
    Color? shadowSoft,
    Color? shadowStrong,
    Color? primarySoft,
    Color? primarySoftAlt,
    Color? primarySoftSubtle,
    Color? errorSoft,
    Color? navigationIndicator,
  }) {
    return AppSemanticColors(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      onBackground: onBackground ?? this.onBackground,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      error: error ?? this.error,
      onEmphasis: onEmphasis ?? this.onEmphasis,
      onEmphasisMuted: onEmphasisMuted ?? this.onEmphasisMuted,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowStrong: shadowStrong ?? this.shadowStrong,
      primarySoft: primarySoft ?? this.primarySoft,
      primarySoftAlt: primarySoftAlt ?? this.primarySoftAlt,
      primarySoftSubtle: primarySoftSubtle ?? this.primarySoftSubtle,
      errorSoft: errorSoft ?? this.errorSoft,
      navigationIndicator: navigationIndicator ?? this.navigationIndicator,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      error: Color.lerp(error, other.error, t)!,
      onEmphasis: Color.lerp(onEmphasis, other.onEmphasis, t)!,
      onEmphasisMuted: Color.lerp(onEmphasisMuted, other.onEmphasisMuted, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
      shadowStrong: Color.lerp(shadowStrong, other.shadowStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primarySoftAlt: Color.lerp(primarySoftAlt, other.primarySoftAlt, t)!,
      primarySoftSubtle: Color.lerp(primarySoftSubtle, other.primarySoftSubtle, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      navigationIndicator: Color.lerp(navigationIndicator, other.navigationIndicator, t)!,
    );
  }
}

extension AppColorsExtension on BuildContext {
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
