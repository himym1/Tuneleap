import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/audio_visualizer_bars.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/playlist_track_search.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';

/// 打开一张在线歌单并播放其中的曲目。
class OnlinePlaylistDetailScreen extends ConsumerStatefulWidget {
  const OnlinePlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<OnlinePlaylistDetailScreen> createState() =>
      _OnlinePlaylistDetailScreenState();
}

class _OnlinePlaylistDetailScreenState
    extends ConsumerState<OnlinePlaylistDetailScreen> {
  OnlinePlaylistDetail? _detail;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(backendClientProvider)
          .getOnlinePlaylist(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _play(List<Song> tracks, int index) {
    return ref
        .read(audioPlayerServiceProvider)
        .playAllAndConfirm(tracks, startIndex: index);
  }

  Widget _statusPage(BuildContext context, Widget child) {
    final h = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 0),
            child: Row(
              children: [
                if (context.canPop())
                  IconButton(
                    tooltip: S.of(context).commonBack,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
              ],
            ),
          ),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    if (_loading) {
      return _statusPage(
        context,
        CircularProgressIndicator(color: context.colors.primary),
      );
    }
    final detail = _detail;
    if (_error != null || detail == null) {
      return _statusPage(
        context,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.commonLoadFailed),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(strings.commonRetry),
            ),
          ],
        ),
      );
    }

    final isMobile = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    final player = ref.read(audioPlayerServiceProvider);
    return PlaylistTrackQuery(
      songs: detail.tracks,
      builder: (context, searchController, indexes) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: StreamBuilder<Song?>(
            stream: player.currentSongStream,
            initialData: player.currentSong,
            builder: (context, snapshot) {
              final currentId = (snapshot.data ?? player.currentSong)?.id;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(h, h, h, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (context.canPop())
                                IconButton(
                                  onPressed: () => context.pop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                              CoverArt(
                                url: detail.coverUrl ?? '',
                                size: isMobile ? 88 : 140,
                                borderRadius: 12,
                                hasShadow: true,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.pageTitle,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      strings.playlistSongCountLabel(
                                        detail.trackCount ??
                                            detail.tracks.length,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .songSubtitle
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    if (detail.truncated) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        strings.onlinePlaylistsTruncated(
                                          detail.tracks.length,
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.songSubtitle,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: detail.tracks.isEmpty
                                          ? null
                                          : () => _play(detail.tracks, 0),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: Text(
                                        strings.onlinePlaylistsPlayAll,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (detail.tracks.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            PlaylistTrackSearchField(
                              controller: searchController,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (detail.tracks.isNotEmpty && indexes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(strings.playlistNoMatchingSongs),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final sourceIndex = indexes[index];
                        final song = detail.tracks[sourceIndex];
                        final playing = currentId == song.id;
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: h),
                          child: SongContextMenu(
                            song: song,
                            onPlay: () => _play(detail.tracks, sourceIndex),
                            child: ListTile(
                              onTap: () => _play(detail.tracks, sourceIndex),
                              leading: CoverArt(
                                url: song.coverArt ?? '',
                                size: 44,
                                borderRadius: 8,
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.songTitle
                                    .copyWith(
                                      fontWeight: playing
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: playing
                                          ? context.colors.primary
                                          : null,
                                    ),
                              ),
                              subtitle: Text(
                                [song.artist, song.album]
                                    .where((part) => part.trim().isNotEmpty)
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: playing
                                  ? const AudioVisualizerBars(size: 14)
                                  : null,
                            ),
                          ),
                        );
                      }, childCount: indexes.length),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
