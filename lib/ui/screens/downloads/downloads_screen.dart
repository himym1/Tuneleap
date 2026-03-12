import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 下载管理页面 — 统计卡片 + 实时下载队列
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final manager = ref.read(downloadManagerProvider.notifier);
    final completed = manager.completedCount;
    final totalMb = manager.totalSizeMb;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
        children: [
          Text(
            S.of(context).navDownloads,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // 统计卡片
          Row(
            children: [
              _StatCard(
                icon: Icons.download_done,
                label: S.of(context).downloadsCompleted,
                value: '$completed',
              ),
              const SizedBox(width: 16),
              _StatCard(
                icon: Icons.music_note,
                label: S.of(context).downloadsOfflineSongs,
                value:
                    '${tasks.where((t) => t.status == DownloadStatus.completed).length}',
              ),
              const SizedBox(width: 16),
              _StatCard(
                icon: Icons.storage,
                label: S.of(context).downloadsUsedSpace,
                value: S.of(context).commonSizeMb(totalMb.toStringAsFixed(1)),
              ),
            ],
          ),
          const SizedBox(height: 28),

          Text(
            S.of(context).downloadsQueue,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_download_outlined,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.of(context).downloadsEmpty,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.of(context).downloadsHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DownloadTaskTile(
                  task: task,
                  onRemove: () => ref
                      .read(downloadManagerProvider.notifier)
                      .removeTask(task.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 下载任务行 ─────────────────────────────────────────────────────────────────

class _DownloadTaskTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onRemove;

  const _DownloadTaskTile({required this.task, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _statusColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_statusIcon, size: 18, color: _statusColor(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.song.artist} · ${task.song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (task.status == DownloadStatus.downloading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: task.progress,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.colors.primary,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                if (task.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.errorMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.colors.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: task.status, progress: task.progress),
          if (task.status != DownloadStatus.downloading) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: S.of(context).tooltipRemove,
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }

  IconData get _statusIcon => switch (task.status) {
    DownloadStatus.pending => Icons.schedule,
    DownloadStatus.downloading => Icons.download,
    DownloadStatus.completed => Icons.check,
    DownloadStatus.failed => Icons.error_outline,
  };

  Color _statusColor(BuildContext context) => switch (task.status) {
    DownloadStatus.pending => Theme.of(context).colorScheme.onSurfaceVariant,
    DownloadStatus.downloading => context.colors.primary,
    DownloadStatus.completed => context.colors.success,
    DownloadStatus.failed => context.colors.error,
  };
}

class _StatusChip extends StatelessWidget {
  final DownloadStatus status;
  final double progress;

  const _StatusChip({required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DownloadStatus.pending => (
        S.of(context).downloadsPending,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      DownloadStatus.downloading => (
        S.of(context).commonPercent((progress * 100).toInt()),
        context.colors.primary,
      ),
      DownloadStatus.completed => (
        S.of(context).downloadsCompleted,
        context.colors.success,
      ),
      DownloadStatus.failed => (S.of(context).downloadsFailed, context.colors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── 统计卡片 ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.primarySoftAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: context.colors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
