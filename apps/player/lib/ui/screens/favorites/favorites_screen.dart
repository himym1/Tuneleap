import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/ui/widgets/segmented_control.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentIndex) {
        setState(() => _currentIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final starred = ref.watch(starredProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 14),
            child: Row(
              children: [
                if (isMobile) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () => context.go('/settings'),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    S.of(context).favoritesTitle,
                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(h, 0, h, 16),
            child: AppSegmentedControl<int>(
              items: [
                AppSegmentItem(
                  value: 0,
                  label: S.of(context).favoritesTabSongs,
                ),
                AppSegmentItem(
                  value: 1,
                  label: S.of(context).favoritesTabAlbums,
                ),
                AppSegmentItem(
                  value: 2,
                  label: S.of(context).favoritesTabArtists,
                ),
              ],
              selected: _currentIndex,
              onSelected: (index) {
                _tabController.animateTo(index);
                setState(() => _currentIndex = index);
              },
            ),
          ),
          Expanded(
            child: starred.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(
                message: S.of(context).commonError,
                onRetry: () => ref.invalidate(starredProvider),
                retryLabel: S.of(context).commonRetry,
              ),
              data: (result) => TabBarView(
                controller: _tabController,
                children: [
                  _FavoriteSongs(songs: result.songs, padding: h),
                  _FavoriteAlbums(albums: result.albums, padding: h),
                  _FavoriteArtists(artists: result.artists, padding: h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteSongs extends ConsumerWidget {
  const _FavoriteSongs({required this.songs, required this.padding});

  final List<Song> songs;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return Center(child: Text(S.of(context).favoritesEmpty));
    }
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongContextMenu(
          song: song,
          child: ListTile(
            leading: CoverArt(
              url: client.coverArtUrl(song.coverArt, size: 80),
              size: AppDimensions.coverList,
              borderRadius: 10,
              hasShadow: true,
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onTap: () => ref
                .read(audioPlayerServiceProvider)
                .playAll(songs, startIndex: index),
          ),
        );
      },
    );
  }
}

class _FavoriteAlbums extends ConsumerWidget {
  const _FavoriteAlbums({required this.albums, required this.padding});

  final List<Album> albums;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (albums.isEmpty) {
      return Center(child: Text(S.of(context).favoritesEmpty));
    }
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          leading: CoverArt(
            url: client.coverArtUrl(album.coverArt, size: 80),
            size: AppDimensions.coverList,
            borderRadius: 10,
            hasShadow: true,
          ),
          title: Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            album.artist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => context.push('/album/${album.id}'),
        );
      },
    );
  }
}

class _FavoriteArtists extends ConsumerWidget {
  const _FavoriteArtists({required this.artists, required this.padding});

  final List<Artist> artists;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (artists.isEmpty) {
      return Center(child: Text(S.of(context).favoritesEmpty));
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          title: Text(artist.name),
          subtitle: Text(
            S.of(context).artistAlbumCount(artist.albumCount ?? 0),
          ),
          onTap: () => context.push('/artist/${artist.id}'),
        );
      },
    );
  }
}
