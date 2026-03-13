import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
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

  const SongContextMenu({
    super.key,
    required this.song,
    required this.child,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showMenu(context, ref, details.globalPosition),
      onLongPressStart: (details) =>
          _showMenu(context, ref, details.globalPosition),
      child: child,
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
    String value,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
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
