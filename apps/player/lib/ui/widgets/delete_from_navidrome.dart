import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/cloud_auth_dialog.dart';

Future<bool> deleteLibrarySongFromNavidrome(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  VoidCallback? onDeleted,
}) {
  return deleteLibrarySongsFromNavidrome(context, ref, [
    song,
  ], onDeleted: onDeleted);
}

Future<bool> deleteLibrarySongsFromNavidrome(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs, {
  VoidCallback? onDeleted,
}) async {
  final targets = [
    for (final song in songs)
      if (!song.isOnline && !song.isRadio && song.id.isNotEmpty) song,
  ];
  if (targets.isEmpty) return false;
  final l10n = S.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final serverId = ref.read(serverConfigProvider).serverId;
  final deleteService = ref.read(navidromeDeleteServiceProvider);
  final backend = deleteService.backendClient;
  if (backend.isConfigured &&
      ref.read(cloudAuthProvider).value?.isAuthenticated != true) {
    final signedIn = await CloudAuthDialog.show(context);
    if (!signedIn || !context.mounted) return false;
  } else if (!backend.canMutateNas) {
    messenger.showSnackBar(_message(l10n.nasAgentConfigRequired));
    return false;
  }

  final first = targets.first;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.contextMenuDeleteTitle),
      content: Text(
        targets.length == 1
            ? l10n.contextMenuDeleteConfirm(first.title, first.artist)
            : l10n.libraryAuditDeleteSelectedConfirm(targets.length),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  if (!context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.contextMenuDeleting),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  var deleted = false;
  Object? deleteError;
  try {
    if (targets.length == 1) {
      await deleteService.deleteLibrarySong(targets.single);
    } else {
      await deleteService.deleteLibrarySongIds([
        for (final song in targets) song.id,
      ]);
    }
    deleted = true;
  } catch (error) {
    deleteError = error;
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  if (!deleted) {
    if (context.mounted && deleteError != null) {
      messenger.showSnackBar(_message(_formatDeleteError(l10n, deleteError)));
    }
    return false;
  }

  if (ref.read(serverConfigProvider).serverId != serverId) {
    return true;
  }

  final playerService = ref.read(audioPlayerServiceProvider);
  final keys = {for (final song in targets) song.storageKey};
  for (var index = playerService.queue.length - 1; index >= 0; index--) {
    if (keys.contains(playerService.queue[index].storageKey)) {
      playerService.removeFromQueue(index);
    }
  }

  try {
    await ref.read(subsonicClientProvider).startScan();
  } catch (_) {}
  try {
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(newestSongsProvider);
    ref.invalidate(recentAlbumsProvider);
    await ref.read(libraryProvider.notifier).refresh();
  } catch (_) {}
  onDeleted?.call();
  if (context.mounted) {
    messenger.showSnackBar(
      _message(
        targets.length == 1
            ? l10n.contextMenuDeleted
            : l10n.libraryAuditBatchDeleted(targets.length),
      ),
    );
  }
  return true;
}

String _formatDeleteError(S l10n, Object error) {
  if (error is NasDeleteException) {
    final message = error.message.toLowerCase();
    if (message.contains('not found')) {
      return l10n.contextMenuDeleteNotFound;
    }
    return l10n.contextMenuDeleteFailedReason(_shortError(error.message));
  }
  if (error is StateError) {
    return l10n.nasAgentConfigRequired;
  }
  return l10n.contextMenuDeleteFailedReason(_shortError(error.toString()));
}

String _shortError(String message) {
  final text = message.trim();
  if (text.isEmpty) return 'unknown error';
  return text.length <= 120 ? text : '${text.substring(0, 117)}...';
}

SnackBar _message(String text) => SnackBar(
  content: Text(text),
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 3),
);
