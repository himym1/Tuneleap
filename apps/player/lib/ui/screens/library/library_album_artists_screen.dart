import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// Album Artists screen — uses getArtists() which returns album artists by default in Subsonic
class LibraryAlbumArtistsScreen extends ConsumerStatefulWidget {
  const LibraryAlbumArtistsScreen({super.key});

  @override
  ConsumerState<LibraryAlbumArtistsScreen> createState() =>
      _LibraryAlbumArtistsScreenState();
}

class _LibraryAlbumArtistsScreenState
    extends ConsumerState<LibraryAlbumArtistsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<Artist>? _searchResults;
  String? _searchResultsServerId;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchQuery = value;
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _searchResultsServerId = null;
      });
      return;
    }
    if (_searchController.value.composing != TextRange.empty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 500), _doApiSearch);
  }

  Future<void> _doApiSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) return;
    final serverId = ref.read(serverConfigProvider).serverId;
    try {
      final client = ref.read(subsonicClientProvider);
      final result = await client.search3(
        query,
        artistCount: 50,
        albumCount: 0,
        songCount: 0,
      );
      if (!mounted ||
          _searchQuery.trim() != query ||
          ref.read(serverConfigProvider).serverId != serverId) {
        return;
      }
      // Filter to album artists only
      setState(() {
        _searchResults = result.artists
            .where((artist) => (artist.albumCount ?? 0) > 0)
            .toList();
        _searchResultsServerId = serverId;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsProvider);
    final serverId = ref.watch(
      serverConfigProvider.select((config) => config.serverId),
    );
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
              S.of(context).libraryAlbumArtistsTitle,
              style: Theme.of(context).textTheme.pageTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(h, 0, h, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
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
                final filteredArtists = artists
                    .where((artist) => (artist.albumCount ?? 0) > 0)
                    .toList();
                final display = _searchResultsServerId == serverId
                    ? (_searchResults ?? filteredArtists)
                    : filteredArtists;
                return display.isEmpty
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
                    : _buildList(display);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Artist> artists) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
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
