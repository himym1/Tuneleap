import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/cloud_auth_dialog.dart';
import 'package:navidrome_player/ui/widgets/import_duplicate_dialog.dart';
import 'package:navidrome_player/ui/widgets/nas_import_queue_popup.dart';
import 'package:navidrome_player/utils/import_duplicate.dart';
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
  var replaceSongIds = const <String>[];
  final replaceSession = ref.read(libraryAuditReplaceTargetProvider);
  final preferredId = replaceSession?.current.songId;
  // Library-audit replace: user already picked the online result and the
  // local song id. Skip the duplicate picker and replace that id directly.
  if (preferredId != null && preferredId.isNotEmpty) {
    force = true;
    replaceSongIds = [preferredId];
  } else {
    final List<ImportDuplicateCandidate> candidates;
    try {
      final local = await localClient.search3(
        song.title,
        songCount: 20,
        albumCount: 0,
        artistCount: 0,
      );
      candidates = importDuplicateCandidates(
        incoming: song,
        locals: local.songs,
      );
    } catch (_) {
      messenger.showSnackBar(_message(l10n.importDuplicateCheckFailed));
      return false;
    }
    if (candidates.isNotEmpty) {
      if (!context.mounted) return false;
      final maxBitRate = ref.read(audioQualityProvider);
      var incomingQuality = incomingImportQuality(maxBitRate: maxBitRate);
      try {
        final playback = await backend.probePlaybackInfo(
          song,
          maxBitRate: maxBitRate,
        );
        incomingQuality = incomingQualityFromPlayback(
          maxBitRate: maxBitRate,
          url: playback.url,
          cloudBr: playback.br,
          cloudType: playback.type,
          cloudSize: playback.size,
          durationSeconds: song.duration,
        );
      } catch (_) {}
      if (!context.mounted) return false;
      final decision = await showImportDuplicateDialog(
        context: context,
        incoming: song,
        candidates: candidates,
        incomingQuality: incomingQuality,
      );
      if (!decision.shouldImport) return false;
      force = true;
      replaceSongIds = decision.replaceSongIds;
    }
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

  final enqueued = queue.enqueue(
    song,
    force: force,
    replaceSongIds: replaceSongIds,
  );
  if (!enqueued) {
    messenger.showSnackBar(_message(l10n.nasImportAlreadyQueued));
    return true;
  }

  onImported?.call();
  if (preferredId != null && replaceSongIds.contains(preferredId)) {
    ref.read(libraryAuditProvider.notifier).removeFinding(preferredId);
    ref.read(libraryAuditReplaceTargetProvider.notifier).completeCurrent();
  }
  if (!context.mounted) return true;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.contextMenuQueuedNavidrome),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: l10n.nasImportViewQueue,
        onPressed: () => showNasImportQueuePopup(context),
      ),
    ),
  );
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

SnackBar _message(String text) => SnackBar(
  content: Text(text),
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 3),
);
