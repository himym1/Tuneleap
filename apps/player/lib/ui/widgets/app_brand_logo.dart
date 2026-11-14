import 'package:flutter/material.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

/// 应用品牌图标 — 与桌面/移动端桌面图标一致
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 34,
    this.borderRadius = 10,
    this.shadowBlur = 12,
  });

  final double size;
  final double borderRadius;
  final double shadowBlur;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.32),
            blurRadius: shadowBlur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primary, colors.secondary],
                  ),
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: colors.onEmphasis,
                  size: size * 0.56,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 0.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
