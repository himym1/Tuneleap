import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibrarySongsScreen extends ConsumerStatefulWidget {
  const LibrarySongsScreen({super.key});

  @override
  ConsumerState<LibrarySongsScreen> createState() => _LibrarySongsScreenState();
}

class _LibrarySongsScreenState extends ConsumerState<LibrarySongsScreen> {
  List<Song> _songs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  static const _pageSize = 50;
  final _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final songs = await client.getRandomSongs(size: _pageSize);
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _hasMore = songs.length >= _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    _loadingMore = true;
    try {
      final client = ref.read(subsonicClientProvider);
      final more = await client.getRandomSongs(size: _pageSize);
      if (!mounted) return;
      setState(() {
        _songs.addAll(more);
        _hasMore = more.length >= _pageSize;
      });
    } catch (_) {}
    _loadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
            child: Text(
              S.of(context).navSongs,
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
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : _songs.isEmpty
                ? Center(
                    child: Text(
                      S.of(context).libraryNoSongs,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _buildSongList(),
          ),
        ],
      ),
    );
  }

  void _scrollToCurrentSong() {
    final currentSong = ref.read(audioPlayerServiceProvider).currentSong;
    if (currentSong == null) return;

    final filtered = _searchQuery.isEmpty
        ? _songs
        : _songs
              .where(
                (s) =>
                    s.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    s.artist.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    s.album.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    final index = filtered.indexWhere((s) => s.id == currentSong.id);
    if (index == -1) return;

    _scrollController.animateTo(
      index * 68.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildSongList() {
    final client = ref.read(subsonicClientProvider);
    final currentSong = ref.watch(audioPlayerServiceProvider).currentSong;
    final filtered = _searchQuery.isEmpty
        ? _songs
        : _songs
              .where(
                (s) =>
                    s.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    s.artist.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    s.album.toLowerCase().contains(_searchQuery.toLowerCase()),
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

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount:
              filtered.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= filtered.length) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            }
            final song = filtered[index];
            final isPlaying = currentSong?.id == song.id;
            return SongContextMenu(
              song: song,
              onPlay: () {
                ref
                    .read(audioPlayerServiceProvider)
                    .playAll(filtered, startIndex: index);
              },
              child: Container(
                decoration: isPlaying
                    ? BoxDecoration(
                        border: Border.all(color: AppColors.accent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
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
                  trailing: song.duration != null
                      ? Text(
                          song.formattedDuration,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    ref
                        .read(audioPlayerServiceProvider)
                        .playAll(_songs, startIndex: index);
                  },
                ),
              ),
            );
          },
        ),
        if (currentSong != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _scrollToCurrentSong,
              backgroundColor: AppColors.accent,
              child: Icon(Icons.my_location, color: AppColors.onEmphasis),
            ),
          ),
      ],
    );
  }
}
