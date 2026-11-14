import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

/// 统一的页面内嵌返回按钮，保证最小点击热区与视觉一致性
class PageBackButton extends StatelessWidget {
  const PageBackButton({
    super.key,
    this.fallbackRoute = '/home',
    this.onTap,
    this.compact = false,
  });

  final String fallbackRoute;
  final VoidCallback? onTap;
  final bool compact;

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (compact) {
      return IconButton(
        tooltip: s.tooltipBack,
        icon: const Icon(Icons.arrow_back_rounded, size: 22),
        onPressed: () => _handleTap(context),
      );
    }
    return Semantics(
      button: true,
      label: s.tooltipBack,
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  s.commonBack,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
