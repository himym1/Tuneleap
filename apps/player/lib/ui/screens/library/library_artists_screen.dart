import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/library_section_tabs.dart';
import 'package:navidrome_player/ui/widgets/loading_skeleton.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/utils/text_composing.dart';

class LibraryArtistsScreen extends ConsumerStatefulWidget {
  const LibraryArtistsScreen({super.key});

  @override
  ConsumerState<LibraryArtistsScreen> createState() =>
      _LibraryArtistsScreenState();
}

class _LibraryArtistsScreenState extends ConsumerState<LibraryArtistsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref
        .read(librarySearchProvider(LibrarySearchType.artists).notifier)
        .onQueryChanged(
          value,
          composing: isActivelyComposing(_searchController.value),
        );
  }

  void _playArtist(Artist artist) {
    ref.read(libraryProvider.notifier).playArtist(artist);
  }

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsProvider);
    final searchState = ref.watch(
      librarySearchProvider(LibrarySearchType.artists),
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
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (value) => ref
                  .read(
                    librarySearchProvider(LibrarySearchType.artists).notifier,
                  )
                  .onQueryChanged(value),
              decoration: InputDecoration(
                hintText: S.of(context).navSearch,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: artistsAsync.when(
              loading: () => SongListSkeleton(
                itemCount: 10,
                padding: EdgeInsets.symmetric(horizontal: h, vertical: 8),
              ),
              error: (_, _) => ErrorState(
                message: S.of(context).libraryNoArtists,
                retryLabel: S.of(context).commonRetry,
                onRetry: () => ref.invalidate(artistsProvider),
              ),
              data: (artists) {
                final display = searchState.serverId == serverId
                    ? (searchState.artists ?? artists)
                    : artists;
                return display.isEmpty
                    ? EmptyState(
                        icon: Icons.person_outline_rounded,
                        message: S.of(context).libraryNoArtists,
                      )
                    : _buildArtistList(display, h);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistList(List<Artist> artists, double h) {
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final coverUrl = artist.coverArt != null
            ? client.coverArtUrl(artist.coverArt, size: 120)
            : '';
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: coverUrl.isNotEmpty
                ? ClipOval(
                    child: CoverArt(url: coverUrl, size: 42, borderRadius: 21),
                  )
                : CircleAvatar(
                    radius: 21,
                    backgroundColor: context.colors.primarySoft,
                    child: Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: context.colors.primary,
                    ),
                  ),
            title: Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.songTitle,
            ),
            subtitle: Text(
              S.of(context).artistAlbumCount(artist.albumCount ?? 0),
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded, size: 22),
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
