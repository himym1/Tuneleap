import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/ui/widgets/cloud_auth_dialog.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/playback_origin.dart';
import 'package:navidrome_player/utils/player_navigation.dart';

List<Song> composePersonalizedLocalMix({
  required List<Song> playHistory,
  required List<Song> similarSongs,
  required List<Song> starredSongs,
  required List<Song> randomSongs,
  int limit = 30,
}) {
  final localHistory = playHistory.where((song) => !song.isOnline).toList();
  final recentKeys = localHistory
      .take(5)
      .map((song) => song.storageKey)
      .toSet();
  final pools = <List<Song>>[
    similarSongs.where((song) => !song.isOnline).toList(),
    localHistory.skip(8).take(8).toList(),
    starredSongs.where((song) => !song.isOnline).toList(),
    randomSongs.where((song) => !song.isOnline).toList(),
  ];
  const quotas = [15, 5, 4, 6];
  final selected = <Song>[];
  final seen = <String>{};
  final artistCounts = <String, int>{};

  bool addSong(
    Song song, {
    required int artistLimit,
    bool allowRecent = false,
  }) {
    if (selected.length >= limit ||
        seen.contains(song.storageKey) ||
        (!allowRecent && recentKeys.contains(song.storageKey))) {
      return false;
    }
    final artistKey = song.artistId.isNotEmpty
        ? song.artistId
        : song.artist.trim().toLowerCase();
    if (artistKey.isNotEmpty && (artistCounts[artistKey] ?? 0) >= artistLimit) {
      return false;
    }
    seen.add(song.storageKey);
    selected.add(song);
    if (artistKey.isNotEmpty) {
      artistCounts[artistKey] = (artistCounts[artistKey] ?? 0) + 1;
    }
    return true;
  }

  void takeFrom(
    Iterable<Song> songs,
    int count, {
    int artistLimit = 2,
    bool allowRecent = false,
  }) {
    var added = 0;
    for (final song in songs) {
      if (addSong(song, artistLimit: artistLimit, allowRecent: allowRecent)) {
        added++;
        if (added >= count) return;
      }
    }
  }

  for (var index = 0; index < pools.length; index++) {
    takeFrom(pools[index], quotas[index]);
  }
  final fallback = pools.expand((songs) => songs);
  takeFrom(fallback, limit - selected.length);
  takeFrom(fallback, limit - selected.length, artistLimit: limit);
  if (selected.isEmpty) {
    takeFrom(localHistory, limit, artistLimit: limit, allowRecent: true);
  }
  return selected;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loadingLocalPlayback = false;
  bool _refreshingHome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for silent Cloud restore so first recommendations are not 401.
      await ref.read(cloudAuthProvider.future);
      if (!mounted) return;
      ref.read(recommendationProvider.notifier).ensureLoaded();
    });
  }

  Future<void> _refresh() async {
    if (_refreshingHome) return;
    setState(() => _refreshingHome = true);
    var succeeded = false;
    try {
      ref.invalidate(newestSongsProvider);
      await Future.wait([
        ref.read(newestSongsProvider.future),
        ref.read(recommendationProvider.notifier).refresh(),
      ]);
      succeeded = ref.read(recommendationProvider).error == null;
    } catch (_) {
      succeeded = false;
    } finally {
      if (mounted) {
        setState(() => _refreshingHome = false);
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                succeeded
                    ? S.of(context).homeRefreshed
                    : S.of(context).commonError,
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  Future<void> _playPersonalizedMix() async {
    if (_loadingLocalPlayback) return;
    setState(() => _loadingLocalPlayback = true);
    try {
      final player = ref.read(audioPlayerServiceProvider);
      final client = ref.read(subsonicClientProvider);
      final localHistory = player.playHistory
          .where((song) => !song.isOnline)
          .toList();
      final seeds = localHistory.take(3).toList();

      Future<List<Song>> loadSimilarSongs() async {
        final batches = await Future.wait(
          seeds.map((seed) async {
            try {
              return await client
                  .getSimilarSongs2(seed.id, count: 15)
                  .timeout(const Duration(seconds: 15));
            } catch (_) {
              return <Song>[];
            }
          }),
        );
        return batches.expand((songs) => songs).toList();
      }

      Future<List<Song>> loadStarredSongs() async {
        try {
          return (await client.getStarred2().timeout(
            const Duration(seconds: 15),
          )).songs;
        } catch (_) {
          return <Song>[];
        }
      }

      Future<List<Song>> loadRandomSongs() async {
        try {
          return await client
              .getRandomSongs(size: 80)
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          return <Song>[];
        }
      }

      final candidates = await Future.wait<List<Song>>([
        loadSimilarSongs(),
        loadStarredSongs(),
        loadRandomSongs(),
      ]);
      final songs = composePersonalizedLocalMix(
        playHistory: localHistory,
        similarSongs: candidates[0],
        starredSongs: candidates[1],
        randomSongs: candidates[2],
      );
      if (songs.isEmpty) throw StateError('empty local library');
      await player.playAll(songs);
      if (mounted) openPlayer(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).homeLocalPlaybackFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocalPlayback = false);
    }
  }

  Widget _buildLocalActions() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.primary, context.colors.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-personalized-mix-button'),
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          onTap: _loadingLocalPlayback ? null : _playPersonalizedMix,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loadingLocalPlayback)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onEmphasis,
                    ),
                  )
                else
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: context.colors.onEmphasis,
                  ),
                const SizedBox(width: 8),
                Text(
                  S.of(context).homeLocalMix,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.colors.onEmphasis,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final newestSongs = ref.watch(newestSongsProvider);
    final recommendations = ref.watch(recommendationProvider);
    final cloudAuthenticated =
        ref.watch(cloudAuthProvider).value?.isAuthenticated == true;
    final recentSongs = ref
        .watch(recommendationRecentSongsProvider)
        .take(1)
        .toList();
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: newestSongs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: S.of(context).commonError,
          onRetry: _refresh,
          retryLabel: S.of(context).commonRetry,
        ),
        data: (newest) => RefreshIndicator(
          key: const Key('home-refresh-indicator'),
          onRefresh: _refresh,
          child: ListView(
            key: const Key('home-scroll-view'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(h, h, h, h),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _greeting(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.pageTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 40,
                    child: _refreshingHome
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            key: const Key('home-refresh-button'),
                            tooltip: S.of(context).commonRefresh,
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                  ),
                  const SizedBox(width: 4),
                  _buildWeather(),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionHeader(
                S.of(context).homeYourMusic,
                onMore: () => context.go('/library/songs'),
              ),
              const SizedBox(height: 8),
              if (recentSongs.isNotEmpty) ...[
                Text(
                  S.of(context).homeContinueListening,
                  style: Theme.of(context).textTheme.chipLabel.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                _buildRecentSongs(recentSongs),
                const SizedBox(height: 12),
              ],
              _buildLocalActions(),
              const SizedBox(height: 20),

              _buildSectionHeader(
                S.of(context).homeDailyRecommend,
                onRefresh: () {
                  HapticFeedback.lightImpact();
                  ref.read(recommendationProvider.notifier).refresh();
                },
                isRefreshing: recommendations.refreshing,
                onMore: () => context.push('/home/recommendations'),
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
                  message: cloudAuthenticated
                      ? S.of(context).commonError
                      : S.of(context).cloudAuthRequired,
                  onRetry: () async {
                    if (!cloudAuthenticated) {
                      final ok = await CloudAuthDialog.show(context);
                      if (!ok || !mounted) return;
                    }
                    await ref.read(recommendationProvider.notifier).refresh();
                  },
                  retryLabel: cloudAuthenticated
                      ? S.of(context).recommendationsRetry
                      : S.of(context).cloudSignIn,
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
                  recommendations.visibleItems.take(6).toList(),
                ),
              const SizedBox(height: 20),
              _buildSectionHeader(
                S.of(context).homeNewestSongs,
                onMore: () => context.go('/library/songs'),
              ),
              const SizedBox(height: 8),
              if (newest.isEmpty)
                EmptyState(
                  icon: Icons.library_music_outlined,
                  message: S.of(context).commonNoData,
                )
              else
                _buildNewestSongs(newest),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeather() {
    final weather = ref.watch(weatherProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return weather.when(
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        return Tooltip(
          message: S.of(context).commonRefresh,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref.invalidate(weatherProvider),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: isDark ? 0.08 : 0.05,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${info.icon} ${info.temp}  ${info.location}',
                  style: Theme.of(context).textTheme.chipLabel.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

  Widget _buildSectionHeader(
    String title, {
    VoidCallback? onMore,
    VoidCallback? onRefresh,
    bool isRefreshing = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        if (onRefresh != null) ...[
          TextButton.icon(
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              '换一批',
              style: Theme.of(context).textTheme.chipLabel.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
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
    if (mounted) openPlayer(context);
  }

  Future<void> _playRecentSongs(List<Song> songs, int index) async {
    if (songs.isEmpty) return;
    await ref
        .read(audioPlayerServiceProvider)
        .playAll(songs, startIndex: index);
    if (mounted) openPlayer(context);
  }

  Widget _buildSongRows(List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= AppDimensions.homeGridTwoPane ? 2 : 1;
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

  Widget _buildNewestSongs(List<Song> songs) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metadata = [
      widget.song.artist,
      widget.song.album,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.10 : 0.06,
                )
              : (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.04 : 0.02,
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: _hovered ? (isDark ? 0.14 : 0.08) : (isDark ? 0.06 : 0.04),
            ),
            width: 0.6,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: Semantics(
            button: true,
            label: '${widget.song.title}, $metadata',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    ResolvedSongCoverArt(
                      song: widget.song,
                      size: 44,
                      borderRadius: 8,
                      hasShadow: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.songTitle
                                .copyWith(fontWeight: FontWeight.w600),
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
                        style: Theme.of(context).textTheme.songDuration
                            .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.play_circle_filled_rounded,
                        size: 24,
                        color: _hovered
                            ? context.colors.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
