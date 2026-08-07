import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/playback_origin.dart';
import 'package:navidrome_player/ui/widgets/import_to_navidrome_button.dart';

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
  static Future<void> showForSong(
    BuildContext context,
    WidgetRef ref,
    Song song, {
    Offset? position,
    VoidCallback? onPlay,
    VoidCallback? onDeleted,
  }) {
    return SongContextMenu(
      song: song,
      onPlay: onPlay,
      onDeleted: onDeleted,
      child: const SizedBox.shrink(),
    )._showMenu(context, ref, position ?? const Offset(0, 0));
  }

  static Future<void> addToPlaylist(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) {
    return SongContextMenu(
      song: song,
      child: const SizedBox.shrink(),
    )._showPlaylistPicker(context, ref);
  }

  static Future<void> deleteSong(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) {
    return SongContextMenu(
      song: song,
      child: const SizedBox.shrink(),
    )._deleteSong(context, ref);
  }

  final Song song;
  final Widget child;
  final VoidCallback? onPlay;
  final VoidCallback? onDeleted;
  final PlaybackOrigin? playbackOrigin;
  final VoidCallback? onImported;

  const SongContextMenu({
    super.key,
    required this.song,
    required this.child,
    this.onPlay,
    this.onDeleted,
    this.playbackOrigin,
    this.onImported,
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

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final playerService = ref.read(audioPlayerServiceProvider);
    final client = ref.read(subsonicClientProvider);
    final resolver = ref.read(songMediaResolverProvider);
    final downloadManager = ref.read(downloadManagerProvider.notifier);
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
          await playerService.playSong(song, origin: playbackOrigin);
        }
        break;
      case 'play_next':
        playerService.playNext(song, origin: playbackOrigin);
        messenger.showSnackBar(_snackBar(l10n.contextMenuAddedNext));
        break;
      case 'add_queue':
        playerService.addToQueue(song, origin: playbackOrigin);
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
        if (context.mounted) {
          await importOnlineSongToNavidrome(
            context,
            ref,
            song,
            onImported: onImported,
          );
        }
        break;
      case 'delete':
        if (context.mounted) await _deleteSong(context, ref);
        break;
    }
  }

  Future<void> _deleteSong(BuildContext context, WidgetRef ref) async {
    final backend = ref.read(backendClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = S.of(context);
    if (!backend.canMutateNas) {
      messenger.showSnackBar(_snackBar(l10n.nasAgentConfigRequired));
      return;
    }
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
    try {
      final ok = await backend.deleteSongById(song.id);
      if (!ok) {
        messenger.showSnackBar(_snackBar(l10n.contextMenuDeleteFailed));
        return;
      }
      final playerService = ref.read(audioPlayerServiceProvider);
      final index = playerService.queue.indexWhere(
        (candidate) => candidate.storageKey == song.storageKey,
      );
      if (index >= 0) playerService.removeFromQueue(index);
      ref.invalidate(newestAlbumsProvider);
      ref.invalidate(recentAlbumsProvider);
      await ref.read(libraryProvider.notifier).refresh();
      onDeleted?.call();
      messenger.showSnackBar(_snackBar(l10n.contextMenuDeleted));
    } catch (error) {
      debugPrint('[Delete] failed: ${error.runtimeType}');
      messenger.showSnackBar(_snackBar(l10n.contextMenuDeleteFailed));
    }
  }

  SnackBar _snackBar(String message) => SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  );

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
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.chipLabel.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlaylistPicker(BuildContext context, WidgetRef ref) async {
    final service = ref.read(playlistServiceProvider);
    try {
      final playlists = await service.getPlaylists();
      if (!context.mounted) return;

      await showDialog<void>(
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
                          try {
                            await service.updatePlaylist(
                              p.id,
                              songIdsToAdd: [song.id],
                            );
                            if (!context.mounted) return;
                            ref.invalidate(playlistsProvider);
                            _showSnackBar(
                              context,
                              S.of(context).songContextAddedToPlaylist(p.name),
                            );
                          } catch (_) {
                            if (context.mounted) {
                              _showSnackBar(
                                context,
                                S.of(context).contextMenuLoadFailed,
                              );
                            }
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
