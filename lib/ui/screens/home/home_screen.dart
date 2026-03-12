import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _refresh() async {
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(dailySongsProvider);
    ref.invalidate(recentAlbumsProvider);
    await Future.wait([
      ref.read(newestAlbumsProvider.future),
      ref.read(dailySongsProvider.future),
      ref.read(recentAlbumsProvider.future),
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
    final dailySongs = ref.watch(dailySongsProvider);
    final recentAlbums = ref.watch(recentAlbumsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: newestAlbums.when(
        loading: () =>
            Center(child: const CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: S.of(context).commonError,
          onRetry: _refresh,
          retryLabel: S.of(context).commonRetry,
        ),
        data: (newest) => RefreshIndicator(
          onRefresh: _refresh,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
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

              // ── 每日推荐 ──
              _buildSectionHeader(S.of(context).homeDailyRecommend),
              const SizedBox(height: 12),
              dailySongs.when(
                data: (songs) => _buildDailyGrid(songs),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
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
        return Text(
          '${info.icon} ${info.temp}  ${info.location}',
          style: Theme.of(context).textTheme.chipLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
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
              style: TextStyle(fontSize: 13, color: context.colors.primary),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go('/album/${album.id}'),
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
                        style: Theme.of(context).textTheme.songSubtitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyGrid(List<Song> songs) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final client = ref.read(subsonicClientProvider);
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
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return SongContextMenu(
              song: song,
              onPlay: () {
                ref
                    .read(audioPlayerServiceProvider)
                    .playAll(songs, startIndex: index);
                context.push('/player');
              },
              child: _DailyRecommendTile(
                song: song,
                coverUrl: client.coverArtUrl(song.coverArt, size: 80),
                onTap: () {
                  ref
                      .read(audioPlayerServiceProvider)
                      .playAll(songs, startIndex: index);
                  context.push('/player');
                },
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
            ? Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.8)
            : Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                CoverArt(
                  url: widget.coverUrl,
                  size: 44,
                  borderRadius: 6,
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
                        style: Theme.of(context).textTheme.chipLabel.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
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
    );
  }
}