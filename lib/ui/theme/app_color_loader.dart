import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

class AppColorPalette {
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
  final Color transparent;
  final Color shadowSoft;
  final Color shadowStrong;
  final Color primarySoft;
  final Color primarySoftAlt;
  final Color primarySoftSubtle;
  final Color errorSoft;
  final Color scrollbarThumbHover;
  final Color scrollbarThumb;
  final Color navigationIndicator;
  final Color scrollbarThumbDarkHover;
  final Color scrollbarThumbDark;

  const AppColorPalette({
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
    required this.transparent,
    required this.shadowSoft,
    required this.shadowStrong,
    required this.primarySoft,
    required this.primarySoftAlt,
    required this.primarySoftSubtle,
    required this.errorSoft,
    required this.scrollbarThumbHover,
    required this.scrollbarThumb,
    required this.navigationIndicator,
    required this.scrollbarThumbDarkHover,
    required this.scrollbarThumbDark,
  });

  factory AppColorPalette.fromJson(Map<String, dynamic> json) {
    return AppColorPalette(
      primary: _parseColor(json['primary'] as String),
      secondary: _parseColor(json['secondary'] as String),
      accent: _parseColor(json['accent'] as String),
      success: _parseColor(json['success'] as String),
      background: _parseColor(json['background'] as String),
      surface: _parseColor(json['surface'] as String),
      surfaceContainer: _parseColor(json['surfaceContainer'] as String),
      onBackground: _parseColor(json['onBackground'] as String),
      onSurface: _parseColor(json['onSurface'] as String),
      onSurfaceVariant: _parseColor(json['onSurfaceVariant'] as String),
      error: _parseColor(json['error'] as String),
      onEmphasis: _parseColor(json['onEmphasis'] as String),
      onEmphasisMuted: _parseColor(json['onEmphasisMuted'] as String),
      transparent: _parseColor(json['transparent'] as String),
      shadowSoft: _parseColor(json['shadowSoft'] as String),
      shadowStrong: _parseColor(json['shadowStrong'] as String),
      primarySoft: _parseColor(json['primarySoft'] as String),
      primarySoftAlt: _parseColor(json['primarySoftAlt'] as String),
      primarySoftSubtle: _parseColor(json['primarySoftSubtle'] as String),
      errorSoft: _parseColor(json['errorSoft'] as String),
      scrollbarThumbHover: _parseColor(json['scrollbarThumbHover'] as String),
      scrollbarThumb: _parseColor(json['scrollbarThumb'] as String),
      navigationIndicator: _parseColor(json['navigationIndicator'] as String),
      scrollbarThumbDarkHover: _parseColor(
        json['scrollbarThumbDarkHover'] as String,
      ),
      scrollbarThumbDark: _parseColor(json['scrollbarThumbDark'] as String),
    );
  }

  static Color _parseColor(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final buffer = StringBuffer();
    if (normalized.length == 6) {
      buffer.write('ff');
    }
    buffer.write(normalized);
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

Future<void> initializeAppColors() async {
  final rawJson = await rootBundle.loadString('assets/theme/app_colors.json');
  final jsonMap = jsonDecode(rawJson) as Map<String, dynamic>;
  AppColors.configure(AppColorPalette.fromJson(jsonMap));
}
