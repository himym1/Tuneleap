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
}) async {
  if (song.isOnline || song.isRadio) return false;
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

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.contextMenuDeleteTitle),
      content: Text(l10n.contextMenuDeleteConfirm(song.title, song.artist)),
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

  try {
    await deleteService.deleteLibrarySong(song);
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(_message(_formatDeleteError(l10n, error)));
    }
    return false;
  }

  if (ref.read(serverConfigProvider).serverId != serverId) {
    return true;
  }

  final playerService = ref.read(audioPlayerServiceProvider);
  final index = playerService.queue.indexWhere(
    (candidate) => candidate.storageKey == song.storageKey,
  );
  if (index >= 0) playerService.removeFromQueue(index);

  try {
    await ref.read(subsonicClientProvider).startScan();
  } catch (_) {}
  try {
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(recentAlbumsProvider);
    await ref.read(libraryProvider.notifier).refresh();
  } catch (_) {}
  onDeleted?.call();
  if (context.mounted) {
    messenger.showSnackBar(_message(l10n.contextMenuDeleted));
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
