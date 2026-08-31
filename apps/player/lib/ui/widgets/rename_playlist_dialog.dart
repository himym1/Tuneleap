import 'package:flutter/material.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 弹出播放列表重命名对话框，取消或空名称时返回 null。
Future<String?> showRenamePlaylistDialog({
  required BuildContext context,
  required String currentName,
}) async {
  final controller = TextEditingController(text: currentName);
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).playlistRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: S.of(context).playlistNameLabel,
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(S.of(context).commonSave),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
