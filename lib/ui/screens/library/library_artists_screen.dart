import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: Text(
              S.of(context).navArtists,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: S.of(context).navSearch,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: artistsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, _) => Center(
                child: Text(
                  S.of(context).libraryNoArtists,
                  style: TextStyle(
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              S.of(context).artistAlbumCount(artist.albumCount ?? 0),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 22),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: () => _playArtist(artist),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => context.go('/artist/${artist.id}'),
          ),
        );
      },
    );
  }
}
