import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/library_section_tabs.dart';
import 'package:navidrome_player/ui/widgets/loading_skeleton.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/utils/text_composing.dart';

class LibraryAlbumsScreen extends ConsumerStatefulWidget {
  const LibraryAlbumsScreen({super.key});

  @override
  ConsumerState<LibraryAlbumsScreen> createState() =>
      _LibraryAlbumsScreenState();
}

class _LibraryAlbumsScreenState extends ConsumerState<LibraryAlbumsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref
        .read(librarySearchProvider(LibrarySearchType.albums).notifier)
        .onQueryChanged(
          value,
          composing: isActivelyComposing(_searchController.value),
        );
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(newestAlbumsProvider);
    final searchState = ref.watch(
      librarySearchProvider(LibrarySearchType.albums),
    );
    final serverId = ref.watch(
      serverConfigProvider.select((config) => config.serverId),
    );
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
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (value) => ref
                  .read(
                    librarySearchProvider(LibrarySearchType.albums).notifier,
                  )
                  .onQueryChanged(value),
              decoration: InputDecoration(
                hintText: S.of(context).navSearch,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: albumsAsync.when(
              loading: () => const AlbumGridSkeleton(),
              error: (_, _) => ErrorState(
                message: S.of(context).libraryNoAlbums,
                retryLabel: S.of(context).commonRetry,
                onRetry: () => ref.invalidate(newestAlbumsProvider),
              ),
              data: (albums) {
                final display = searchState.serverId == serverId
                    ? (searchState.albums ?? albums)
                    : albums;
                return display.isEmpty
                    ? EmptyState(
                        icon: Icons.album_outlined,
                        message: S.of(context).libraryNoAlbums,
                      )
                    : _buildAlbumGrid(display, h);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumGrid(List<Album> albums, double h) {
    final client = ref.read(subsonicClientProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / AppDimensions.albumGridColumnWidth)
                .floor()
                .clamp(2, 6);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(h, 8, h, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.78,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return _AlbumGridCard(
              album: album,
              coverUrl: client.coverArtUrl(album.coverArt, size: 300),
              onTap: () => context.push('/album/${album.id}'),
            );
          },
        );
      },
    );
  }
}

class _AlbumGridCard extends StatefulWidget {
  const _AlbumGridCard({
    required this.album,
    required this.coverUrl,
    required this.onTap,
  });

  final Album album;
  final String coverUrl;
  final VoidCallback onTap;

  @override
  State<_AlbumGridCard> createState() => _AlbumGridCardState();
}

class _AlbumGridCardState extends State<_AlbumGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label:
            '${album.name}${album.artist != null ? ', ${album.artist}' : ''}',
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedScale(
                    scale: _hovered ? 1.025 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: CoverArt(
                      url: widget.coverUrl,
                      borderRadius: 14,
                      hasShadow: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.songTitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _hovered ? context.colors.primary : null,
                  ),
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
      ),
    );
  }
}
