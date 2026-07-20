import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibrarySongsScreen extends ConsumerStatefulWidget {
  const LibrarySongsScreen({super.key});

  @override
  ConsumerState<LibrarySongsScreen> createState() => _LibrarySongsScreenState();
}

class _LibrarySongsScreenState extends ConsumerState<LibrarySongsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // 静态缓存：跨 widget 实例保留歌曲列表和滚动位置
  static List<Song> _cachedSongs = [];
  static bool _cachedHasMore = true;
  static String? _cachedServerId;

  List<Song> _songs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;
  static const _pageSize = 50;
  static const _itemExtent = 64.0; // ListTile with padding
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<Song>? _searchResults; // null = not searching, use _songs
  late String _serverId;
  ProviderSubscription<String>? _serverSubscription;

  @override
  void initState() {
    super.initState();
    _serverId = ref.read(serverConfigProvider).serverId;
    if (_cachedServerId != _serverId) {
      _cachedSongs = [];
      _cachedHasMore = true;
      _cachedServerId = _serverId;
    }
    _serverSubscription = ref.listenManual(
      serverConfigProvider.select((config) => config.serverId),
      (_, next) => _handleServerChanged(next),
    );
    _scrollController.addListener(_onScroll);
    // 从静态缓存恢复
    if (_cachedSongs.isNotEmpty) {
      _songs = List.of(_cachedSongs);
      _hasMore = _cachedHasMore;
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentSong();
      });
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    _serverSubscription?.close();
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _handleServerChanged(String serverId) {
    if (serverId == _serverId || !mounted) return;
    _serverId = serverId;
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
    _cachedSongs = [];
    _cachedHasMore = true;
    _cachedServerId = serverId;
    setState(() {
      _songs = [];
      _searchResults = null;
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final requestServerId = _serverId;
    try {
      final client = ref.read(subsonicClientProvider);
      final result = await client.search3(
        '',
        songCount: _pageSize,
        songOffset: 0,
        artistCount: 0,
        albumCount: 0,
      );
      if (!mounted ||
          ref.read(serverConfigProvider).serverId != requestServerId ||
          _serverId != requestServerId) {
        return;
      }
      setState(() {
        _songs = result.songs;
        _hasMore = result.songs.length >= _pageSize;
        _loading = false;
        _error = null;
        _cachedSongs = List.of(_songs);
        _cachedHasMore = _hasMore;
        _cachedServerId = _serverId;
      });
    } catch (e) {
      if (mounted &&
          ref.read(serverConfigProvider).serverId == requestServerId &&
          _serverId == requestServerId) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
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
    final requestServerId = _serverId;
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
      if (!mounted ||
          ref.read(serverConfigProvider).serverId != requestServerId ||
          _serverId != requestServerId) {
        return;
      }
      setState(() {
        _songs.addAll(result.songs);
        _hasMore = result.songs.length >= _pageSize;
        _cachedSongs = List.of(_songs);
        _cachedHasMore = _hasMore;
        _cachedServerId = _serverId;
      });
    } catch (e) {
      if (mounted &&
          ref.read(serverConfigProvider).serverId == requestServerId &&
          _serverId == requestServerId) {
        debugPrint('Failed to load more songs: ${e.runtimeType}');
      }
    } finally {
      if (mounted &&
          ref.read(serverConfigProvider).serverId == requestServerId &&
          _serverId == requestServerId) {
        _loadingMore = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              S.of(context).navSongs,
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(S.of(context).commonLoadFailed),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _loadData();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(S.of(context).commonRetry),
                        ),
                      ],
                    ),
                  )
                : _songs.isEmpty
                ? Center(
                    child: Text(
                      S.of(context).libraryNoSongs,
                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchQuery = value;
    if (value.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    // Skip if IME is still composing
    if (_searchController.value.composing != TextRange.empty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 500), _doApiSearch);
  }

  Future<void> _doApiSearch() async {
    final requestServerId = _serverId;
    final query = _searchQuery.trim();
    if (query.isEmpty) return;
    try {
      final client = ref.read(subsonicClientProvider);
      final result = await client.search3(
        query,
        songCount: 50,
        songOffset: 0,
        artistCount: 0,
        albumCount: 0,
      );
      if (!mounted ||
          _searchQuery.trim() != query ||
          ref.read(serverConfigProvider).serverId != requestServerId ||
          _serverId != requestServerId) {
        return;
      }
      setState(() => _searchResults = result.songs);
    } catch (_) {}
  }

  List<Song> _filteredSongs() {
    return _searchResults ?? _songs;
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
              onDeleted: () {
                setState(() => _songs.removeWhere((s) => s.id == song.id));
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
                  trailing: song.duration != null
                      ? Text(
                          song.formattedDuration,
                          style: Theme.of(context).textTheme.songDuration.copyWith(
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
              width: 44,
              height: 44,
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
