import 'package:flutter/material.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';

/// Reusable stat card used by Downloads, Scrobble, and other dashboard pages.
///
/// Must be placed inside a [Row] (desktop) or [Column] (mobile) — the card
/// wraps itself in [Expanded] so the parent distributes space evenly.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: AppDimensions.iconBoxSize,
              height: AppDimensions.iconBoxSize,
              decoration: BoxDecoration(
                color: colors.primarySoftAlt,
                borderRadius:
                    BorderRadius.circular(AppDimensions.iconBoxRadius),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.statValue
                        .copyWith(color: theme.colorScheme.onSurface),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.songSubtitle
                        .copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
