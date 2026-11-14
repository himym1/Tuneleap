import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 音质设置页面
class AudioQualityScreen extends ConsumerWidget {
  const AudioQualityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentQuality = ref.watch(audioQualityProvider);

    final qualities = [
      _QualityOption(
        name: S.of(context).audioQualityOriginalName,
        desc: S.of(context).audioQualityOriginalDesc,
        maxBitRate: 0,
      ),
      _QualityOption(
        name: S.of(context).audioQualityMp3Label(128),
        desc: S.of(context).audioQualityMp3128Desc,
        maxBitRate: 128,
      ),
      _QualityOption(
        name: S.of(context).audioQualityMp3Label(320),
        desc: S.of(context).audioQualityHigh,
        maxBitRate: 320,
      ),
    ];

    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final v = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return ResponsivePageScaffold(
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: v),
        children: [
          Row(
            children: [
              if (isMobile)
                IconButton(
                  tooltip: S.of(context).tooltipBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  onPressed: () => context.go('/settings'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              Expanded(
                child: Text(
                  S.of(context).settingsAudioQuality,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.pageTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                qualities
                    .firstWhere(
                      (q) => q.maxBitRate == currentQuality,
                      orElse: () => qualities[0],
                    )
                    .name,
                style: Theme.of(context).textTheme.chipLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 音质选择 ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.cardSurface,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              border: Border.all(
                color: context.colors.hairlineBorder,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.high_quality_rounded,
                      size: 18,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.of(context).audioQualitySelection,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.settingsSectionTitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final vertical = constraints.maxWidth < 460;
                    Widget buildCard(_QualityOption q) {
                      final selected = currentQuality == q.maxBitRate;
                      return Semantics(
                        button: true,
                        label: q.name,
                        selected: selected,
                        child: InkWell(
                          onTap: () => ref
                              .read(audioQualityProvider.notifier)
                              .setQuality(q.maxBitRate),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: vertical ? double.infinity : null,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? context.colors.primary
                                  : context.colors.subtleSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: context.colors.hairlineBorder,
                                      width: 0.8,
                                    ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.name,
                                  style: Theme.of(context).textTheme.chipLabel
                                      .copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? context.colors.onEmphasis
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  q.desc,
                                  style: Theme.of(context)
                                      .textTheme
                                      .songSubtitle
                                      .copyWith(
                                        fontSize: 11,
                                        color: selected
                                            ? context.colors.onEmphasisMuted
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (vertical) {
                      return Column(
                        children: [
                          for (var i = 0; i < qualities.length; i++) ...[
                            buildCard(qualities[i]),
                            if (i < qualities.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: List.generate(qualities.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i < qualities.length - 1 ? 10 : 0,
                            ),
                            child: buildCard(qualities[i]),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityOption {
  final String name;
  final String desc;
  final int maxBitRate;
  const _QualityOption({
    required this.name,
    required this.desc,
    required this.maxBitRate,
  });
}
