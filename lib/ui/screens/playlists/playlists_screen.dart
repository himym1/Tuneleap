import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final playlists = await client.getPlaylists();
      if (!mounted) return;
      setState(() {
        _playlists = playlists;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _createPlaylist() {
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
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitCreate(ctx, nameController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => _submitCreate(ctx, nameController.text),
            child: Text(S.of(context).commonCreate),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCreate(BuildContext ctx, String name) async {
    if (name.trim().isEmpty) return;
    Navigator.pop(ctx);
    try {
      final client = ref.read(subsonicClientProvider);
      await client.createPlaylist(name.trim());
      await _loadPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistCreated(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistCreateFailed)),
        );
      }
    }
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(S.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final client = ref.read(subsonicClientProvider);
      await client.deletePlaylist(playlist.id);
      setState(() => _playlists.removeWhere((p) => p.id == playlist.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistDeleted(playlist.name))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistDeleteFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).navPlaylists,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      S.of(context).playlistCount(_playlists.length),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _createPlaylist,
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _playlists.isEmpty
                ? _buildEmptyState()
                : _buildPlaylistGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).playlistEmptyHint,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGrid() {
    final client = ref.read(subsonicClientProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 260).floor().clamp(2, 5);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: _playlists.length,
          itemBuilder: (context, index) {
            final pl = _playlists[index];
            return _PlaylistCard(
              playlist: pl,
              coverUrl: client.coverArtUrl(pl.coverArt, size: 300),
              onTap: () => _openPlaylist(pl),
              onDelete: () => _deletePlaylist(pl),
              onRename: () => _renamePlaylist(pl),
            );
          },
        );
      },
    );
  }

  void _openPlaylist(Playlist playlist) async {
    try {
      final client = ref.read(subsonicClientProvider);
      final detail = await client.getPlaylist(playlist.id);
      if (!mounted) return;
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
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _renamePlaylistInDialog(
                                      ctx,
                                      playlist.id,
                                      playlistName,
                                      (newName) {
                                        setDialogState(
                                          () => playlistName = newName,
                                        );
                                        _loadPlaylists();
                                      },
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                S.of(context).commonSongs(songs.length),
                                style: TextStyle(
                                  fontSize: 12,
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
                  const Divider(height: 1),
                  Flexible(
                    child: songs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                S.of(context).playlistListEmpty,
                                style: TextStyle(
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
                            onReorder: (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) newIndex--;
                              final song = songs.removeAt(oldIndex);
                              songs.insert(newIndex, song);
                              setDialogState(() {});
                              // \u91cd\u6392\u5e8f\uff1a\u79fb\u9664\u65e7\u4f4d\u7f6e\uff0c\u63d2\u5165\u65b0\u4f4d\u7f6e
                              try {
                                await client.updatePlaylist(
                                  playlist.id,
                                  songIndexesToRemove: [oldIndex],
                                );
                                // \u91cd\u65b0\u6dfb\u52a0\u5230\u65b0\u4f4d\u7f6e\u524d\u7684\u6b4c\u66f2\u540e\u9762
                                // Subsonic API \u7684 updatePlaylist \u4f1a\u628a\u6b4c\u66f2\u52a0\u5230\u672b\u5c3e
                                // \u56e0\u6b64\u6211\u4eec\u9700\u8981\u91cd\u5efa\u6574\u4e2a\u5217\u8868
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
                              } catch (_) {}
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
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
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
                                        '${song.duration! ~/ 60}:${(song.duration! % 60).toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () async {
                                        try {
                                          await client.updatePlaylist(
                                            playlist.id,
                                            songIndexesToRemove: [i],
                                          );
                                          setDialogState(
                                            () => songs.removeAt(i),
                                          );
                                          _loadPlaylists();
                                        } catch (_) {}
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.remove_circle_outline,
                                          size: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
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
    } catch (_) {}
  }

  void _renamePlaylistInDialog(
    BuildContext ctx,
    String playlistId,
    String currentName,
    void Function(String) onRenamed,
  ) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: ctx,
      builder: (innerCtx) => AlertDialog(
        title: Text(S.of(context).playlistRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: S.of(context).playlistNewName,
            border: OutlineInputBorder(),
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
            } catch (_) {}
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerCtx),
            child: Text(S.of(context).commonCancel),
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
              } catch (_) {}
            },
            child: Text(S.of(context).commonConfirm),
          ),
        ],
      ),
    );
  }

  void _renamePlaylist(Playlist playlist) {
    _renamePlaylistInDialog(
      context,
      playlist.id,
      playlist.name,
      (_) => _loadPlaylists(),
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
            child: GestureDetector(
              onTap: onTap,
              child: CoverArt(url: coverUrl, borderRadius: 0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          S
                              .of(context)
                              .playlistSongCountLabel(playlist.songCount ?? 0),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
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
        color: selected ? AppColors.primarySoft : AppColors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected
              ? AppColors.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
