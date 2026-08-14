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

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = ref.watch(starredProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(h, h, h, 8),
              child: Row(
                children: [
                  if (isMobile)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => context.go('/settings'),
                    ),
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
            TabBar(
              tabs: [
                Tab(text: S.of(context).favoritesTabSongs),
                Tab(text: S.of(context).favoritesTabAlbums),
                Tab(text: S.of(context).favoritesTabArtists),
              ],
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
              borderRadius: 6,
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            borderRadius: 6,
          ),
          title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            album.artist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
