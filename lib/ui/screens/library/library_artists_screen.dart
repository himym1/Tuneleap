import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibraryArtistsScreen extends ConsumerStatefulWidget {
  const LibraryArtistsScreen({super.key});

  @override
  ConsumerState<LibraryArtistsScreen> createState() =>
      _LibraryArtistsScreenState();
}

class _LibraryArtistsScreenState extends ConsumerState<LibraryArtistsScreen> {
  String _searchQuery = '';

  void _playArtist(Artist artist) async {
    try {
      final client = ref.read(subsonicClientProvider);
      final detail = await client.getArtist(artist.id);
      if (detail.albums.isNotEmpty) {
        final album = await client.getAlbum(detail.albums.first.id);
        if (album.songs.isNotEmpty) {
          ref.read(audioPlayerServiceProvider).playAll(album.songs);
        }
      }
    } catch (e) {
      debugPrint('Failed to play artist: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile ? AppDimensions.paddingMobile : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 16),
            child: Text(
              S.of(context).navArtists,
              style: Theme.of(context).textTheme.pageTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(h, 0, h, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: S.of(context).navSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: artistsAsync.when(
              loading: () => Center(
                child: const CircularProgressIndicator(),
              ),
              error: (_, _) => Center(
                child: Text(
                  S.of(context).libraryNoArtists,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              data: (artists) {
                final filtered = _searchQuery.isEmpty
                    ? artists
                    : artists
                          .where(
                            (a) => a.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();
                return filtered.isEmpty
                    ? Center(
                        child: Text(
                          S.of(context).libraryNoArtists,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _buildArtistList(filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistList(List<Artist> artists) {
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final coverUrl = client.coverArtUrl(artist.coverArt, size: 100);
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
              backgroundImage: coverUrl.isNotEmpty
                  ? NetworkImage(coverUrl)
                  : null,
              child: coverUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    )
                  : null,
            ),
            title: Text(
              artist.name,
              style: Theme.of(context).textTheme.songTitle,
            ),
            subtitle: Text(
              S.of(context).artistAlbumCount(artist.albumCount ?? 0),
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 22),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: S.of(context).tooltipPlay,
              onPressed: () => _playArtist(artist),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => context.push('/artist/${artist.id}'),
          ),
        );
      },
    );
  }
}
