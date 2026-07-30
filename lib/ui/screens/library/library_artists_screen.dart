import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/library_section_tabs.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibraryArtistsScreen extends ConsumerStatefulWidget {
  const LibraryArtistsScreen({super.key});

  @override
  ConsumerState<LibraryArtistsScreen> createState() =>
      _LibraryArtistsScreenState();
}

class _LibraryArtistsScreenState extends ConsumerState<LibraryArtistsScreen> {
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
      setState(() {
        _searchResults = result.artists;
        _searchResultsServerId = serverId;
      });
    } catch (_) {}
  }

  void _playArtist(Artist artist) {
    ref.read(libraryProvider.notifier).playArtist(artist);
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
              S.of(context).navArtists,
              style: Theme.of(context).textTheme.pageTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(h, 0, h, 16),
            child: const LibrarySectionTabs(),
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
                final display = _searchResultsServerId == serverId
                    ? (_searchResults ?? artists)
                    : artists;
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
                    : _buildArtistList(display);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistList(List<Artist> artists) {
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
