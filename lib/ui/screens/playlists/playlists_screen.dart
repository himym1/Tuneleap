import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/utils/duration_format.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlaylists = ref.watch(playlistsProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile ? AppDimensions.paddingMobile : AppDimensions.paddingDesktop;

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 110,
              toolbarHeight: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(context).navPlaylists,
                        style: Theme.of(context).textTheme.pageTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            S.of(context).playlistCount(asyncPlaylists.value?.length ?? 0),
                            style: Theme.of(context).textTheme.songSubtitle.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: () => _createPlaylist(context, ref),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(S.of(context).commonNew),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  child: _FilterChip(
                    label: S.of(context).playlistCreatedList,
                    selected: true,
                  ),
                ),
              ),
            ),
          ],
          body: asyncPlaylists.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            ),
            error: (_, _) => Center(
              child: Text(
                S.of(context).commonLoadFailed,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            data: (playlists) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(playlistsProvider),
                child: playlists.isEmpty
                ? ListView(children: [const SizedBox(height: 200), _buildEmptyState(context)])
                : _buildPlaylistGrid(context, ref, playlists),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).navPlaylists,
                  style: Theme.of(context).textTheme.pageTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      S.of(context).playlistCount(asyncPlaylists.value?.length ?? 0),
                      style: Theme.of(context).textTheme.chipLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _createPlaylist(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(S.of(context).commonNew),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 分类标签
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: Row(
              children: [
                _FilterChip(
                  label: S.of(context).playlistCreatedList,
                  selected: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 列表网格
          Expanded(
            child: asyncPlaylists.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: context.colors.primary),
              ),
              error: (_, _) => Center(
                child: Text(
                  S.of(context).commonLoadFailed,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              data: (playlists) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(playlistsProvider),
                  child: playlists.isEmpty
                  ? ListView(children: [const SizedBox(height: 200), _buildEmptyState(context)])
                  : _buildPlaylistGrid(context, ref, playlists),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _createPlaylist(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).playlistCreate),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: S.of(context).playlistNameLabel,
          ),
          onSubmitted: (_) => _submitCreate(ctx, context, ref, nameController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => _submitCreate(ctx, context, ref, nameController.text),
            child: Text(S.of(context).commonCreate),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCreate(
    BuildContext ctx,
    BuildContext screenContext,
    WidgetRef ref,
    String name,
  ) async {
    if (name.trim().isEmpty) return;
    Navigator.pop(ctx);
    try {
      final client = ref.read(subsonicClientProvider);
      await client.createPlaylist(name.trim());
      ref.invalidate(playlistsProvider);
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(content: Text(S.of(screenContext).playlistCreated(name))),
        );
      }
    } catch (e) {
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(content: Text(S.of(screenContext).playlistCreateFailed)),
        );
      }
    }
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).playlistDeleteTitle),
        content: Text(S.of(context).playlistDeleteConfirm(playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            child: Text(S.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final client = ref.read(subsonicClientProvider);
      await client.deletePlaylist(playlist.id);
      ref.invalidate(playlistsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistDeleted(playlist.name))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistDeleteFailed)),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context).playlistEmptyTitle,
            style: Theme.of(context).textTheme.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).playlistEmptyHint,
            style: Theme.of(context).textTheme.songSubtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGrid(
    BuildContext context,
    WidgetRef ref,
    List<Playlist> playlists,
  ) {
    final client = ref.read(subsonicClientProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return _PlaylistListTile(
                playlist: pl,
                coverUrl: client.coverArtUrl(pl.coverArt, size: 300),
                onTap: () => _openPlaylist(context, ref, pl),
                onDelete: () => _deletePlaylist(context, ref, pl),
                onRename: () => _renamePlaylist(context, ref, pl),
              );
            },
          );
        }
        final crossAxisCount = (constraints.maxWidth / 260).floor().clamp(2, 5);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final pl = playlists[index];
            return _PlaylistCard(
              playlist: pl,
              coverUrl: client.coverArtUrl(pl.coverArt, size: 300),
              onTap: () => _openPlaylist(context, ref, pl),
              onDelete: () => _deletePlaylist(context, ref, pl),
              onRename: () => _renamePlaylist(context, ref, pl),
            );
          },
        );
      },
    );
  }

  void _openPlaylist(BuildContext context, WidgetRef ref, Playlist playlist) async {
    try {
      final client = ref.read(subsonicClientProvider);
      final detail = await client.getPlaylist(playlist.id);
      if (!context.mounted) return;
      final playerService = ref.read(audioPlayerServiceProvider);
      final songs = List<Song>.from(detail.songs);
      var playlistName = detail.name;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CoverArt(
                          url: client.coverArtUrl(detail.coverArt, size: 300),
                          size: 56,
                          borderRadius: 10,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      playlistName,
                                      style: Theme.of(context).textTheme.songTitle.copyWith(
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: S.of(context).playlistRename,
                                    child: InkWell(
                                      onTap: () => _renamePlaylistInDialog(
                                      ctx,
                                      context,
                                      ref,
                                      playlist.id,
                                      playlistName,
                                      (newName) {
                                        setDialogState(
                                          () => playlistName = newName,
                                        );
                                        ref.invalidate(playlistsProvider);
                                      },
                                    ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                S.of(context).commonSongs(songs.length),
                                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            if (songs.isNotEmpty) {
                              playerService.playAll(songs);
                            }
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(S.of(context).playlistPlay),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: songs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                S.of(context).playlistListEmpty,
                                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ReorderableListView.builder(
                            shrinkWrap: true,
                            itemCount: songs.length,
                            onReorderItem: (oldIndex, newIndex) async {
                              final song = songs.removeAt(oldIndex);
                              songs.insert(newIndex, song);
                              setDialogState(() {});
                              // 重排序：移除旧位置，插入新位置
                              try {
                                await client.updatePlaylist(
                                  playlist.id,
                                  songIndexesToRemove: [oldIndex],
                                );
                                // 重新添加到新位置前的歌曲后面
                                // Subsonic API 的 updatePlaylist 会把歌曲加到末尾
                                // 因此我们需要重建整个列表
                                final songIds = songs.map((s) => s.id).toList();
                                // 简化：删除并重建
                                await client.updatePlaylist(
                                  playlist.id,
                                  songIndexesToRemove: List.generate(
                                    songs.length,
                                    (i) => 0,
                                  ),
                                );
                                await client.updatePlaylist(
                                  playlist.id,
                                  songIdsToAdd: songIds,
                                );
                              } catch (e) {
                                debugPrint('Failed to add songs to playlist: $e');
                              }
                            },
                            itemBuilder: (ctx, i) {
                              final song = songs[i];
                              return ListTile(
                                key: ValueKey('${song.id}_$i'),
                                dense: true,
                                leading: CoverArt(
                                  url: client.coverArtUrl(
                                    song.coverArt,
                                    size: 80,
                                  ),
                                  size: 40,
                                  borderRadius: 6,
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.songTitle.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (song.duration != null)
                                      Text(
                                        formatDuration(song.duration!),
                                        style: Theme.of(context).textTheme.songDuration.copyWith(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    Semantics(
                                      button: true,
                                      label: S.of(context).commonDelete,
                                      child: InkWell(
                                        onTap: () async {
                                          try {
                                            await client.updatePlaylist(
                                              playlist.id,
                                              songIndexesToRemove: [i],
                                            );
                                            setDialogState(
                                              () => songs.removeAt(i),
                                            );
                                            ref.invalidate(playlistsProvider);
                                          } catch (e) {
                                            debugPrint('Failed to remove song from playlist: $e');
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Icon(
                                            Icons.remove_circle_outline,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  playerService.playAll(songs, startIndex: i);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to open playlist: $e');
    }
  }

  void _renamePlaylistInDialog(
    BuildContext ctx,
    BuildContext screenContext,
    WidgetRef ref,
    String playlistId,
    String currentName,
    void Function(String) onRenamed,
  ) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: ctx,
      builder: (innerCtx) => AlertDialog(
        title: Text(S.of(screenContext).playlistRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: S.of(screenContext).playlistNewName,
          ),
          onSubmitted: (_) async {
            final newName = controller.text.trim();
            if (newName.isEmpty) return;
            Navigator.pop(innerCtx);
            try {
              await ref
                  .read(subsonicClientProvider)
                  .updatePlaylist(playlistId, name: newName);
              onRenamed(newName);
            } catch (e) {
              debugPrint('Failed to rename playlist: $e');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerCtx),
            child: Text(S.of(screenContext).commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(innerCtx);
              try {
                await ref
                    .read(subsonicClientProvider)
                    .updatePlaylist(playlistId, name: newName);
                onRenamed(newName);
              } catch (e) {
                debugPrint('Failed to rename playlist: $e');
              }
            },
            child: Text(S.of(screenContext).commonConfirm),
          ),
        ],
      ),
    );
  }

  void _renamePlaylist(BuildContext context, WidgetRef ref, Playlist playlist) {
    _renamePlaylistInDialog(
      context,
      context,
      ref,
      playlist.id,
      playlist.name,
      (_) => ref.invalidate(playlistsProvider),
    );
  }
}

class _PlaylistListTile extends StatelessWidget {
  final Playlist playlist;
  final String coverUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _PlaylistListTile({
    required this.playlist,
    required this.coverUrl,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: CoverArt(url: coverUrl, size: 52, borderRadius: 8),
      title: Text(
        playlist.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.songTitle.copyWith(
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        S.of(context).playlistSongCountLabel(playlist.songCount ?? 0),
        style: Theme.of(context).textTheme.songSubtitle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: S.of(context).tooltipMore,
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'rename',
            child: Text(S.of(context).playlistRename),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(S.of(context).commonDelete),
          ),
        ],
        onSelected: (v) {
          if (v == 'delete') onDelete();
          if (v == 'rename') onRename();
        },
      ),
      onTap: onTap,
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final String coverUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _PlaylistCard({
    required this.playlist,
    required this.coverUrl,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: playlist.name,
              child: InkWell(
                onTap: onTap,
                child: CoverArt(url: coverUrl, borderRadius: 0),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: playlist.name,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.songTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          S
                              .of(context)
                              .playlistSongCountLabel(playlist.songCount ?? 0),
                          style: Theme.of(context).textTheme.songSubtitle.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: S.of(context).tooltipMore,
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(S.of(context).playlistRename),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(S.of(context).commonDelete),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                    if (v == 'rename') onRename();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _FilterChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? context.colors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? context.colors.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.chipLabel.copyWith(
          fontWeight: FontWeight.w500,
          color: selected
              ? context.colors.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
