import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibraryGenresScreen extends ConsumerStatefulWidget {
  const LibraryGenresScreen({super.key});

  @override
  ConsumerState<LibraryGenresScreen> createState() =>
      _LibraryGenresScreenState();
}

class _LibraryGenresScreenState extends ConsumerState<LibraryGenresScreen> {
  Genre? _selectedGenre;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: Row(
              children: [
                if (_selectedGenre != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    tooltip: S.of(context).tooltipBack,
                    onPressed: () => setState(() => _selectedGenre = null),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _selectedGenre?.name ?? S.of(context).libraryGenresTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
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
            child: _selectedGenre != null
                ? _buildGenreSongs()
                : _buildGenreList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreList() {
    final genresAsync = ref.watch(genresProvider);

    return genresAsync.when(
      loading: () =>
          Center(child: const CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          S.of(context).libraryNoGenres,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      data: (genres) {
        final filtered = _searchQuery.isEmpty
            ? genres
            : genres
                  .where(
                    (g) => g.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList();
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              S.of(context).libraryNoGenres,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final genre = filtered[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.music_note, color: context.colors.primary),
              ),
              title: Text(
                genre.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                '${S.of(context).genreSongCount(genre.songCount)} · ${S.of(context).genreAlbumCount(genre.albumCount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () => setState(() => _selectedGenre = genre),
            );
          },
        );
      },
    );
  }

  Widget _buildGenreSongs() {
    if (_selectedGenre == null) return const SizedBox.shrink();

    final songsAsync = ref.watch(genreSongsProvider(_selectedGenre!.name));
    final client = ref.read(subsonicClientProvider);

    return songsAsync.when(
      loading: () =>
          Center(child: const CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(
          S.of(context).libraryNoSongs,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      data: (songs) {
        final filtered = _searchQuery.isEmpty
            ? songs
            : songs
                  .where(
                    (s) =>
                        s.title.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        s.artist.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        s.album.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                  )
                  .toList();
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              S.of(context).libraryNoSongs,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final song = filtered[index];
            return SongContextMenu(
              song: song,
              onPlay: () {
                ref
                    .read(audioPlayerServiceProvider)
                    .playAll(songs, startIndex: index);
              },
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: CoverArt(
                  url: client.coverArtUrl(song.coverArt, size: 80),
                  size: 44,
                  borderRadius: 6,
                ),
                title: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '${song.artist} · ${song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  ref
                      .read(audioPlayerServiceProvider)
                      .playAll(songs, startIndex: index);
                },
              ),
            );
          },
        );
      },
    );
  }
}
