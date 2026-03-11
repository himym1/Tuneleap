import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Artist> _artists = [];
  List<Album> _albums = [];
  List<Song> _songs = [];
  List<Artist> _starredArtists = [];
  List<Album> _starredAlbums = [];
  List<Song> _starredSongs = [];
  bool _loading = true;
  bool _showFavoritesOnly = false;

  // 分页状态
  int _albumOffset = 0;
  bool _hasMoreAlbums = true;
  bool _hasMoreSongs = true;
  bool _loadingMore = false;
  static const _pageSize = 50;
  final _albumScrollController = ScrollController();
  final _songScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _albumScrollController.addListener(_onAlbumScroll);
    _songScrollController.addListener(_onSongScroll);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _albumScrollController.dispose();
    _songScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final results = await Future.wait([
        client.getArtists(),
        client.getAlbumList2(type: 'newest', size: _pageSize, offset: 0),
        client.getRandomSongs(size: _pageSize),
      ]);
      final starred = await client.getStarred2();
      if (!mounted) return;
      setState(() {
        _artists = results[0] as List<Artist>;
        _albums = results[1] as List<Album>;
        _songs = results[2] as List<Song>;
        _albumOffset = _albums.length;
        _hasMoreAlbums = _albums.length >= _pageSize;
        _hasMoreSongs = _songs.length >= _pageSize;
        _starredArtists = starred.artists;
        _starredAlbums = starred.albums;
        _starredSongs = starred.songs;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onAlbumScroll() {
    if (_loadingMore || !_hasMoreAlbums || _showFavoritesOnly) return;
    if (_albumScrollController.position.pixels >
        _albumScrollController.position.maxScrollExtent - 200) {
      _loadMoreAlbums();
    }
  }

  void _onSongScroll() {
    if (_loadingMore || !_hasMoreSongs || _showFavoritesOnly) return;
    if (_songScrollController.position.pixels >
        _songScrollController.position.maxScrollExtent - 200) {
      _loadMoreSongs();
    }
  }

  Future<void> _loadMoreAlbums() async {
    _loadingMore = true;
    try {
      final client = ref.read(subsonicClientProvider);
      final more = await client.getAlbumList2(
        type: 'newest',
        size: _pageSize,
        offset: _albumOffset,
      );
      if (!mounted) return;
      setState(() {
        _albums.addAll(more);
        _albumOffset += more.length;
        _hasMoreAlbums = more.length >= _pageSize;
      });
    } catch (_) {}
    _loadingMore = false;
  }

  Future<void> _loadMoreSongs() async {
    _loadingMore = true;
    try {
      final client = ref.read(subsonicClientProvider);
      final more = await client.getRandomSongs(size: _pageSize);
      if (!mounted) return;
      setState(() {
        _songs.addAll(more);
        _hasMoreSongs = more.length >= _pageSize;
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
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).navLibrary,
                  style: Theme.of(context).textTheme.pageTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    _FilterChip(
                      label: S.of(context).commonAll,
                      selected: !_showFavoritesOnly,
                      onTap: () => setState(() => _showFavoritesOnly = false),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: S.of(context).navFavorites,
                      selected: _showFavoritesOnly,
                      onTap: () => setState(() => _showFavoritesOnly = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Tab 切换
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.onEmphasis,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                dividerHeight: 0,
                tabs: [
                  Tab(text: S.of(context).libraryTabArtists),
                  Tab(text: S.of(context).libraryTabAlbums),
                  Tab(text: S.of(context).libraryTabSongs),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 内容
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildArtistList(),
                      _buildAlbumGrid(),
                      _buildSongList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistList() {
    final artists = _showFavoritesOnly ? _starredArtists : _artists;
    if (artists.isEmpty) {
      return EmptyState(
        icon: Icons.person_outline,
        message: S.of(context).libraryNoArtists,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final client = ref.read(subsonicClientProvider);
        final coverUrl = client.coverArtUrl(artist.coverArt, size: 100);
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
              backgroundImage: coverUrl.isNotEmpty
                  ? NetworkImage(coverUrl)
                  : null,
              child: coverUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    )
                  : null,
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 22),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  onPressed: () => _playArtist(artist),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border, size: 20),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  onPressed: () {},
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => _openArtist(artist),
          ),
        );
      },
    );
  }

  Widget _buildAlbumGrid() {
    final albums = _showFavoritesOnly ? _starredAlbums : _albums;
    if (albums.isEmpty) {
      return EmptyState(
        icon: Icons.album_outlined,
        message: S.of(context).libraryNoAlbums,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 180).floor().clamp(2, 6);
        return GridView.builder(
          controller: _showFavoritesOnly ? null : _albumScrollController,
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.78,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount:
              albums.length + (_hasMoreAlbums && !_showFavoritesOnly ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= albums.length) {
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
            final album = albums[index];
            final client = ref.read(subsonicClientProvider);
            return Material(
              color: AppColors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openAlbumDetail(album),
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
                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
                        fontWeight: FontWeight.w500,
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
            );
          },
        );
      },
    );
  }

  Widget _buildSongList() {
    final songs = _showFavoritesOnly ? _starredSongs : _songs;
    if (songs.isEmpty) {
      return EmptyState(
        icon: Icons.music_note_outlined,
        message: S.of(context).libraryNoSongs,
      );
    }
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      controller: _showFavoritesOnly ? null : _songScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: songs.length + (_hasMoreSongs && !_showFavoritesOnly ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= songs.length) {
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
        final song = songs[index];
        return SongContextMenu(
          song: song,
          onPlay: () {
            ref
                .read(audioPlayerServiceProvider)
                .playAll(songs, startIndex: index);
          },
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
                  .playAll(songs, startIndex: index);
            },
          ),
        );
      },
    );
  }

  void _playArtist(Artist artist) async {
    try {
      final client = ref.read(subsonicClientProvider);
      final detail = await client.getArtist(artist.id);
      if (detail.albums.isNotEmpty) {
        final album = await client.getAlbum(detail.albums.first.id);
        if (album.songs.isNotEmpty) {
          ref.read(audioPlayerServiceProvider).playAll(album.songs);
        }
      }
    } catch (_) {}
  }

  void _openArtist(Artist artist) {
    context.go('/artist/${artist.id}');
  }

  void _openAlbumDetail(Album album) {
    context.go('/album/${album.id}');
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _FilterChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? null
                : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.chipLabel.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? AppColors.onEmphasis
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
