import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 艺术家详情页 — 头像 + 简介 + 专辑列表
class ArtistDetailScreen extends ConsumerWidget {
  final String artistId;
  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(artistDetailProvider(artistId));

    return asyncDetail.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context).commonLoadFailed,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => GoRouter.of(context).canPop() ? context.pop() : context.go('/home'),
                child: Text(S.of(context).commonBack),
              ),
            ],
          ),
        ),
      ),
      data: (detail) {
        final client = ref.read(subsonicClientProvider);
        final artist = detail.artist;
        final albums = detail.albums;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final mobile = AppBreakpoints.isMobile(width);
              final hPad = mobile
                  ? AppDimensions.paddingMobile
                  : AppDimensions.paddingDesktop;
              return CustomScrollView(
            slivers: [
              // 头部
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(hPad),
                  child: mobile
                      // ── Mobile: avatar on top, info centered below ──
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
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
                            const SizedBox(height: 16),
                            // 返回
                            InkWell(
                              onTap: () => GoRouter.of(context).canPop() ? context.pop() : context.go('/home'),
                              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: Semantics(
                                button: true,
                                label: S.of(context).tooltipBack,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      S.of(context).commonBack,
                                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              artist.name,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.pageTitle.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              S.of(context).artistAlbumCount(albums.length),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.chipLabel.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () async {
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
                                } catch (e) {
                                  debugPrint('Failed to play all songs: $e');
                                }
                              },
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: Text(S.of(context).albumPlayAll),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ],
                        )
                      // ── Desktop: avatar left, info right ──
                      : Row(
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
                                    onTap: () => GoRouter.of(context).canPop() ? context.pop() : context.go('/home'),
                                    customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    child: Semantics(
                                      button: true,
                                      label: S.of(context).tooltipBack,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.arrow_back,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            S.of(context).commonBack,
                                            style: Theme.of(context).textTheme.songSubtitle.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    artist.name,
                                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    S.of(context).artistAlbumCount(albums.length),
                                    style: Theme.of(context).textTheme.chipLabel.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                          } catch (e) {
                                            debugPrint('Failed to play all songs: $e');
                                          }
                                        },
                                        icon: const Icon(Icons.play_arrow, size: 18),
                                        label: Text(S.of(context).albumPlayAll),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 40),
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
                  padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
                  child: Text(
                    S.of(context).homeAlbums,
                    style: Theme.of(context).textTheme.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              // 专辑网格
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final album = albums[index];
                    return Semantics(
                      button: true,
                      label: album.name,
                      child: InkWell(
                      onTap: () => context.go('/album/${album.id}'),
                      borderRadius: BorderRadius.circular(12),
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
                            style: Theme.of(context).textTheme.songTitle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${album.year ?? '—'}',
                            style: Theme.of(context).textTheme.songDuration.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    );
                  }, childCount: albums.length),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
            },
          ),
        );
      },
    );
  }
}
