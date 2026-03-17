import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

extension on SearchBackend {
  String label(BuildContext context) => switch (this) {
    SearchBackend.local => S.of(context).searchBackendNavidrome,
    SearchBackend.netease => S.of(context).searchBackendNetease,
    SearchBackend.kuwo => S.of(context).searchBackendKuwo,
    SearchBackend.joox => S.of(context).searchBackendJoox,
  };
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

  List<String> _getFilters(BuildContext context, SearchBackend backend) {
    final filters = [S.of(context).searchAll, S.of(context).homeSongs];
    if (!backend.isOnline) {
      filters.addAll([S.of(context).homeAlbums, S.of(context).homeArtists]);
    }
    return filters;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchProvider.notifier).search(query.trim());
    });
  }

  void _setBackend(SearchBackend backend) {
    ref.read(searchProvider.notifier).setBackend(backend);
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchProvider.notifier).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final filters = _getFilters(context, searchState.selectedBackend);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile ? AppDimensions.paddingMobile : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).navSearch,
                  style: Theme.of(context).textTheme.pageTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 搜索栏
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: false,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: S.of(context).searchHintInput,
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: S.of(context).tooltipClear,
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clearResult();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SearchBackend.values.map((backend) {
                final selected = searchState.selectedBackend == backend;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: backend.label(context),
                  excludeSemantics: true,
                  child: Material(
                    color: selected
                        ? context.colors.primary
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _setBackend(backend),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: selected
                              ? null
                              : Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                        ),
                        child: Text(
                          backend.label(context),
                          style: Theme.of(context).textTheme.chipLabel.copyWith(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? context.colors.onEmphasis
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // 分类标签
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: Row(
              children: List.generate(filters.length, (index) {
                final selected = searchState.selectedFilter == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: filters[index],
                    excludeSemantics: true,
                    child: Material(
                      color: selected
                          ? context.colors.primary
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => ref.read(searchProvider.notifier).setFilter(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: selected
                                ? null
                                : Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                          ),
                          child: Text(
                            filters[index],
                            style: Theme.of(context).textTheme.chipLabel.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? context.colors.onEmphasis
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // 结果
          Expanded(child: _buildResults(searchState)),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState searchState) {
    if (searchState.searching) {
      return Center(child: const CircularProgressIndicator());
    }

    if (searchState.result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).searchPlaceholder,
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final result = searchState.result!;
    final filter = searchState.selectedFilter;
    final isOnline = searchState.selectedBackend.isOnline;

    final songs = (filter == 0 || filter == 1) ? result.songs : <Song>[];
    final albums = (!isOnline && (filter == 0 || filter == 2))
        ? result.albums
        : <Album>[];
    final artists = (!isOnline && (filter == 0 || filter == 3))
        ? result.artists
        : <Artist>[];

    if (songs.isEmpty && albums.isEmpty && artists.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        message: S.of(context).searchNoResult,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        if (songs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text(
              S.of(context).searchResults,
              style: Theme.of(context).textTheme.sectionSubheader.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...songs.map(
            (song) => _SongResultTile(
              song: song,
              onTap: () {
                ref.read(audioPlayerServiceProvider).playSong(song);
                context.push('/player');
              },
            ),
          ),
        ],
        if (albums.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
            child: Text(
              S.of(context).homeAlbums,
              style: Theme.of(context).textTheme.sectionSubheader.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...albums.map(
            (album) => _AlbumResultTile(
              album: album,
              client: ref.read(subsonicClientProvider),
              onTap: () => context.push('/album/${album.id}'),
            ),
          ),
        ],
        if (artists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
            child: Text(
              S.of(context).homeArtists,
              style: Theme.of(context).textTheme.sectionSubheader.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...artists.map(
            (artist) => _ArtistResultTile(
              artist: artist,
              client: ref.read(subsonicClientProvider),
              onTap: () => context.push('/artist/${artist.id}'),
            ),
          ),
        ],
      ],
    );
  }
}

class _SongResultTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongResultTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.read(songMediaResolverProvider);
    final playerService = ref.read(audioPlayerServiceProvider);
    return StreamBuilder<Song?>(
      stream: playerService.currentSongStream,
      initialData: playerService.currentSong,
      builder: (context, snapshot) {
        final isPlaying = (snapshot.data ?? playerService.currentSong)?.id == song.id;
        return SongContextMenu(
          song: song,
          onPlay: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isPlaying ? context.colors.primarySoft : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: FutureBuilder<String>(
                future: resolver.coverArtUrl(song, size: 100),
                builder: (context, snapshot) =>
                    CoverArt(url: snapshot.data ?? '', size: 40, borderRadius: 6),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.songTitle.copyWith(
                  fontWeight: isPlaying ? FontWeight.w600 : null,
                  color: isPlaying ? context.colors.primary : null,
                ),
              ),
              subtitle: Text(
                '${song.artist} · ${song.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: isPlaying
                      ? context.colors.primary.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (song.isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      switch (song.onlineSource) {
                        'kuwo' => S.of(context).searchBackendKuwo,
                        'joox' => S.of(context).searchBackendJoox,
                        _ => S.of(context).searchBackendNetease,
                      },
                      style: Theme.of(context).textTheme.chipLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (song.duration != null)
                  Text(
                    song.formattedDuration,
                    style: Theme.of(context).textTheme.songSubtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: onTap,
          ),
          ),
        );
      },
    );
  }
}

class _AlbumResultTile extends StatelessWidget {
  final Album album;
  final SubsonicClient client;
  final VoidCallback onTap;
  const _AlbumResultTile({
    required this.album,
    required this.client,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: CoverArt(
        url: client.coverArtUrl(album.coverArt, size: 100),
        size: 40,
        borderRadius: 6,
      ),
      title: Text(
        album.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.songTitle,
      ),
      subtitle: Text(
        album.artist ?? '',
        style: Theme.of(context).textTheme.songSubtitle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}

class _ArtistResultTile extends StatelessWidget {
  final Artist artist;
  final SubsonicClient client;
  final VoidCallback onTap;
  const _ArtistResultTile({
    required this.artist,
    required this.client,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        backgroundImage: artist.coverArt != null
            ? NetworkImage(client.coverArtUrl(artist.coverArt, size: 100))
            : null,
        child: artist.coverArt == null
            ? Icon(
                Icons.person,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      title: Text(artist.name, style: Theme.of(context).textTheme.songTitle),
      subtitle: Text(
        S.of(context).artistAlbumCount(artist.albumCount ?? 0),
        style: Theme.of(context).textTheme.songSubtitle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}
