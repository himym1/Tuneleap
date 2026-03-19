import 'package:flutter/material.dart';
import 'package:navidrome_player/services/update_checker.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 统一的更新弹窗 — 发现新版本 → 下载进度 → 安装
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  /// 显示更新弹窗的便捷方法
  static void show(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _UpdateState { info, downloading, installing, failed }

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdateState _state = _UpdateState.info;
  double _progress = 0;
  String? _error;

  Future<void> _startDownload() async {
    final url = widget.info.downloadUrl;
    if (url == null) return;

    setState(() => _state = _UpdateState.downloading);

    final filePath = await downloadUpdate(
      url,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (filePath == null) {
      setState(() {
        _state = _UpdateState.failed;
        _error = S.of(context).updateFailed;
      });
      return;
    }

    setState(() => _state = _UpdateState.installing);

    final ok = await installUpdate(filePath);
    // 如果 macOS 走到这里说明 exit(0) 没执行（不会到这）
    // Android 的话 installUpdate 返回后用户在系统安装器里操作
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _state = _UpdateState.failed;
        _error = S.of(context).updateFailed;
      });
    }
    // Android: 安装器已弹出，关闭弹窗
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return AlertDialog(
      title: Text(s.updateNewVersion(widget.info.version)),
      content: _buildContent(s),
      actions: _buildActions(s),
    );
  }

  Widget _buildContent(S s) {
    switch (_state) {
      case _UpdateState.info:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.info.changelog != null) ...[
              Text(s.updateChangelog,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(widget.info.changelog!),
            ],
          ],
        );

      case _UpdateState.downloading:
        final percent = (_progress * 100).toInt();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _progress,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text('$percent%',
                style: TextStyle(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                )),
          ],
        );

      case _UpdateState.installing:
        return Row(
          children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: context.colors.primary),
            ),
            const SizedBox(width: 16),
            Text(s.updateCheckUpdate),
          ],
        );

      case _UpdateState.failed:
        return Text(_error ?? s.updateFailed,
            style: TextStyle(color: context.colors.error));
    }
  }

  List<Widget> _buildActions(S s) {
    switch (_state) {
      case _UpdateState.info:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.commonCancel),
          ),
          if (widget.info.downloadUrl != null)
            FilledButton(
              onPressed: _startDownload,
              child: Text(s.updateDownload),
            ),
        ];

      case _UpdateState.downloading:
        return []; // 下载中不能关闭

      case _UpdateState.installing:
        return [];

      case _UpdateState.failed:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.commonCancel),
          ),
          FilledButton(
            onPressed: () => setState(() {
              _state = _UpdateState.info;
              _progress = 0;
              _error = null;
            }),
            child: Text(s.commonRetry),
          ),
        ];
    }
  }
}
