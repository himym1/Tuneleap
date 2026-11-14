import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

/// 歌曲列表加载骨架屏
class SongListSkeleton extends StatelessWidget {
  const SongListSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding,
    this.showCover = true,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final EdgeInsetsGeometry? padding;
  final bool showCover;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.cardSurface,
              borderRadius: BorderRadius.circular(
                AppDimensions.cardRadiusSmall,
              ),
              border: Border.all(
                color: context.colors.hairlineBorder,
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                if (showCover) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 13,
                        width: index.isEven ? 160 : 130,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        height: 10,
                        width: index.isEven ? 110 : 140,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 34,
                  height: 11,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerHigh,
      child: shrinkWrap
          ? Padding(padding: padding ?? EdgeInsets.zero, child: child)
          : ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: padding ?? EdgeInsets.zero,
              children: [child],
            ),
    );
  }
}

/// 专辑/封面网格加载骨架屏
class AlbumGridSkeleton extends StatelessWidget {
  const AlbumGridSkeleton({super.key, this.itemCount = 8, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);
        final h = isMobile
            ? AppDimensions.paddingMobile
            : AppDimensions.paddingDesktop;
        final crossAxisCount =
            (constraints.maxWidth / AppDimensions.albumGridColumnWidth)
                .floor()
                .clamp(2, 6);
        return Shimmer.fromColors(
          baseColor: scheme.surfaceContainerHighest,
          highlightColor: scheme.surfaceContainerHigh,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding ?? EdgeInsets.fromLTRB(h, 8, h, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.78,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: itemCount,
            itemBuilder: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 13,
                  width: 110,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 11,
                  width: 72,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 歌单列表/网格加载骨架屏
class PlaylistGridSkeleton extends StatelessWidget {
  const PlaylistGridSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);
        if (isMobile) {
          return SongListSkeleton(
            itemCount: itemCount,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMobile,
              vertical: 8,
            ),
          );
        }
        final crossAxisCount = (constraints.maxWidth / 260).floor().clamp(2, 5);
        return Shimmer.fromColors(
          baseColor: scheme.surfaceContainerHighest,
          highlightColor: scheme.surfaceContainerHigh,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingDesktop,
              vertical: 8,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.3,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: itemCount,
            itemBuilder: (_, _) => Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              ),
            ),
          ),
        );
      },
    );
  }
}
