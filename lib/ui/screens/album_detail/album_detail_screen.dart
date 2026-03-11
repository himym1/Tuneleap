import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 专辑详情页 — 大封面 + 信息 + 歌曲列表
class AlbumDetailScreen extends ConsumerStatefulWidget {
  final String albumId;
  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  Album? _album;
  bool _loading = true;
  bool _starred = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final album = await client.getAlbum(widget.albumId);
      final starred = await client.getStarred2();
      final isStarred = starred.albums.any((a) => a.id == widget.albumId);
      if (!mounted) return;
      setState(() {
        _album = album;
        _starred = isStarred;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final album = _album;
    if (album == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
                onPressed: () => Navigator.of(context).maybePop(),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      CoverArt(
                        url: client.coverArtUrl(album.coverArt, size: 600),
                        size: 240,
                        borderRadius: 16,
                      ),
                    ],
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                S.of(context).commonBack,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                                    content: Text(
                                      S.of(context).contextMenuAddedQueue,
                                    ),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.playlist_add, size: 18),
                              label: Text(S.of(context).albumAddToQueue),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () async {
                                final c = ref.read(subsonicClientProvider);
                                try {
                                  if (_starred) {
                                    await c.unstar(albumId: album.id);
                                  } else {
                                    await c.star(albumId: album.id);
                                  }
                                  setState(() => _starred = !_starred);
                                } catch (_) {}
                              },
                              icon: Icon(
                                _starred
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _starred
                                    ? AppColors.error
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              tooltip: _starred
                                  ? S.of(context).albumUnfavorite
                                  : S.of(context).albumFavorite,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                      style: Theme.of(context).textTheme.sectionSubheader.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      S.of(context).albumTitle,
                      style: Theme.of(context).textTheme.sectionSubheader.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      S.of(context).albumDuration,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.sectionSubheader.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(indent: 32, endIndent: 32, height: 16),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = album.songs[index];
              return SongContextMenu(
                song: song,
                onPlay: () =>
                    playerService.playAll(album.songs, startIndex: index),
                child: InkWell(
                  onTap: () =>
                      playerService.playAll(album.songs, startIndex: index),
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
                                style: Theme.of(context).textTheme.songTitle,
                              ),
                              Text(
                                song.artist,
                                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                            style: Theme.of(context).textTheme.songDuration.copyWith(
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
              );
            }, childCount: album.songs.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
