import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 收藏体系页面 — 统计卡片 + Tab(歌曲/专辑/艺术家) + 列表
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Song> _starredSongs = [];
  List<Album> _starredAlbums = [];
  List<Artist> _starredArtists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStarred();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStarred() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final starred = await client.getStarred2();
      if (!mounted) return;
      setState(() {
        _starredSongs = starred.songs;
        _starredAlbums = starred.albums;
        _starredArtists = starred.artists;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Text(
              S.of(context).favoritesTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 统计卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                _StatCard(
                  icon: Icons.music_note,
                  value: '${_starredSongs.length}',
                  label: S.of(context).favoritesTabSongs,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.album,
                  value: '${_starredAlbums.length}',
                  label: S.of(context).favoritesTabAlbums,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.person,
                  value: '${_starredArtists.length}',
                  label: S.of(context).favoritesTabArtists,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Tab
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
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                dividerHeight: 0,
                tabs: [
                  Tab(text: S.of(context).homeSongs),
                  Tab(text: S.of(context).homeAlbums),
                  Tab(text: S.of(context).homeArtists),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSongList(),
                      _buildAlbumList(),
                      _buildArtistList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    if (_starredSongs.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_outline,
        message: S.of(context).favoritesEmpty,
      );
    }
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      itemCount: _starredSongs.length,
      itemBuilder: (context, index) {
        final song = _starredSongs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CoverArt(
            url: client.coverArtUrl(song.coverArt, size: 100),
            size: 44,
            borderRadius: 6,
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.duration != null)
                Text(
                  '${song.duration! ~/ 60}:${(song.duration! % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.favorite, color: AppColors.error, size: 18),
                onPressed: () => _unstarSong(song),
              ),
            ],
          ),
          onTap: () => ref.read(audioPlayerServiceProvider).playSong(song),
        );
      },
    );
  }

  Widget _buildAlbumList() {
    if (_starredAlbums.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_outline,
        message: S.of(context).favoritesEmpty,
      );
    }
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      itemCount: _starredAlbums.length,
      itemBuilder: (context, index) {
        final album = _starredAlbums[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CoverArt(
            url: client.coverArtUrl(album.coverArt, size: 100),
            size: 44,
            borderRadius: 6,
          ),
          title: Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            album.artist ?? '',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.favorite, color: AppColors.error, size: 18),
            onPressed: () => _unstarAlbum(album),
          ),
          onTap: () => context.go('/album/${album.id}'),
        );
      },
    );
  }

  Widget _buildArtistList() {
    if (_starredArtists.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_outline,
        message: S.of(context).favoritesEmpty,
      );
    }
    final client = ref.read(subsonicClientProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      itemCount: _starredArtists.length,
      itemBuilder: (context, index) {
        final artist = _starredArtists[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            backgroundImage: artist.coverArt != null
                ? NetworkImage(client.coverArtUrl(artist.coverArt, size: 100))
                : null,
            child: artist.coverArt == null
                ? Icon(
                    Icons.person,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
                : null,
          ),
          title: Text(
            artist.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            S.of(context).artistAlbumCount(artist.albumCount ?? 0),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.favorite, color: AppColors.error, size: 18),
            onPressed: () => _unstarArtist(artist),
          ),
          onTap: () => context.go('/artist/${artist.id}'),
        );
      },
    );
  }

  void _unstarSong(Song song) {
    ref.read(starredSongsProvider.notifier).unstar(song.id);
    setState(() => _starredSongs.remove(song));
  }

  void _unstarAlbum(Album album) async {
    try {
      await ref.read(subsonicClientProvider).unstar(albumId: album.id);
      setState(() => _starredAlbums.remove(album));
    } catch (_) {}
  }

  void _unstarArtist(Artist artist) async {
    try {
      await ref.read(subsonicClientProvider).unstar(artistId: artist.id);
      setState(() => _starredArtists.remove(artist));
    } catch (_) {}
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoftAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
