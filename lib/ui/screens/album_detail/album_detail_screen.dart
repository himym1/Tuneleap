import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => GoRouter.of(context).canPop() ? context.pop() : context.go('/home'),
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
                final isDesktop = constraints.maxWidth > 600;
                final padding = isDesktop ? 32.0 : 16.0;
                final coverSize = isDesktop ? 240.0 : 200.0;

                if (isDesktop) {
                  return Padding(
                    padding: EdgeInsets.all(padding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CoverArt(
                          url: client.coverArtUrl(album.coverArt, size: 600),
                          size: coverSize,
                          borderRadius: 16,
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: _buildAlbumInfo(
                            context, ref, album, playerService,
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
                      InkWell(
                        onTap: () => GoRouter.of(context).canPop() ? context.pop() : context.go('/home'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              S.of(context).commonBack,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CoverArt(
                        url: client.coverArtUrl(album.coverArt, size: 600),
                        size: coverSize,
                        borderRadius: 16,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        album.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.pageTitle.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        album.artist ??
                            S.of(context).commonUnknownArtist,
                        style: Theme.of(context)
                            .textTheme
                            .songSubtitle
                            .copyWith(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.of(context).albumSongDuration(
                              album.year?.toString() ?? '—',
                              album.songs.length,
                              formatDuration(album.duration),
                            ),
                        style: Theme.of(context)
                            .textTheme
                            .chipLabel
                            .copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              if (album.songs.isNotEmpty) {
                                playerService.playAll(album.songs);
                              }
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(S.of(context).albumPlayAll),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () {
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
                            icon: const Icon(Icons.playlist_add),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      S.of(context).albumDuration,
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .sectionSubheader
                          .copyWith(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 8),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = album.songs[index];
              final isPlaying = currentSong?.id == song.id;
              return SongContextMenu(
                song: song,
                onPlay: () {
                  playerService.playAll(album.songs, startIndex: index);
                  context.push('/player');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isPlaying ? context.colors.primarySoft : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                  onTap: () {
                    playerService.playAll(album.songs, startIndex: index);
                    context.push('/player');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isPlaying ? FontWeight.w600 : null,
                              color: isPlaying
                                  ? context.colors.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
                                style:
                                    Theme.of(context).textTheme.songTitle.copyWith(
                                      fontWeight: isPlaying ? FontWeight.w600 : null,
                                      color: isPlaying ? context.colors.primary : null,
                                    ),
                              ),
                              Text(
                                song.artist,
                                style: Theme.of(context)
                                    .textTheme
                                    .songSubtitle
                                    .copyWith(
                                      color: isPlaying
                                          ? context.colors.primary.withValues(alpha: 0.7)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            formatDuration(song.duration),
                            textAlign: TextAlign.right,
                            style: Theme.of(context)
                                .textTheme
                                .songDuration
                                .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
        InkWell(
          onTap: () => GoRouter.of(context).canPop() ? context.pop() : context.go('/home'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                S.of(context).commonBack,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
          S.of(context).albumSongDuration(
                album.year?.toString() ?? '—',
                album.songs.length,
                formatDuration(album.duration),
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
                  playerService.playAll(album.songs);
                }
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(S.of(context).albumPlayAll),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
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
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(S.of(context).albumAddToQueue),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
