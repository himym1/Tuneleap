import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

/// An Apple Music / macOS Sonoma styled segmented control.
/// Features a frosted translucent chassis, elevated floating selection thumb,
/// delicate specular rim borders, and smooth spring animations.
class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final double height;
  final bool isExpanded;

  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.height = 42,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.08 : 0.05,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.10 : 0.07,
          ),
          width: 0.8,
        ),
      ),
      child: isExpanded
          ? Row(
              children: [
                for (final item in items)
                  Expanded(child: _buildItem(context, item, isDark)),
              ],
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 3),
              itemBuilder: (context, index) =>
                  _buildItem(context, items[index], isDark),
            ),
    );
  }

  Widget _buildItem(BuildContext context, AppSegmentItem<T> item, bool isDark) {
    final isSelected = item.value == selected;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(item.value);
          },
          borderRadius: BorderRadius.circular(8.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8.5),
              border: isSelected
                  ? Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: isDark ? 0.18 : 0.06,
                      ),
                      width: 0.8,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.40 : 0.10,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.20 : 0.04,
                        ),
                        blurRadius: 1.5,
                        offset: const Offset(0, 0.5),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 16,
                      color: isSelected
                          ? (isDark ? Colors.white : context.colors.primary)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                        color: isSelected
                            ? (isDark
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface)
                            : Theme.of(context).colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  if (item.badge != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colors.primary.withValues(alpha: 0.16)
                            : (isDark ? Colors.white : Colors.black).withValues(
                                alpha: 0.08,
                              ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badge!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? context.colors.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? badge;

  const AppSegmentItem({
    required this.value,
    required this.label,
    this.icon,
    this.badge,
  });
}
