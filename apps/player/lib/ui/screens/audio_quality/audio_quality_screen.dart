import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (AppBreakpoints.isMobile(MediaQuery.of(context).size.width))
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.go('/settings'),
                ),
              Text(
                S.of(context).settingsAudioQuality,
                style: Theme.of(context).textTheme.pageTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
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
          const SizedBox(height: 28),

          // ── 音质选择 ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
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
                    Text(
                      S.of(context).audioQualitySelection,
                      style: Theme.of(context).textTheme.settingsSectionTitle,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(qualities.length, (i) {
                    final q = qualities[i];
                    final selected = currentQuality == q.maxBitRate;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        label: q.name,
                        selected: selected,
                        child: InkWell(
                          onTap: () => ref
                              .read(audioQualityProvider.notifier)
                              .setQuality(q.maxBitRate),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: EdgeInsets.only(
                              right: i < qualities.length - 1 ? 10 : 0,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? context.colors.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
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
                      ),
                    );
                  }),
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
