import 'package:flutter/material.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 弹出播放列表重命名对话框，取消或空名称时返回 null。
Future<String?> showRenamePlaylistDialog({
  required BuildContext context,
  required String currentName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenamePlaylistDialog(currentName: currentName),
  );
}

class _RenamePlaylistDialog extends StatefulWidget {
  const _RenamePlaylistDialog({required this.currentName});

  final String currentName;

  @override
  State<_RenamePlaylistDialog> createState() => _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends State<_RenamePlaylistDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.of(context).playlistRename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: S.of(context).playlistNameLabel),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(S.of(context).commonSave),
        ),
      ],
    );
  }
}
