import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';
import 'package:navidrome_player/ui/widgets/segmented_control.dart';
import 'package:navidrome_player/ui/widgets/stat_card.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

enum _DownloadsTab { offline, nasImport }

/// 下载管理页面 — 本机离线下载 + NAS 导入曲库队列
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  _DownloadsTab _tab = _DownloadsTab.offline;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(downloadManagerProvider);
    final nasTasks = ref.watch(nasImportQueueProvider);
    final manager = ref.read(downloadManagerProvider.notifier);
    final completed = manager.completedCount;
    final totalMb = manager.totalSizeMb;
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    final activeNas = nasTasks.where((t) => t.isActive).length;

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
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
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
            const SizedBox(height: 16),
            AppSegmentedControl<_DownloadsTab>(
              selected: _tab,
              onSelected: (value) => setState(() => _tab = value),
              items: [
                AppSegmentItem(
                  value: _DownloadsTab.offline,
                  label: S.of(context).downloadsOfflineTab,
                  icon: Icons.phone_android_rounded,
                  badge: tasks.isEmpty ? null : '${tasks.length}',
                ),
                AppSegmentItem(
                  value: _DownloadsTab.nasImport,
                  label: S.of(context).downloadsNasImportTab,
                  icon: Icons.cloud_download_rounded,
                  badge: activeNas == 0 && nasTasks.isEmpty
                      ? null
                      : '${activeNas > 0 ? activeNas : nasTasks.length}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_tab == _DownloadsTab.offline)
              ..._offlineBody(
                context,
                tasks: tasks,
                completed: completed,
                totalMb: totalMb,
                isMobile: isMobile,
              )
            else
              ..._nasBody(context, nasTasks: nasTasks),
          ],
        ),
      ),
    );
  }

  List<Widget> _offlineBody(
    BuildContext context, {
    required List<DownloadTask> tasks,
    required int completed,
    required double totalMb,
    required bool isMobile,
  }) {
    return [
      if (isMobile)
        Column(
          children: [
            Row(
              children: [
                StatCard(
                  icon: Icons.download_done_rounded,
                  label: S.of(context).downloadsCompleted,
                  value: '$completed',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatCard(
                  icon: Icons.music_note_rounded,
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
                  icon: Icons.storage_rounded,
                  label: S.of(context).downloadsUsedSpace,
                  value: S.of(context).commonSizeMb(totalMb.toStringAsFixed(1)),
                ),
              ],
            ),
          ],
        )
      else
        Row(
          children: [
            StatCard(
              icon: Icons.download_done_rounded,
              label: S.of(context).downloadsCompleted,
              value: '$completed',
            ),
            const SizedBox(width: 16),
            StatCard(
              icon: Icons.music_note_rounded,
              label: S.of(context).downloadsOfflineSongs,
              value:
                  '${tasks.where((t) => t.status == DownloadStatus.completed).length}',
            ),
            const SizedBox(width: 16),
            StatCard(
              icon: Icons.storage_rounded,
              label: S.of(context).downloadsUsedSpace,
              value: S.of(context).commonSizeMb(totalMb.toStringAsFixed(1)),
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
        _EmptyBox(
          icon: Icons.cloud_download_outlined,
          title: S.of(context).downloadsEmpty,
          hint: S.of(context).downloadsHint,
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
    ];
  }

  List<Widget> _nasBody(
    BuildContext context, {
    required List<NasImportTask> nasTasks,
  }) {
    final active = nasTasks.where((t) => t.isActive).length;
    final done = nasTasks
        .where((t) => t.stage == NasImportStage.completed)
        .length;
    final failed = nasTasks
        .where((t) => t.stage == NasImportStage.failed)
        .length;
    final hasFinished = nasTasks.any((t) => !t.isActive);

    return [
      Row(
        children: [
          StatCard(
            icon: Icons.hourglass_top_rounded,
            label: S.of(context).downloadsPending,
            value: '$active',
          ),
          const SizedBox(width: 12),
          StatCard(
            icon: Icons.check_rounded,
            label: S.of(context).downloadsCompleted,
            value: '$done',
          ),
          const SizedBox(width: 12),
          StatCard(
            icon: Icons.error_outline_rounded,
            label: S.of(context).downloadsFailed,
            value: '$failed',
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text(
            S.of(context).downloadsNasImportTab,
            style: Theme.of(context).textTheme.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (hasFinished)
            TextButton(
              onPressed: () =>
                  ref.read(nasImportQueueProvider.notifier).clearFinished(),
              child: Text(S.of(context).nasImportClearFinished),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (nasTasks.isEmpty)
        _EmptyBox(
          icon: Icons.library_add_outlined,
          title: S.of(context).downloadsNasImportEmpty,
          hint: S.of(context).downloadsNasImportHint,
        )
      else
        ...nasTasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NasImportTaskTile(
              task: task,
              onRemove: () =>
                  ref.read(nasImportQueueProvider.notifier).remove(task.id),
              onRetry: () =>
                  ref.read(nasImportQueueProvider.notifier).retry(task.id),
            ),
          ),
        ),
    ];
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const _EmptyBox({
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              icon,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              icon: const Icon(Icons.close_rounded, size: 16),
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
    DownloadStatus.pending => Icons.schedule_rounded,
    DownloadStatus.downloading => Icons.download_rounded,
    DownloadStatus.completed => Icons.check_rounded,
    DownloadStatus.failed => Icons.error_outline_rounded,
  };

  Color _statusColor(BuildContext context) => switch (task.status) {
    DownloadStatus.pending => Theme.of(context).colorScheme.onSurfaceVariant,
    DownloadStatus.downloading => context.colors.primary,
    DownloadStatus.completed => context.colors.success,
    DownloadStatus.failed => context.colors.error,
  };
}

class _NasImportTaskTile extends StatelessWidget {
  final NasImportTask task;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const _NasImportTaskTile({
    required this.task,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final busy =
        task.stage == NasImportStage.resolving ||
        task.stage == NasImportStage.uploading;
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
                if (busy) ...[
                  const SizedBox(height: 6),
                  const LinearProgressIndicator(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ],
                if (task.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.errorMessage!,
                    maxLines: 2,
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
          _NasStatusChip(stage: task.stage),
          if (task.stage == NasImportStage.failed) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: S.of(context).commonRetry,
              onPressed: onRetry,
            ),
          ],
          if (!busy) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              tooltip: S.of(context).tooltipRemove,
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }

  IconData get _statusIcon => switch (task.stage) {
    NasImportStage.pending => Icons.schedule_rounded,
    NasImportStage.resolving => Icons.hourglass_top_rounded,
    NasImportStage.uploading => Icons.cloud_upload_rounded,
    NasImportStage.completed => Icons.check_rounded,
    NasImportStage.failed => Icons.error_outline_rounded,
  };

  Color _statusColor(BuildContext context) => switch (task.stage) {
    NasImportStage.pending => Theme.of(context).colorScheme.onSurfaceVariant,
    NasImportStage.resolving ||
    NasImportStage.uploading => context.colors.primary,
    NasImportStage.completed => context.colors.success,
    NasImportStage.failed => context.colors.error,
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

class _NasStatusChip extends StatelessWidget {
  final NasImportStage stage;

  const _NasStatusChip({required this.stage});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (stage) {
      NasImportStage.pending => (
        S.of(context).downloadsPending,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      NasImportStage.resolving => (
        S.of(context).nasImportStageResolving,
        context.colors.primary,
      ),
      NasImportStage.uploading => (
        S.of(context).nasImportStageUploading,
        context.colors.primary,
      ),
      NasImportStage.completed => (
        S.of(context).downloadsCompleted,
        context.colors.success,
      ),
      NasImportStage.failed => (
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
