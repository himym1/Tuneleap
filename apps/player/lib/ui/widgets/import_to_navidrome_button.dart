import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/cloud_auth_dialog.dart';
import 'package:navidrome_player/utils/song_identity.dart';

Future<bool> importOnlineSongToNavidrome(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  VoidCallback? onImported,
}) async {
  if (!song.isOnline) return false;
  final l10n = S.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final serverId = ref.read(serverConfigProvider).serverId;
  final localClient = ref.read(subsonicClientProvider);
  final backend = ref.read(navidromeImportServiceProvider).backendClient;
  if (backend.isConfigured &&
      ref.read(cloudAuthProvider).value?.isAuthenticated != true) {
    final signedIn = await CloudAuthDialog.show(context);
    if (!signedIn || !context.mounted) return false;
  } else if (!backend.canMutateNas) {
    messenger.showSnackBar(_message(l10n.nasAgentConfigRequired));
    return false;
  }

  var force = false;
  try {
    final local = await localClient.search3(
      song.title,
      songCount: 20,
      albumCount: 0,
      artistCount: 0,
    );
    final identity = songWeakIdentity(song);
    final duplicate = local.songs.any(
      (candidate) => songWeakIdentity(candidate) == identity,
    );
    if (duplicate) {
      if (!context.mounted) return false;
      force = await _confirmDuplicate(context, l10n, song);
      if (!force) return false;
    }
  } catch (_) {
    messenger.showSnackBar(_message(l10n.importDuplicateCheckFailed));
    return false;
  }

  if (ref.read(serverConfigProvider).serverId != serverId) {
    messenger.showSnackBar(_message(l10n.contextMenuImportNavidromeFailed));
    return false;
  }

  final queue = ref.read(nasImportQueueProvider.notifier);
  if (queue.isQueuedOrActive(song)) {
    messenger.showSnackBar(_message(l10n.nasImportAlreadyQueued));
    return true;
  }

  final enqueued = queue.enqueue(song, force: force);
  if (!enqueued) {
    messenger.showSnackBar(_message(l10n.nasImportAlreadyQueued));
    return true;
  }

  onImported?.call();
  if (!context.mounted) return true;
  messenger.clearSnackBars();
  messenger.showSnackBar(_message(l10n.contextMenuQueuedNavidrome));
  return true;
}

class ImportToNavidromeButton extends ConsumerStatefulWidget {
  const ImportToNavidromeButton({
    required this.song,
    this.onImported,
    this.iconColor,
    super.key,
  });

  final Song song;
  final VoidCallback? onImported;
  final Color? iconColor;

  @override
  ConsumerState<ImportToNavidromeButton> createState() =>
      _ImportToNavidromeButtonState();
}

class _ImportToNavidromeButtonState
    extends ConsumerState<ImportToNavidromeButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(
      nasImportQueueProvider.select(
        (tasks) => tasks.any(
          (task) =>
              task.isActive &&
              songWeakIdentity(task.song) == songWeakIdentity(widget.song),
        ),
      ),
    );
    return IconButton(
      tooltip: S.of(context).contextMenuImportNavidrome,
      onPressed: (_loading || active)
          ? null
          : () async {
              setState(() => _loading = true);
              await importOnlineSongToNavidrome(
                context,
                ref,
                widget.song,
                onImported: widget.onImported,
              );
              if (mounted) setState(() => _loading = false);
            },
      icon: (_loading || active)
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.library_add_rounded, color: widget.iconColor),
    );
  }
}

Future<bool> _confirmDuplicate(BuildContext context, S l10n, Song song) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.importDuplicateTitle),
          content: Text(l10n.importDuplicateMessage(song.title, song.artist)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.importAnyway),
            ),
          ],
        ),
      ) ??
      false;
}

SnackBar _message(String text) => SnackBar(
  content: Text(text),
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 3),
);
