import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/library_section_tabs.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibraryAlbumsScreen extends ConsumerStatefulWidget {
  const LibraryAlbumsScreen({super.key});

  @override
  ConsumerState<LibraryAlbumsScreen> createState() =>
      _LibraryAlbumsScreenState();
}

class _LibraryAlbumsScreenState extends ConsumerState<LibraryAlbumsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<Album>? _searchResults;
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
        albumCount: 50,
        songCount: 0,
        artistCount: 0,
      );
      if (!mounted ||
          _searchQuery.trim() != query ||
          ref.read(serverConfigProvider).serverId != serverId) {
        return;
      }
      setState(() {
        _searchResults = result.albums;
        _searchResultsServerId = serverId;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(newestAlbumsProvider);
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
              S.of(context).navAlbums,
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
            child: albumsAsync.when(
              loading: () => Center(
                child: const CircularProgressIndicator(),
              ),
              error: (_, _) => Center(
                child: Text(
                  S.of(context).libraryNoAlbums,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              data: (albums) {
                final display = _searchResultsServerId == serverId
                    ? (_searchResults ?? albums)
                    : albums;
                return display.isEmpty
                    ? Center(
                        child: Text(
                          S.of(context).libraryNoAlbums,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _buildAlbumGrid(display);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumGrid(List<Album> albums) {
    final client = ref.read(subsonicClientProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 180).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.78,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return Semantics(
              button: true,
              label: '${album.name}${album.artist != null ? ', ${album.artist}' : ''}',
              child: InkWell(
              onTap: () => context.push('/album/${album.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CoverArt(
                      url: client.coverArtUrl(album.coverArt, size: 300),
                      borderRadius: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.songTitle,
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
            );
          },
        );
      },
    );
  }
}
