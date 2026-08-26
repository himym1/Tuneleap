import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/audio_visualizer_bars.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/utils/duration_format.dart';
import 'package:navidrome_player/utils/player_navigation.dart';

/// 专辑详情页 — 大封面 + 信息 + 歌曲列表
class AlbumDetailScreen extends ConsumerWidget {
  final String albumId;
  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(albumDetailProvider(albumId));

    if (detail.loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final album = detail.album;
    if (album == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context).commonLoadFailed,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => GoRouter.of(context).canPop()
                    ? context.pop()
                    : context.go('/home'),
                child: Text(S.of(context).commonBack),
              ),
            ],
          ),
        ),
      );
    }

    final client = ref.read(subsonicClientProvider);
    final playerService = ref.read(audioPlayerServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<Song?>(
        stream: playerService.currentSongStream,
        initialData: playerService.currentSong,
        builder: (context, songSnapshot) {
          final currentSong = songSnapshot.data ?? playerService.currentSong;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = AppBreakpoints.isDesktop(
                      constraints.maxWidth,
                    );
                    final padding = isDesktop ? 32.0 : 16.0;
                    final coverSize = isDesktop ? 240.0 : 200.0;

                    if (isDesktop) {
                      return Padding(
                        padding: EdgeInsets.all(padding),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CoverArt(
                              url: client.coverArtUrl(
                                album.coverArt,
                                size: 600,
                              ),
                              size: coverSize,
                              borderRadius: 20,
                              hasShadow: true,
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              child: _buildAlbumInfo(
                                context,
                                ref,
                                album,
                                playerService,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    // Mobile: vertical layout
                    return Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Semantics(
                            button: true,
                            label: S.of(context).tooltipBack,
                            child: InkWell(
                              onTap: () => GoRouter.of(context).canPop()
                                  ? context.pop()
                                  : context.go('/home'),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_rounded,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      S.of(context).commonBack,
                                      style: Theme.of(context)
                                          .textTheme
                                          .songSubtitle
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CoverArt(
                            url: client.coverArtUrl(album.coverArt, size: 600),
                            size: coverSize,
                            borderRadius: 20,
                            hasShadow: true,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            album.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.pageTitle
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            album.artist ?? S.of(context).commonUnknownArtist,
                            style: Theme.of(context).textTheme.songSubtitle
                                .copyWith(
                                  fontSize: 15,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            S
                                .of(context)
                                .albumSongDuration(
                                  album.year?.toString() ?? '—',
                                  album.songs.length,
                                  formatDurationOrEmpty(album.duration),
                                ),
                            style: Theme.of(context).textTheme.chipLabel
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: () {
                                  if (album.songs.isNotEmpty) {
                                    HapticFeedback.lightImpact();
                                    playerService.playAll(album.songs);
                                  }
                                },
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: Text(S.of(context).albumPlayAll),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  if (album.songs.isNotEmpty) {
                                    HapticFeedback.lightImpact();
                                    final shuffled = List<Song>.from(
                                      album.songs,
                                    )..shuffle();
                                    playerService.playAll(shuffled);
                                  }
                                },
                                icon: const Icon(
                                  Icons.shuffle_rounded,
                                  size: 17,
                                ),
                                label: const Text('随机播放'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  for (final song in album.songs) {
                                    playerService.addToQueue(song);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        S.of(context).contextMenuAddedQueue,
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.playlist_add_rounded),
                                tooltip: S.of(context).albumAddToQueue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = AppBreakpoints.isDesktop(
                      constraints.maxWidth,
                    );
                    final hPadding = isDesktop ? 32.0 : 16.0;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPadding),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '#',
                              style: Theme.of(context)
                                  .textTheme
                                  .sectionSubheader
                                  .copyWith(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              S.of(context).albumTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .sectionSubheader
                                  .copyWith(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          SizedBox(
                            width: isDesktop ? 100 : 56,
                            child: Text(
                              S.of(context).albumDuration,
                              textAlign: TextAlign.right,
                              style: Theme.of(context)
                                  .textTheme
                                  .sectionSubheader
                                  .copyWith(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = album.songs[index];
                  final isPlaying = currentSong?.id == song.id;
                  final isMobile = AppBreakpoints.isMobile(
                    MediaQuery.of(context).size.width,
                  );
                  return SongContextMenu(
                    song: song,
                    onPlay: () {
                      playerService.playAll(album.songs, startIndex: index);
                      openPlayer(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isPlaying ? context.colors.primarySoft : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () {
                          playerService.playAll(album.songs, startIndex: index);
                          openPlayer(context);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 32,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: isPlaying
                                    ? StreamBuilder<bool>(
                                        stream: playerService.playingStream,
                                        builder: (context, playingSnap) =>
                                            AudioVisualizerBars(
                                              isPlaying:
                                                  playingSnap.data ?? false,
                                              size: 14,
                                              color: context.colors.primary,
                                            ),
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .chipLabel
                                            .copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .songTitle
                                          .copyWith(
                                            fontWeight: isPlaying
                                                ? FontWeight.w600
                                                : null,
                                            color: isPlaying
                                                ? context.colors.primary
                                                : null,
                                          ),
                                    ),
                                    Text(
                                      song.artist,
                                      style: Theme.of(context)
                                          .textTheme
                                          .songSubtitle
                                          .copyWith(
                                            color: isPlaying
                                                ? context.colors.primary
                                                      .withValues(alpha: 0.7)
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: isMobile ? 56 : 100,
                                child: Text(
                                  formatDurationOrEmpty(song.duration),
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context)
                                      .textTheme
                                      .songDuration
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: album.songs.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlbumInfo(
    BuildContext context,
    WidgetRef ref,
    Album album,
    AudioPlayerService playerService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: S.of(context).tooltipBack,
          child: InkWell(
            onTap: () => GoRouter.of(context).canPop()
                ? context.pop()
                : context.go('/home'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    S.of(context).commonBack,
                    style: Theme.of(context).textTheme.songSubtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          album.name,
          style: Theme.of(context).textTheme.pageTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          album.artist ?? S.of(context).commonUnknownArtist,
          style: Theme.of(context).textTheme.songSubtitle.copyWith(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          S
              .of(context)
              .albumSongDuration(
                album.year?.toString() ?? '—',
                album.songs.length,
                formatDurationOrEmpty(album.duration),
              ),
          style: Theme.of(context).textTheme.chipLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () {
                if (album.songs.isNotEmpty) {
                  HapticFeedback.lightImpact();
                  playerService.playAll(album.songs);
                }
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(S.of(context).albumPlayAll),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                if (album.songs.isNotEmpty) {
                  HapticFeedback.lightImpact();
                  final shuffled = List<Song>.from(album.songs)..shuffle();
                  playerService.playAll(shuffled);
                }
              },
              icon: const Icon(Icons.shuffle_rounded, size: 17),
              label: const Text('随机播放'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                for (final song in album.songs) {
                  playerService.addToQueue(song);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context).contextMenuAddedQueue),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.playlist_add_rounded, size: 20),
              tooltip: S.of(context).albumAddToQueue,
            ),
          ],
        ),
      ],
    );
  }
}
