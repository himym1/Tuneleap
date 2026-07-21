import 'dart:io';
import 'package:flutter/material.dart';
import 'package:navidrome_player/services/update_checker.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 统一的更新弹窗 — 发现新版本 → 下载进度 → 安装
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  final String apiKey;

  const UpdateDialog({super.key, required this.info, required this.apiKey});

  /// 显示更新弹窗的便捷方法
  static void show(
    BuildContext context,
    AppUpdateInfo info, {
    required String apiKey,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info, apiKey: apiKey),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _UpdateState { info, downloading, installing, manualInstall, failed }

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdateState _state = _UpdateState.info;
  double _progress = 0;
  String? _error;

  Future<void> _startDownload() async {
    setState(() => _state = _UpdateState.downloading);

    final filePath = await downloadUpdate(
      widget.info,
      apiKey: widget.apiKey,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
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
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _state = _UpdateState.failed;
        _error = S.of(context).updateFailed;
      });
      return;
    }
    if (Platform.isMacOS) {
      setState(() => _state = _UpdateState.manualInstall);
      return;
    }
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
              Text(
                s.updateChangelog,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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
            Text(
              '$percent%',
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

      case _UpdateState.installing:
        return Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Text(s.updateCheckUpdate),
          ],
        );

      case _UpdateState.manualInstall:
        return Text(s.updateMacInstallHint);

      case _UpdateState.failed:
        return Text(
          _error ?? s.updateFailed,
          style: TextStyle(color: context.colors.error),
        );
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
          FilledButton(
            onPressed: _startDownload,
            child: Text(s.updateDownload),
          ),
        ];

      case _UpdateState.downloading:
        return []; // 下载中不能关闭

      case _UpdateState.installing:
        return [];

      case _UpdateState.manualInstall:
        return [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.commonConfirm),
          ),
        ];

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
