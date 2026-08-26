import 'package:flutter/material.dart';

import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/utils/cover_color.dart';

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
  static ColorScheme _schemeFromSeed({
    required Color seed,
    required Brightness brightness,
    required bool fromCover,
  }) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: fromCover
          ? coverSchemeVariant(seed)
          : DynamicSchemeVariant.tonalSpot,
    );
  }

  static ThemeData light({Color? seedColor}) {
    final useSchemeBrand = seedColor != null;
    final scheme = _schemeFromSeed(
      seed: seedColor ?? AppColors.secondary,
      brightness: Brightness.light,
      fromCover: useSchemeBrand,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
    );
    final primary = useSchemeBrand
        ? base.colorScheme.primary
        : AppColors.primary;
    return base.copyWith(
      cardTheme: CardThemeData(
        color: base.colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: BorderSide(
            color: base.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 2,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          side: BorderSide(
            color: base.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
        fillColor:
            (useSchemeBrand
                    ? base.colorScheme.surfaceContainerHigh
                    : const Color(0xFFF2F2F7))
                .withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        prefixIconColor: base.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.7,
        ),
        suffixIconColor: base.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.7,
        ),
        hintStyle: TextStyle(
          color: base.colorScheme.onSurfaceVariant.withValues(alpha: 0.60),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: base.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.8,
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primary, width: 3),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: base.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: base.colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: base.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: base.colorScheme.surfaceContainerHighest,
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
      extensions: [
        AppSemanticColors._fromScheme(
          base.colorScheme,
          useSchemeBrand: useSchemeBrand,
        ),
      ],
    );
  }

  static ThemeData dark({Color? seedColor, bool amoled = false}) {
    final useSchemeBrand = seedColor != null;
    final generated = _schemeFromSeed(
      seed: seedColor ?? AppColors.secondary,
      brightness: Brightness.dark,
      fromCover: useSchemeBrand,
    );
    final scheme = amoled
        ? generated.copyWith(
            surface: Colors.black,
            surfaceDim: Colors.black,
            surfaceBright: const Color(0xFF242424),
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: const Color(0xFF050505),
            surfaceContainer: const Color(0xFF0A0A0A),
            surfaceContainerHigh: const Color(0xFF111111),
            surfaceContainerHighest: const Color(0xFF1A1A1A),
          )
        : generated;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Poppins',
    );
    final primary = useSchemeBrand ? scheme.primary : AppColors.primary;
    final accent = useSchemeBrand ? scheme.tertiary : AppColors.accent;
    return base.copyWith(
      cardTheme: CardThemeData(
        color: base.colorScheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: BorderSide(
            color: base.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 2,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          side: BorderSide(
            color: base.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
        fillColor: amoled
            ? const Color(0xFF141414)
            : Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        prefixIconColor: base.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.7,
        ),
        suffixIconColor: base.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.7,
        ),
        hintStyle: TextStyle(
          color: base.colorScheme.onSurfaceVariant.withValues(alpha: 0.60),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: base.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.8,
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: -0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primary, width: 3),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
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
      extensions: [
        AppSemanticColors._fromScheme(
          base.colorScheme,
          useSchemeBrand: useSchemeBrand,
        ),
      ],
    );
  }
}

extension AppTextStyles on TextTheme {
  // ── Page-level ──
  TextStyle get pageTitle => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );

  TextStyle get sectionTitle => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  TextStyle get sectionSubheader => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  TextStyle get chipLabel => const TextStyle(fontSize: 13);

  // ── Stats / values ──
  TextStyle get statValue => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  TextStyle get segmentLabel => const TextStyle(fontSize: 12);

  // ── Song list items ──
  TextStyle get songTitle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  TextStyle get songSubtitle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  TextStyle get songDuration => const TextStyle(
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── Player-specific ──
  TextStyle get playerSongName => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  TextStyle get playerLargeSongName => const TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  TextStyle get playerMediumTitle => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  TextStyle get playerQueueHeader => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  TextStyle get playerTimestamp => const TextStyle(
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  TextStyle get playerSubtitle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  // ── Settings (kept for backward compat) ──
  TextStyle get settingsPageTitle => pageTitle;

  TextStyle get settingsSectionTitle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  TextStyle get settingsSectionSubtitle =>
      const TextStyle(fontSize: 13, height: 1.5);

  TextStyle get settingsVersionLabel => const TextStyle(fontSize: 13);

  // ── Mini player compact slider ──
  static SliderThemeData miniSliderTheme(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliderThemeData(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
    );
  }
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

  /// Brand tokens from AppColors, or generated scheme colors for dynamic mode.
  factory AppSemanticColors._fromScheme(
    ColorScheme scheme, {
    bool useSchemeBrand = false,
  }) {
    return AppSemanticColors(
      primary: useSchemeBrand ? scheme.primary : AppColors.primary,
      secondary: useSchemeBrand ? scheme.secondary : AppColors.secondary,
      accent: useSchemeBrand ? scheme.tertiary : AppColors.accent,
      success: AppColors.success,
      background: scheme.surface,
      surface: scheme.surfaceContainerLow,
      surfaceContainer: scheme.surfaceContainerHigh,
      onBackground: scheme.onSurface,
      onSurface: scheme.onSurface,
      onSurfaceVariant: scheme.onSurfaceVariant,
      error: AppColors.error,
      onEmphasis: useSchemeBrand ? scheme.onPrimary : AppColors.onEmphasis,
      onEmphasisMuted: useSchemeBrand
          ? scheme.onPrimary.withValues(alpha: 0.70)
          : AppColors.onEmphasisMuted,
      shadowSoft: AppColors.shadowSoft,
      shadowStrong: AppColors.shadowStrong,
      primarySoft: useSchemeBrand
          ? scheme.primary.withValues(alpha: 0.10)
          : AppColors.primarySoft,
      primarySoftAlt: useSchemeBrand
          ? scheme.primary.withValues(alpha: 0.08)
          : AppColors.primarySoftAlt,
      primarySoftSubtle: useSchemeBrand
          ? scheme.primary.withValues(alpha: 0.06)
          : AppColors.primarySoftSubtle,
      errorSoft: AppColors.errorSoft,
      navigationIndicator: useSchemeBrand
          ? scheme.primaryContainer
          : AppColors.navigationIndicator,
    );
  }

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
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      onEmphasis: Color.lerp(onEmphasis, other.onEmphasis, t)!,
      onEmphasisMuted: Color.lerp(onEmphasisMuted, other.onEmphasisMuted, t)!,
      shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
      shadowStrong: Color.lerp(shadowStrong, other.shadowStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primarySoftAlt: Color.lerp(primarySoftAlt, other.primarySoftAlt, t)!,
      primarySoftSubtle: Color.lerp(
        primarySoftSubtle,
        other.primarySoftSubtle,
        t,
      )!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      navigationIndicator: Color.lerp(
        navigationIndicator,
        other.navigationIndicator,
        t,
      )!,
    );
  }
}

extension AppColorsExtension on BuildContext {
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
