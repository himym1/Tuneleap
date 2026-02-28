import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/song_tile.dart';
import 'package:navidrome_player/ui/widgets/mini_player.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Album> _recentAlbums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final albums = await client.getAlbumList2(type: 'newest', size: 20);
      setState(() {
        _recentAlbums = albums;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar.large(
                    title: const Text('Navidrome Player'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          // TODO: navigate to search
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          // TODO: navigate to settings
                        },
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: Text('最近添加', style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _AlbumCard(
                          album: _recentAlbums[index],
                          client: ref.read(subsonicClientProvider),
                          onTap: () => _openAlbum(_recentAlbums[index]),
                        ),
                        childCount: _recentAlbums.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  void _openAlbum(Album album) async {
    final client = ref.read(subsonicClientProvider);
    final detail = await client.getAlbum(album.id);
    if (!mounted) return;

    final playerService = ref.read(audioPlayerServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.name, style: Theme.of(context).textTheme.headlineSmall),
                    if (detail.artist != null) Text(detail.artist!, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        playerService.playAll(detail.songs);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('播放全部'),
                    ),
                  ],
                ),
              ),
              ...detail.songs.asMap().entries.map((entry) => SongTile(
                    song: entry.value,
                    onTap: () {
                      playerService.playAll(detail.songs, startIndex: entry.key);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  final dynamic client;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final coverUrl = client.coverArtUrl(album.coverArt, size: 300) as String;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverUrl.isNotEmpty
                  ? Image.network(coverUrl, fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.album, size: 48)),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          if (album.artist != null)
            Text(album.artist!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
