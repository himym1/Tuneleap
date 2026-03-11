import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).settingsAudioQuality,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
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
                style: TextStyle(
                  fontSize: 13,
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
                      Icons.high_quality,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context).audioQualitySelection,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(qualities.length, (i) {
                    final q = qualities[i];
                    final selected = currentQuality == q.maxBitRate;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => ref
                            .read(audioQualityProvider.notifier)
                            .setQuality(q.maxBitRate),
                        child: Container(
                          margin: EdgeInsets.only(
                            right: i < qualities.length - 1 ? 10 : 0,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
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
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.onEmphasis
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                q.desc,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: selected
                                      ? AppColors.onEmphasisMuted
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
