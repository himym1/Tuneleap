import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/stat_card.dart';
import 'package:navidrome_player/utils/duration_format.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// Scrobble / 播放记录页面
class ScrobbleScreen extends ConsumerWidget {
  const ScrobbleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final recentSongs = playerService.playHistory;

    // 统计数据基于 history
    final todayCount = recentSongs.length; // 当前 session 播放数
    final client = ref.read(subsonicClientProvider);

    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.all(isMobile ? AppDimensions.paddingMobile : AppDimensions.paddingDesktop),
        children: [
          // 头部
          Text(
            S.of(context).navScrobble,
            style: Theme.of(context).textTheme.pageTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context).scrobbleSubtitle,
            style: Theme.of(context).textTheme.songSubtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // 统计卡片 — mobile 竖排，desktop 横排
          if (isMobile)
            Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Row(children: [
                    StatCard(
                      icon: Icons.play_arrow,
                      value: '$todayCount',
                      label: S.of(context).scrobbleSessionPlays,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: Row(children: [
                    StatCard(
                      icon: Icons.music_note,
                      value: recentSongs
                          .map((s) => s.artist)
                          .toSet()
                          .length
                          .toString(),
                      label: S.of(context).scrobbleUniqueArtists,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: Row(children: [
                    StatCard(
                      icon: Icons.album,
                      value: recentSongs
                          .map((s) => s.albumId)
                          .toSet()
                          .length
                          .toString(),
                      label: S.of(context).scrobbleUniqueAlbums,
                    ),
                  ]),
                ),
              ],
            )
          else
            Row(
              children: [
                StatCard(
                  icon: Icons.play_arrow,
                  value: '$todayCount',
                  label: S.of(context).scrobbleSessionPlays,
                ),
                const SizedBox(width: 16),
                StatCard(
                  icon: Icons.music_note,
                  value: recentSongs
                      .map((s) => s.artist)
                      .toSet()
                      .length
                      .toString(),
                  label: S.of(context).scrobbleUniqueArtists,
                ),
                const SizedBox(width: 16),
                StatCard(
                  icon: Icons.album,
                  value: recentSongs
                      .map((s) => s.albumId)
                      .toSet()
                      .length
                      .toString(),
                  label: S.of(context).scrobbleUniqueAlbums,
                ),
              ],
            ),
          const SizedBox(height: 20),
          // Scrobble 状态卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.radar, size: 18, color: context.colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).scrobbleTitle,
                        style: Theme.of(context).textTheme.songTitle,
                      ),
                      Text(
                        S.of(context).scrobbleAutoDesc,
                        style: Theme.of(context).textTheme.songSubtitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    S.of(context).scrobbleEnabled,
                    style: Theme.of(context).textTheme.chipLabel.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 最近播放
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).scrobbleRecentTitle,
                style: Theme.of(context).textTheme.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (recentSongs.isNotEmpty)
                Text(
                  S.of(context).scrobbleRecentCount(recentSongs.length),
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentSongs.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Center(
                child: Text(
                  S.of(context).scrobbleEmptyHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ),
            )
          else
            ...recentSongs.take(50).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final song = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: Theme.of(context).textTheme.songSubtitle.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      CoverArt(
                        url: client.coverArtUrl(song.coverArt, size: 100),
                        size: 40,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.songTitle,
                  ),
                  subtitle: Text(
                    '${song.artist} · ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.songSubtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: song.duration != null
                      ? Text(
                          formatDurationOrEmpty(song.duration),
                          style: Theme.of(context).textTheme.songSubtitle.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () =>
                      ref.read(audioPlayerServiceProvider).playSong(song),
                ),
              );
            }),
        ],
      ),
    );
  }
}
