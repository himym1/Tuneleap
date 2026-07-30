import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/playback_origin.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recommendationProvider.notifier).ensureLoaded();
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(newestAlbumsProvider);
    await Future.wait([
      ref.read(newestAlbumsProvider.future),
      ref.read(recommendationProvider.notifier).refresh(),
    ]);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final s = S.of(context);
    if (hour < 12) return s.homeGreetingMorning;
    if (hour < 18) return s.homeGreetingAfternoon;
    return s.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final newestAlbums = ref.watch(newestAlbumsProvider);
    final recommendations = ref.watch(recommendationProvider);
    final recentSongs = ref
        .watch(recommendationRecentSongsProvider)
        .take(8)
        .toList();
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: newestAlbums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: S.of(context).commonError,
          onRetry: _refresh,
          retryLabel: S.of(context).commonRetry,
        ),
        data: (newest) => RefreshIndicator(
          onRefresh: _refresh,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ListView(
              padding: EdgeInsets.fromLTRB(h, h, h, h),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _greeting(),
                      style: Theme.of(context).textTheme.pageTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    _buildWeather(),
                  ],
                ),
                const SizedBox(height: 28),

                _buildSectionHeader(
                  S.of(context).homeDailyRecommend,
                  onMore: () => context.go('/recommendations'),
                ),
                const SizedBox(height: 8),
                if (recommendations.initialLoading &&
                    recommendations.visibleItems.isEmpty)
                  const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (recommendations.error != null &&
                    recommendations.visibleItems.isEmpty)
                  ErrorState(
                    message: S.of(context).commonError,
                    onRetry: () =>
                        ref.read(recommendationProvider.notifier).refresh(),
                    retryLabel: S.of(context).recommendationsRetry,
                  )
                else if (recommendations.visibleItems.isEmpty)
                  EmptyState(
                    icon: Icons.queue_music_rounded,
                    message: S.of(context).recommendationsEmpty,
                    actionLabel: S.of(context).recommendationsRetry,
                    onAction: () =>
                        ref.read(recommendationProvider.notifier).refresh(),
                  )
                else
                  _buildRecommendationList(
                    recommendations.visibleItems.take(12).toList(),
                  ),

                if (recentSongs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          S.of(context).homeRecentlyPlayed,
                          onMore: () => context.go('/scrobble'),
                        ),
                        const SizedBox(height: 8),
                        _buildRecentSongs(recentSongs),
                      ],
                    ),
                  ),

                const SizedBox(height: 28),
                _buildSectionHeader(
                  S.of(context).homeNewestAlbums,
                  onMore: () => context.go('/library/albums'),
                ),
                const SizedBox(height: 12),
                _buildAlbumRow(newest),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeather() {
    final weather = ref.watch(weatherProvider);
    return weather.when(
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        return Tooltip(
          message: S.of(context).commonRefresh,
          child: InkWell(
            onTap: () => ref.invalidate(weatherProvider),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                '${info.icon} ${info.temp}  ${info.location}',
                style: Theme.of(context).textTheme.chipLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onMore}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (onMore != null)
          TextButton(
            onPressed: onMore,
            child: Text(
              S.of(context).homeViewMore,
              style: Theme.of(
                context,
              ).textTheme.chipLabel.copyWith(color: context.colors.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildAlbumRow(List<Album> albums) {
    final client = ref.read(subsonicClientProvider);
    final rowHeight = MediaQuery.textScalerOf(context).scale(36) + 144;
    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: albums.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final album = albums[index];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: Semantics(
              button: true,
              label: album.name,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push('/home/album/${album.id}'),
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoverArt(
                        url: client.coverArtUrl(album.coverArt, size: 300),
                        size: 130,
                        borderRadius: 10,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.songSubtitle,
                      ),
                      if (album.artist != null)
                        Text(
                          album.artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.songSubtitle
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
          );
        },
      ),
    );
  }

  PlaybackOrigin? _homeOrigin(RecommendationItem item, String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return null;
    return PlaybackOrigin(
      sessionId: sessionId,
      candidateId: item.candidateId,
      impressionId: 'home-${item.candidateId}',
    );
  }

  Future<void> _playRecommendations(
    List<RecommendationItem> items,
    int index,
  ) async {
    final sessionId = ref.read(recommendationProvider).sessionId;
    if (sessionId == null || items.isEmpty) return;
    ref.read(recommendationPlaybackTrackerProvider);
    final songs = items.map((e) => e.song).toList();
    final origins = [for (final item in items) _homeOrigin(item, sessionId)];
    await ref
        .read(audioPlayerServiceProvider)
        .playAll(songs, startIndex: index, origins: origins);
    if (mounted) context.push('/player');
  }

  Future<void> _playRecentSongs(List<Song> songs, int index) async {
    if (songs.isEmpty) return;
    await ref
        .read(audioPlayerServiceProvider)
        .playAll(songs, startIndex: index);
    if (mounted) context.push('/player');
  }

  Widget _buildSongRows(List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 760 ? 2 : 1;
        final rowExtent = MediaQuery.textScalerOf(context).scale(32) + 36;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: rowExtent,
            crossAxisSpacing: 16,
            mainAxisSpacing: 4,
          ),
          itemCount: rows.length,
          itemBuilder: (context, index) => rows[index],
        );
      },
    );
  }

  Widget _buildRecommendationList(List<RecommendationItem> items) {
    final sessionId = ref.read(recommendationProvider).sessionId;
    return _buildSongRows([
      for (final entry in items.asMap().entries)
        SongContextMenu(
          song: entry.value.song,
          playbackOrigin: _homeOrigin(entry.value, sessionId),
          onImported: () {
            ref
                .read(recommendationProvider.notifier)
                .recordFeedback(
                  entry.value,
                  RecommendationFeedbackEvent.imported,
                );
          },
          onPlay: () => _playRecommendations(items, entry.key),
          child: _HomeSongTile(
            song: entry.value.song,
            onTap: () => _playRecommendations(items, entry.key),
          ),
        ),
    ]);
  }

  Widget _buildRecentSongs(List<Song> songs) {
    return _buildSongRows([
      for (final entry in songs.asMap().entries)
        SongContextMenu(
          song: entry.value,
          onPlay: () => _playRecentSongs(songs, entry.key),
          child: _HomeSongTile(
            song: entry.value,
            onTap: () => _playRecentSongs(songs, entry.key),
          ),
        ),
    ]);
  }
}

class _HomeSongTile extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;

  const _HomeSongTile({required this.song, required this.onTap});

  @override
  State<_HomeSongTile> createState() => _HomeSongTileState();
}

class _HomeSongTileState extends State<_HomeSongTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final metadata = [
      widget.song.artist,
      widget.song.album,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.75)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(6),
        child: Semantics(
          button: true,
          label: '${widget.song.title}, $metadata',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  ResolvedSongCoverArt(
                    song: widget.song,
                    size: 44,
                    borderRadius: 5,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.songTitle.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (metadata.isNotEmpty)
                          Text(
                            metadata,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.songSubtitle
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.song.duration != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.song.formattedDuration,
                      style: Theme.of(context).textTheme.songDuration.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.6,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 24,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
