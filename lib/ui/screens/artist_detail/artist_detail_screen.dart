import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 艺术家详情页 — 头像 + 简介 + 专辑列表
class ArtistDetailScreen extends ConsumerStatefulWidget {
  final String artistId;
  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  ArtistDetail? _detail;
  bool _loading = true;
  bool _starred = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final detail = await client.getArtist(widget.artistId);
      // 读取实际收藏状态
      final starred = await client.getStarred2();
      final isStarred = starred.artists.any((a) => a.id == widget.artistId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _starred = isStarred;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context).commonLoadFailed,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(S.of(context).commonBack),
              ),
            ],
          ),
        ),
      );
    }

    final client = ref.read(subsonicClientProvider);
    final artist = detail.artist;
    final albums = detail.albums;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 头部
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头像
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                    backgroundImage: artist.coverArt != null
                        ? NetworkImage(
                            client.coverArtUrl(artist.coverArt, size: 300),
                          )
                        : null,
                    child: artist.coverArt == null
                        ? Icon(
                            Icons.person,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 返回
                        InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                S.of(context).commonBack,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          artist.name,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          S.of(context).artistAlbumCount(albums.length),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                // 并行获取所有专辑的歌曲
                                try {
                                  final albumDetails = await Future.wait(
                                    albums.map((a) => client.getAlbum(a.id)),
                                  );
                                  final allSongs = albumDetails
                                      .expand((a) => a.songs)
                                      .toList();
                                  if (allSongs.isNotEmpty) {
                                    ref
                                        .read(audioPlayerServiceProvider)
                                        .playAll(allSongs);
                                  }
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: Text(S.of(context).albumPlayAll),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final c = ref.read(subsonicClientProvider);
                                try {
                                  if (_starred) {
                                    await c.unstar(artistId: artist.id);
                                  } else {
                                    await c.star(artistId: artist.id);
                                  }
                                  setState(() => _starred = !_starred);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _starred
                                              ? S.of(context).contextMenuStarred
                                              : S.of(context).artistUnfavorited,
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                } catch (_) {}
                              },
                              icon: Icon(
                                _starred
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 18,
                              ),
                              label: Text(
                                _starred
                                    ? S.of(context).contextMenuStarred
                                    : S.of(context).navFavorites,
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                side: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 专辑标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
              child: Text(
                S.of(context).homeAlbums,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // 专辑网格
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final album = albums[index];
                return GestureDetector(
                  onTap: () => context.go('/album/${album.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CoverArt(
                          url: client.coverArtUrl(album.coverArt, size: 400),
                          borderRadius: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${album.year ?? '—'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }, childCount: albums.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
