import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/providers.dart';

class SaveQueuePlaylistButton extends ConsumerWidget {
  const SaveQueuePlaylistButton({required this.queue, super.key});

  final List<Song> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: S.of(context).playlistSaveQueue,
      icon: const Icon(Icons.playlist_add, size: 21),
      onPressed: queue.isEmpty ? null : () => _save(context, ref),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final serverId = ref.read(serverConfigProvider).serverId;
    final queueLength = queue.length;
    final localSongs = queue.where((song) => !song.isOnline).toList();
    final skipped = queueLength - localSongs.length;
    if (localSongs.isEmpty) {
      _message(context, S.of(context).playlistQueueNoLocalSongs);
      return;
    }

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _PlaylistNameDialog(),
    );
    if (name == null || !context.mounted) return;
    if (ref.read(serverConfigProvider).serverId != serverId) {
      _message(context, S.of(context).playlistQueueSaveFailed);
      return;
    }

    try {
      await ref
          .read(subsonicClientProvider)
          .createPlaylist(
            name,
            songIds: localSongs.map((song) => song.id).toList(),
          );
      if (!context.mounted ||
          ref.read(serverConfigProvider).serverId != serverId) {
        return;
      }
      ref.invalidate(playlistsProvider);
      _message(
        context,
        skipped == 0
            ? S.of(context).playlistQueueSaved(name)
            : S.of(context).playlistQueueSavedSkipped(name, skipped),
      );
    } catch (_) {
      if (context.mounted) {
        _message(context, S.of(context).playlistQueueSaveFailed);
      }
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog();

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).playlistSaveQueue),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: S.of(context).playlistNameLabel),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.of(context).commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(S.of(context).commonSave)),
      ],
    );
  }
}
