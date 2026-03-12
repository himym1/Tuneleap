import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  static const _itemExtent = 64.0; // ListTile with padding
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
      final result = await client.search3(
        '',
        songCount: _pageSize,
        songOffset: 0,
        artistCount: 0,
        albumCount: 0,
      );
      if (!mounted) return;
      setState(() {
        _songs = result.songs;
        _hasMore = result.songs.length >= _pageSize;
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
      final result = await client.search3(
        '',
        songCount: _pageSize,
        songOffset: _songs.length,
        artistCount: 0,
        albumCount: 0,
      );
      if (!mounted) return;
      setState(() {
        _songs.addAll(result.songs);
        _hasMore = result.songs.length >= _pageSize;
      });
    } catch (e) {
      debugPrint('Failed to load more songs: $e');
    }
    _loadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                ? const Center(child: CircularProgressIndicator())
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

    final filtered = _filteredSongs();
    final index = filtered.indexWhere((s) => s.id == currentSong.id);
    if (index == -1) return;

    _scrollController.animateTo(
      index * _itemExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  List<Song> _filteredSongs() {
    if (_searchQuery.isEmpty) return _songs;
    final query = _searchQuery.toLowerCase();
    return _songs.where((s) =>
      s.title.toLowerCase().contains(query) ||
      s.artist.toLowerCase().contains(query) ||
      s.album.toLowerCase().contains(query),
    ).toList();
  }

  Widget _buildSongList() {
    final playerService = ref.read(audioPlayerServiceProvider);
    final client = ref.read(subsonicClientProvider);
    final filtered = _filteredSongs();

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

    // StreamBuilder 监听当前歌曲变化，确保返回页面时高亮和定位按钮实时更新
    return StreamBuilder<Song?>(
      stream: playerService.currentSongStream,
      builder: (context, snapshot) {
        final currentSong = snapshot.data ?? playerService.currentSong;
        return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemExtent: _itemExtent,
          itemCount:
              filtered.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= filtered.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
                context.push('/player');
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isPlaying ? context.colors.primarySoft : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w500,
                      color: isPlaying ? context.colors.primary : null,
                    ),
                  ),
                  subtitle: Text(
                    '${song.artist} · ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPlaying
                          ? context.colors.primary.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: song.duration != null
                      ? Text(
                          song.formattedDuration,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    ref
                        .read(audioPlayerServiceProvider)
                        .playAll(filtered, startIndex: index);
                    context.push('/player');
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
            child: SizedBox(
              width: 40,
              height: 40,
              child: FloatingActionButton(
                onPressed: _scrollToCurrentSong,
                elevation: 2,
                backgroundColor: context.colors.primary,
                shape: const CircleBorder(),
                child: Icon(Icons.my_location, size: 18, color: context.colors.onEmphasis),
              ),
            ),
          ),
      ],
    );
      },
    );
  }
}
