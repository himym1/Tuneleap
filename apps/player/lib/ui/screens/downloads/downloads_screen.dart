import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/stat_card.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';
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
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/settings');
      },
      child: ResponsivePageScaffold(
        body: ListView(
          padding: EdgeInsets.fromLTRB(0, h, 0, h),
          children: [
            Row(
              children: [
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => context.go('/settings'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                Text(
                  S.of(context).navDownloads,
                  style: Theme.of(context).textTheme.pageTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 统计卡片
            if (isMobile)
              Column(
                children: [
                  Row(
                    children: [
                      StatCard(
                        icon: Icons.download_done,
                        label: S.of(context).downloadsCompleted,
                        value: '$completed',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatCard(
                        icon: Icons.music_note,
                        label: S.of(context).downloadsOfflineSongs,
                        value:
                            '${tasks.where((t) => t.status == DownloadStatus.completed).length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      StatCard(
                        icon: Icons.storage,
                        label: S.of(context).downloadsUsedSpace,
                        value: S
                            .of(context)
                            .commonSizeMb(totalMb.toStringAsFixed(1)),
                      ),
                    ],
                  ),
                ],
              )
            else
              Row(
                children: [
                  StatCard(
                    icon: Icons.download_done,
                    label: S.of(context).downloadsCompleted,
                    value: '$completed',
                  ),
                  const SizedBox(width: 16),
                  StatCard(
                    icon: Icons.music_note,
                    label: S.of(context).downloadsOfflineSongs,
                    value:
                        '${tasks.where((t) => t.status == DownloadStatus.completed).length}',
                  ),
                  const SizedBox(width: 16),
                  StatCard(
                    icon: Icons.storage,
                    label: S.of(context).downloadsUsedSpace,
                    value: S
                        .of(context)
                        .commonSizeMb(totalMb.toStringAsFixed(1)),
                  ),
                ],
              ),
            const SizedBox(height: 28),

            Text(
              S.of(context).downloadsQueue,
              style: Theme.of(context).textTheme.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            if (tasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
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
                        style: Theme.of(context).textTheme.songSubtitle
                            .copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        S.of(context).downloadsHint,
                        style: Theme.of(context).textTheme.songSubtitle
                            .copyWith(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
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
                  style: Theme.of(context).textTheme.songTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.song.artist} · ${task.song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
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
                    style: Theme.of(
                      context,
                    ).textTheme.chipLabel.copyWith(color: context.colors.error),
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
      DownloadStatus.failed => (
        S.of(context).downloadsFailed,
        context.colors.error,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.chipLabel.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
