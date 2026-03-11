import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

enum _SearchBackend { local, netease, kuwo, joox }

extension on _SearchBackend {
  bool get isOnline => this != _SearchBackend.local;

  String get label => switch (this) {
    _SearchBackend.local => 'Navidrome',
    _SearchBackend.netease => 'Netease',
    _SearchBackend.kuwo => 'Kuwo',
    _SearchBackend.joox => 'JOOX',
  };

  String? get source => switch (this) {
    _SearchBackend.local => null,
    _SearchBackend.netease => 'netease',
    _SearchBackend.kuwo => 'kuwo',
    _SearchBackend.joox => 'joox',
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
  SearchResult? _result;
  bool _searching = false;
  int _selectedFilter = 0; // 0=全部, 1=歌曲, 2=专辑, 3=艺术家
  _SearchBackend _selectedBackend = _SearchBackend.local;

  List<String> _getFilters(BuildContext context) {
    final filters = [S.of(context).searchAll, S.of(context).homeSongs];
    if (!_selectedBackend.isOnline) {
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
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() => _result = null);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searching = true);
    try {
      final result = switch (_selectedBackend) {
        _SearchBackend.local =>
          await ref
              .read(subsonicClientProvider)
              .search3(query, artistCount: 20, albumCount: 20, songCount: 30),
        _ => SearchResult(
          songs: await ref
              .read(solaraClientProvider)
              .searchSongs(
                query,
                source: _selectedBackend.source!,
                count: 30,
                page: 1,
              ),
        ),
      };
      if (!mounted) return;
      setState(() {
        _result = result;
        _searching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _setBackend(_SearchBackend backend) {
    if (_selectedBackend == backend) return;
    setState(() {
      _selectedBackend = backend;
      if (_selectedBackend.isOnline && _selectedFilter > 1) {
        _selectedFilter = 0;
      }
    });

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = _getFilters(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
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
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _result = null);
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _SearchBackend.values.map((backend) {
                final selected = _selectedBackend == backend;
                return Material(
                  color: selected
                      ? AppColors.primary
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
                        backend.label,
                        style: Theme.of(context).textTheme.chipLabel.copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? AppColors.onEmphasis
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: List.generate(filters.length, (index) {
                final selected = _selectedFilter == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: selected
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _selectedFilter = index),
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
                                ? AppColors.onEmphasis
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return Center(child: CircularProgressIndicator());
    }

    if (_result == null) {
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final songs = (_selectedFilter == 0 || _selectedFilter == 1)
        ? _result!.songs
        : <Song>[];
    final albums =
        (!_selectedBackend.isOnline &&
            (_selectedFilter == 0 || _selectedFilter == 2))
        ? _result!.albums
        : <Album>[];
    final artists =
        (!_selectedBackend.isOnline &&
            (_selectedFilter == 0 || _selectedFilter == 3))
        ? _result!.artists
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
            (song) => _SongResultTile(song: song, onTap: () => _playSong(song)),
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
              onTap: () => context.go('/album/${album.id}'),
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
              onTap: () => context.go('/artist/${artist.id}'),
            ),
          ),
        ],
      ],
    );
  }

  void _playSong(Song song) {
    ref.read(audioPlayerServiceProvider).playSong(song);
  }
}

class _SongResultTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongResultTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.read(songMediaResolverProvider);
    return SongContextMenu(
      song: song,
      onPlay: onTap,
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
          style: Theme.of(context).textTheme.songTitle,
        ),
        subtitle: Text(
          '${song.artist} · ${song.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.songSubtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    'kuwo' => 'Kuwo',
                    'joox' => 'JOOX',
                    _ => 'Netease',
                  },
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (song.duration != null)
              Text(
                song.formattedDuration,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
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
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Image.network(
            client.coverArtUrl(album.coverArt, size: 100),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: const Icon(Icons.album, size: 18),
            ),
          ),
        ),
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
