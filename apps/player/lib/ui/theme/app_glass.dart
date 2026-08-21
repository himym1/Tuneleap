import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

/// Reusable glassmorphic, ambient glow, and micro-elevation utilities.
abstract final class AppGlass {
  /// Frosted glass decoration with subtle specular border highlight.
  static BoxDecoration frostedDecoration(
    BuildContext context, {
    Color? tintColor,
    double opacity = 0.72,
    double borderRadius = AppDimensions.cardRadius,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final baseColor = tintColor ?? surfaceColor;

    return BoxDecoration(
      color: baseColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border:
          border ??
          Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: isDark ? 0.10 : 0.06,
            ),
            width: 0.8,
          ),
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: (isDark ? Colors.black : context.colors.shadowStrong)
                  .withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
    );
  }

  /// Ambient colored shadow matching cover artwork or accent.
  static List<BoxShadow> coverShadow(
    Color accentColor, {
    double blur = 32,
    double spread = 2,
    Offset offset = const Offset(0, 12),
    double alpha = 0.35,
  }) {
    return [
      BoxShadow(
        color: accentColor.withValues(alpha: alpha),
        blurRadius: blur,
        spreadRadius: spread,
        offset: offset,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.20),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

/// Frosted Glass container with BackdropFilter and specular edge highlight.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.borderRadius = AppDimensions.cardRadius,
    this.tintColor,
    this.opacity = 0.72,
    this.border,
    this.boxShadow,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final double blur;
  final double borderRadius;
  final Color? tintColor;
  final double opacity;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: AppGlass.frostedDecoration(
            context,
            tintColor: tintColor,
            opacity: opacity,
            borderRadius: borderRadius,
            border: border,
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ambient fluid aurora backdrop for player and hero banners.
class AmbientAuroraBackdrop extends StatelessWidget {
  const AmbientAuroraBackdrop({
    super.key,
    required this.accentColor,
    this.secondaryAccent,
    required this.child,
  });

  final Color accentColor;
  final Color? secondaryAccent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sec = secondaryAccent ?? accentColor.withValues(alpha: 0.7);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base surface
        Container(color: surface),
        // Glow orb 1 (top center / left)
        Positioned(
          top: -100,
          left: -60,
          right: -60,
          height: 450,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.4),
                  radius: 0.85,
                  colors: [
                    accentColor.withValues(alpha: isDark ? 0.38 : 0.22),
                    accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Glow orb 2 (center right / bottom)
        Positioned(
          top: 200,
          right: -100,
          bottom: 0,
          width: 360,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, 0.2),
                  radius: 0.75,
                  colors: [
                    sec.withValues(alpha: isDark ? 0.24 : 0.14),
                    sec.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Smooth diffusion overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: const SizedBox.expand(),
        ),
        // Foreground content
        child,
      ],
    );
  }
}

/// Apple-style pill badge for audio formats and tags.
class AudioFormatBadge extends StatelessWidget {
  const AudioFormatBadge({
    super.key,
    required this.label,
    this.icon,
    this.primary = false,
  });

  final String label;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = primary
        ? context.colors.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.08 : 0.05,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.12 : 0.08,
          ),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
