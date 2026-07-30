import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
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
  final importService = ref.read(navidromeImportServiceProvider);
  final backend = importService.backendClient;
  if (!backend.canMutateNas) {
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

  _showImporting(messenger, l10n);
  try {
    final result = await importService.importOnlineSong(song, force: force);
    if (ref.read(serverConfigProvider).serverId == serverId) {
      onImported?.call();
    }
    try {
      await localClient.startScan();
    } catch (_) {}
    if (!context.mounted) return true;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      _message(
        result.message == null || result.message!.isEmpty
            ? l10n.contextMenuQueuedNavidrome
            : '${l10n.contextMenuQueuedNavidrome}: ${result.message}',
      ),
    );
    return true;
  } on NasDuplicateException catch (error) {
    messenger.clearSnackBars();
    if (force || !context.mounted) {
      if (context.mounted) {
        messenger.showSnackBar(
          _message(
            '${l10n.contextMenuImportNavidromeFailed}: ${_formatError(error)}',
          ),
        );
      }
      return false;
    }
    final proceed = await _confirmDuplicate(context, l10n, song);
    if (!proceed || !context.mounted) return false;
    if (ref.read(serverConfigProvider).serverId != serverId) {
      messenger.showSnackBar(_message(l10n.contextMenuImportNavidromeFailed));
      return false;
    }
    _showImporting(messenger, l10n);
    try {
      final result = await importService.importOnlineSong(song, force: true);
      if (ref.read(serverConfigProvider).serverId == serverId) {
        onImported?.call();
      }
      try {
        await localClient.startScan();
      } catch (_) {}
      if (!context.mounted) return true;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        _message(
          result.message == null || result.message!.isEmpty
              ? l10n.contextMenuQueuedNavidrome
              : '${l10n.contextMenuQueuedNavidrome}: ${result.message}',
        ),
      );
      return true;
    } catch (error) {
      if (context.mounted) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          _message(
            '${l10n.contextMenuImportNavidromeFailed}: ${_formatError(error)}',
          ),
        );
      }
      return false;
    }
  } catch (error) {
    if (context.mounted) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        _message(
          '${l10n.contextMenuImportNavidromeFailed}: ${_formatError(error)}',
        ),
      );
    }
    return false;
  }
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
    return IconButton(
      tooltip: S.of(context).contextMenuImportNavidrome,
      onPressed: _loading
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
      icon: _loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.library_add_outlined, color: widget.iconColor),
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

void _showImporting(ScaffoldMessengerState messenger, S l10n) {
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.contextMenuQueueingNavidrome)),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 30),
    ),
  );
}

SnackBar _message(String text) => SnackBar(
  content: Text(text),
  behavior: SnackBarBehavior.floating,
  duration: const Duration(seconds: 3),
);

String _formatError(Object error) {
  final message = error.toString().trim();
  if (message.isEmpty) return 'unknown error';
  return message.length <= 120 ? message : '${message.substring(0, 117)}...';
}
