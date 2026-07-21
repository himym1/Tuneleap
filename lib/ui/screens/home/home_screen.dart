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
      ref.read(recommendationPlaybackTrackerProvider);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(recentAlbumsProvider);
    await Future.wait([
      ref.read(newestAlbumsProvider.future),
      ref.read(recentAlbumsProvider.future),
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
    final recentAlbums = ref.watch(recentAlbumsProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: newestAlbums.when(
        loading: () => Center(child: const CircularProgressIndicator()),
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
                // Greeting + Weather
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

                // ── 最新专辑 ──
                _buildSectionHeader(
                  S.of(context).homeNewestAlbums,
                  onMore: () => context.go('/library/albums'),
                ),
                const SizedBox(height: 12),
                _buildAlbumRow(newest),
                const SizedBox(height: 28),

                // ── 推荐 ──
                _buildSectionHeader(
                  S.of(context).homeDailyRecommend,
                  onMore: () => context.go('/recommendations'),
                ),
                const SizedBox(height: 12),
                if (recommendations.initialLoading &&
                    recommendations.visibleItems.isEmpty)
                  const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _buildRecommendationGrid(
                    recommendations.visibleItems.take(12).toList(),
                  ),
                const SizedBox(height: 28),

                // ── 最近播放 ──
                recentAlbums.when(
                  data: (recent) => recent.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              S.of(context).homeRecentlyPlayed,
                              onMore: () => context.go('/scrobble'),
                            ),
                            const SizedBox(height: 12),
                            _buildAlbumRow(recent),
                          ],
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
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
    return SizedBox(
      height: 180,
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
                onTap: () => context.push('/album/${album.id}'),
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
    final songs = items.map((e) => e.song).toList();
    final origins = [for (final item in items) _homeOrigin(item, sessionId)];
    await ref
        .read(audioPlayerServiceProvider)
        .playAll(songs, startIndex: index, origins: origins);
    if (mounted) context.push('/player');
  }

  Widget _buildRecommendationGrid(List<RecommendationItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final backend = ref.read(backendClientProvider);
    final sessionId = ref.read(recommendationProvider).sessionId;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 300).floor().clamp(1, 3);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 4.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final origin = _homeOrigin(item, sessionId);
            return SongContextMenu(
              song: item.song,
              playbackOrigin: origin,
              onImported: () {
                ref
                    .read(recommendationProvider.notifier)
                    .recordFeedback(item, RecommendationFeedbackEvent.imported);
              },
              onPlay: () => _playRecommendations(items, index),
              child: _DailyRecommendTile(
                song: item.song,
                coverUrl: backend.buildCoverProxyUrl(item.song, size: 80),
                onTap: () => _playRecommendations(items, index),
              ),
            );
          },
        );
      },
    );
  }
}

class _DailyRecommendTile extends StatefulWidget {
  final Song song;
  final String coverUrl;
  final VoidCallback onTap;

  const _DailyRecommendTile({
    required this.song,
    required this.coverUrl,
    required this.onTap,
  });

  @override
  State<_DailyRecommendTile> createState() => _DailyRecommendTileState();
}

class _DailyRecommendTileState extends State<_DailyRecommendTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.8)
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          button: true,
          label: widget.song.title,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  CoverArt(url: widget.coverUrl, size: 44, borderRadius: 6),
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
                          style: Theme.of(context).textTheme.chipLabel.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          widget.song.artist,
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
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.3,
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
