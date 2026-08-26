import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

/// Compact floating control: visible while imports are active or failed.
class NasImportQueueIndicator extends ConsumerWidget {
  const NasImportQueueIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(nasImportQueueProvider);
    final active = tasks.where((t) => t.isActive).length;
    final failed = tasks.where((t) => t.stage == NasImportStage.failed).length;
    if (active == 0 && failed == 0) return const SizedBox.shrink();

    final badge = active > 0 ? active : failed;
    final busy = active > 0;

    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showNasImportQueuePopup(context),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                busy ? Icons.cloud_upload_rounded : Icons.error_outline_rounded,
                color: busy ? context.colors.primary : context.colors.error,
              ),
              if (busy)
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: busy ? context.colors.primary : context.colors.error,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$badge',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.onEmphasis,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showNasImportQueuePopup(BuildContext context) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.55;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => const _NasImportQueueSheet(),
  );
}

class _NasImportQueueSheet extends ConsumerWidget {
  const _NasImportQueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(nasImportQueueProvider);
    final l10n = S.of(context);
    final finished = tasks
        .where(
          (t) =>
              t.stage == NasImportStage.completed ||
              t.stage == NasImportStage.failed,
        )
        .isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.downloadsNasImportTab,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (finished)
                TextButton(
                  onPressed: () =>
                      ref.read(nasImportQueueProvider.notifier).clearFinished(),
                  child: Text(l10n.nasImportClearFinished),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                l10n.downloadsNasImportEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _PopupTaskRow(
                    task: task,
                    onRemove: () => ref
                        .read(nasImportQueueProvider.notifier)
                        .remove(task.id),
                    onRetry: () => ref
                        .read(nasImportQueueProvider.notifier)
                        .retry(task.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PopupTaskRow extends StatelessWidget {
  const _PopupTaskRow({
    required this.task,
    required this.onRemove,
    required this.onRetry,
  });

  final NasImportTask task;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final busy =
        task.stage == NasImportStage.resolving ||
        task.stage == NasImportStage.uploading;
    final fraction = task.fraction;
    final (label, color) = switch (task.stage) {
      NasImportStage.pending => (
        S.of(context).downloadsPending,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      NasImportStage.resolving => (
        S.of(context).nasImportStageResolving,
        context.colors.primary,
      ),
      NasImportStage.uploading => (
        fraction != null
            ? '${S.of(context).nasImportStageUploading} · ${S.of(context).commonPercent((fraction * 100).round())}'
            : S.of(context).nasImportStageUploading,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
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
                  '${task.song.artist} · $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.songSubtitle.copyWith(color: color),
                ),
                if (busy) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: task.fraction,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  if (formatNasImportTransfer(task).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatNasImportTransfer(task),
                      style: Theme.of(context).textTheme.chipLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                if (task.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    localizeNasImportError(S.of(context), task.errorMessage),
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
          if (task.stage == NasImportStage.failed)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: S.of(context).commonRetry,
              onPressed: onRetry,
            ),
          if (!busy)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: S.of(context).tooltipRemove,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
