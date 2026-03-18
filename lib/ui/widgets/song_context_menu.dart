import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 通用歌曲右键/长按上下文菜单
///
/// 使用方式：包裹歌曲列表项组件
/// ```dart
/// SongContextMenu(
///   song: song,
///   child: MyListTile(...),
/// )
/// ```
class SongContextMenu extends ConsumerWidget {
  final Song song;
  final Widget child;
  final VoidCallback? onPlay;
  final VoidCallback? onDeleted;

  const SongContextMenu({
    super.key,
    required this.song,
    required this.child,
    this.onPlay,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Builder(
      builder: (context) {
        final renderBox = context.findRenderObject() as RenderBox?;
        final menuPosition = renderBox == null
            ? Offset.zero
            : renderBox.localToGlobal(renderBox.size.center(Offset.zero));

        return Semantics(
          onLongPress: () => _showMenu(context, ref, menuPosition),
          hint: S.of(context).tooltipMore,
          child: GestureDetector(
            onSecondaryTapUp: (details) =>
                _showMenu(context, ref, details.globalPosition),
            onLongPressStart: (details) =>
                _showMenu(context, ref, details.globalPosition),
            child: child,
          ),
        );
      },
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref, Offset position) async {
    final playerService = ref.read(audioPlayerServiceProvider);
    final client = ref.read(subsonicClientProvider);
    final resolver = ref.read(songMediaResolverProvider);
    final downloadManager = ref.read(downloadManagerProvider.notifier);
    final importService = ref.read(navidromeImportServiceProvider);
    final supportsLibraryMutations = resolver.supportsLibraryMutations(song);
    // Capture messenger before async gap to avoid use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context);

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _menuItem(
          context,
          Icons.play_arrow_rounded,
          S.of(context).contextMenuPlay,
          'play',
        ),
        _menuItem(
          context,
          Icons.playlist_play,
          S.of(context).contextMenuPlayNext,
          'play_next',
        ),
        _menuItem(
          context,
          Icons.queue_music,
          S.of(context).contextMenuAddQueue,
          'add_queue',
        ),
        if (supportsLibraryMutations) const PopupMenuDivider(),
        if (supportsLibraryMutations)
          _menuItem(
            context,
            Icons.playlist_add,
            S.of(context).contextMenuAddPlaylist,
            'add_playlist',
          ),
        if (supportsLibraryMutations)
          _menuItem(
            context,
            Icons.favorite_border,
            S.of(context).navFavorites,
            'star',
          ),
        _menuItem(
          context,
          Icons.download_outlined,
          S.of(context).contextMenuDownload,
          'download',
        ),
        if (song.isOnline)
          _menuItem(
            context,
            Icons.library_add,
            S.of(context).contextMenuImportNavidrome,
            'import_navidrome',
          ),
        // 删除 — 仅 Subsonic 本地歌曲
        if (!song.isOnline) ...[
          const PopupMenuDivider(),
          _menuItem(
            context,
            Icons.delete_outline,
            S.of(context).contextMenuDelete,
            'delete',
            isDestructive: true,
          ),
        ],
      ],
    );

    if (value == null) return;
    switch (value) {
      case 'play':
        if (onPlay != null) {
          onPlay!();
        } else {
          await playerService.playSong(song);
        }
        break;
      case 'play_next':
        playerService.playNext(song);
        messenger.showSnackBar(_snackBar(l10n.contextMenuAddedNext));
        break;
      case 'add_queue':
        playerService.addToQueue(song);
        messenger.showSnackBar(_snackBar(l10n.contextMenuAddedQueue));
        break;
      case 'add_playlist':
        if (context.mounted) _showPlaylistPicker(context, ref);
        break;
      case 'star':
        await client.star(id: song.id);
        messenger.showSnackBar(_snackBar(l10n.contextMenuStarred));
        break;
      case 'download':
        await downloadManager.download(song);
        messenger.showSnackBar(_snackBar(l10n.contextMenuDownloading));
        break;
      case 'import_navidrome':
        messenger.showSnackBar(_snackBar(l10n.contextMenuQueueingNavidrome));
        try {
          final result = await importService.importOnlineSong(song);
          if (!context.mounted) return;
          messenger.showSnackBar(
            _snackBar(
              result.message == null || result.message!.isEmpty
                  ? l10n.contextMenuQueuedNavidrome
                  : '${l10n.contextMenuQueuedNavidrome}: ${result.message}',
            ),
          );
        } catch (error) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            _snackBar(
              '${l10n.contextMenuImportNavidromeFailed}: ${_formatImportError(error)}',
            ),
          );
        }
        break;
      case 'delete':
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.contextMenuDeleteTitle),
            content: Text(l10n.contextMenuDeleteConfirm(song.title, song.artist)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        debugPrint('[Delete] song.id: ${song.id}, song.title: ${song.title}');
        final tuneScout = ref.read(tuneScoutClientProvider);
        final ok = await tuneScout.deleteSongById(song.id);
        if (ok) {
          // 从播放队列移除该歌曲
          final queue = playerService.queue;
          final idx = queue.indexWhere((s) => s.storageKey == song.storageKey);
          if (idx >= 0) playerService.removeFromQueue(idx);
          // 刷新所有歌曲列表数据源
          ref.invalidate(newestAlbumsProvider);
          ref.invalidate(dailySongsProvider);
          ref.invalidate(recentAlbumsProvider);
          ref.read(libraryProvider.notifier).refresh();
          onDeleted?.call();
          messenger.showSnackBar(_snackBar(l10n.contextMenuDeleted));
        } else {
          messenger.showSnackBar(_snackBar(l10n.contextMenuDeleteFailed));
        }
        break;
    }
  }

  SnackBar _snackBar(String message) => SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  );

  String _formatImportError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'unknown error';
    }
    if (message.length <= 120) {
      return message;
    }
    return '${message.substring(0, 117)}...';
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final textColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.chipLabel.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaylistPicker(BuildContext context, WidgetRef ref) async {
    final client = ref.read(subsonicClientProvider);
    try {
      final playlists = await client.getPlaylists();
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(S.of(context).contextMenuSelectPlaylist),
          content: SizedBox(
            width: 300,
            child: playlists.isEmpty
                ? Text(S.of(context).playlistEmpty)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (_, i) {
                      final p = playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.playlist_play, size: 20),
                        title: Text(p.name),
                        subtitle: Text(
                          S
                              .of(context)
                              .playlistSongCountLabel(p.songCount ?? 0),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await client.updatePlaylist(
                            p.id,
                            songIdsToAdd: [song.id],
                          );
                          if (context.mounted) {
                            _showSnackBar(
                              context,
                              S.of(context).songContextAddedToPlaylist(p.name),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.of(context).commonCancel),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _showSnackBar(context, S.of(context).contextMenuLoadFailed);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
