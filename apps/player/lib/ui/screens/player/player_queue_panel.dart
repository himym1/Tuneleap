import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/save_queue_playlist_button.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/utils/duration_format.dart';

/// 移动端底部弹出队列列表
void showMobileQueueSheet(
  BuildContext context,
  AudioPlayerService playerService, {
  VoidCallback? onQueueChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: context.colors.hairlineBorder, width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadowStrong,
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (ctx, scrollController) {
              final queue = playerService.queue;
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context).playerQueueTitle,
                          style: Theme.of(context).textTheme.playerSongName
                              .copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              S.of(context).commonSongs(queue.length),
                              style: Theme.of(context).textTheme.chipLabel
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            SaveQueuePlaylistButton(queue: playerService.queue),
                            IconButton(
                              tooltip: S.of(context).playerClearQueue,
                              onPressed: queue.isEmpty
                                  ? null
                                  : () async {
                                      await playerService.clearQueue();
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                              icon: const Icon(
                                Icons.clear_all_rounded,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: queue.isEmpty
                        ? Center(
                            child: Text(
                              S.of(context).playerQueueEmpty,
                              style: Theme.of(context).textTheme.songSubtitle
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        : StatefulBuilder(
                            builder: (context, setSheetState) {
                              return ReorderableListView.builder(
                                scrollController: scrollController,
                                itemCount: queue.length,
                                onReorderItem: (oldIndex, newIndex) {
                                  playerService.reorderQueue(
                                    oldIndex,
                                    newIndex,
                                  );
                                  setSheetState(() {});
                                  onQueueChanged?.call();
                                },
                                itemBuilder: (context, index) {
                                  final song = queue[index];
                                  final isCurrent =
                                      index == playerService.currentIndex;
                                  return ListTile(
                                    key: ValueKey('${song.id}_$index'),
                                    dense: true,
                                    leading: isCurrent
                                        ? Icon(
                                            Icons.equalizer_rounded,
                                            color: context.colors.primary,
                                            size: 18,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .playerTimestamp
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                    title: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .songTitle
                                          .copyWith(
                                            fontWeight: isCurrent
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: isCurrent
                                                ? context.colors.primary
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                          ),
                                    ),
                                    subtitle: Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .songSubtitle
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    trailing: QueueSongMenuButton(
                                      song: song,
                                      onPlay: () {
                                        playerService.skipToIndex(index);
                                        Navigator.pop(ctx);
                                      },
                                      onDeleted: onQueueChanged,
                                    ),
                                    onTap: () {
                                      playerService.skipToIndex(index);
                                      Navigator.pop(ctx);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// 桌面端右侧队列面板 — ReorderableListView + Dismissible
class DesktopQueuePanel extends StatefulWidget {
  final AudioPlayerService playerService;
  const DesktopQueuePanel({super.key, required this.playerService});

  @override
  State<DesktopQueuePanel> createState() => _DesktopQueuePanelState();
}

class _DesktopQueuePanelState extends State<DesktopQueuePanel> {
  @override
  Widget build(BuildContext context) {
    final ps = widget.playerService;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<Song?>(
      stream: ps.currentSongStream,
      builder: (context, _) {
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: AppDimensions.queuePanelWidth,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh
                    .withValues(alpha: isDark ? 0.85 : 0.90),
                border: Border(
                  left: BorderSide(
                    color: context.colors.hairlineBorder,
                    width: 0.8,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context).playerQueueTitle,
                          style: Theme.of(context).textTheme.playerQueueHeader,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              S.of(context).commonSongs(ps.queue.length),
                              style: Theme.of(context).textTheme.playerTimestamp
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            SaveQueuePlaylistButton(queue: ps.queue),
                            IconButton(
                              tooltip: S.of(context).playerClearQueue,
                              onPressed: ps.queue.isEmpty
                                  ? null
                                  : () async {
                                      await ps.clearQueue();
                                      if (mounted) setState(() {});
                                    },
                              icon: const Icon(
                                Icons.clear_all_rounded,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ps.queue.isEmpty
                        ? Center(
                            child: Text(
                              S.of(context).playerQueueEmpty,
                              style: Theme.of(context).textTheme.songSubtitle
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        : ReorderableListView.builder(
                            itemCount: ps.queue.length,
                            onReorderItem: (oldIndex, newIndex) {
                              setState(() {
                                ps.reorderQueue(oldIndex, newIndex);
                              });
                            },
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                color: context.colors.primarySoft,
                                elevation: 2,
                                borderRadius: BorderRadius.circular(8),
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final song = ps.queue[index];
                              final isCurrent = index == ps.currentIndex;
                              return Dismissible(
                                key: ValueKey('${song.id}_$index'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  color: context.colors.errorSoft,
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: context.colors.error,
                                    size: 20,
                                  ),
                                ),
                                onDismissed: (_) {
                                  setState(() {
                                    ps.removeFromQueue(index);
                                  });
                                },
                                child: Container(
                                  color: isCurrent
                                      ? context.colors.primarySoftSubtle
                                      : null,
                                  child: ListTile(
                                    dense: true,
                                    leading: isCurrent
                                        ? Icon(
                                            Icons.equalizer_rounded,
                                            color: context.colors.primary,
                                            size: 18,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .playerTimestamp
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                    title: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .chipLabel
                                          .copyWith(
                                            fontWeight: isCurrent
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: isCurrent
                                                ? context.colors.primary
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                          ),
                                    ),
                                    subtitle: Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .songSubtitle
                                          .copyWith(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (song.duration != null)
                                          Text(
                                            formatDuration(song.duration!),
                                            style: Theme.of(context)
                                                .textTheme
                                                .songDuration
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        QueueSongMenuButton(
                                          song: song,
                                          onPlay: () => ps.skipToIndex(index),
                                          onDeleted: () {
                                            if (mounted) setState(() {});
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Icon(
                                            Icons.drag_handle_rounded,
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => ps.skipToIndex(index),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 队列歌曲操作按钮
class QueueSongMenuButton extends ConsumerWidget {
  final Song song;
  final VoidCallback onPlay;
  final VoidCallback? onDeleted;

  const QueueSongMenuButton({
    super.key,
    required this.song,
    required this.onPlay,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: ValueKey('queue-song-menu-${song.storageKey}'),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      tooltip: S.of(context).tooltipMore,
      onPressed: () {
        final box = context.findRenderObject() as RenderBox?;
        final position = box == null
            ? MediaQuery.sizeOf(context).center(Offset.zero)
            : box.localToGlobal(box.size.center(Offset.zero));
        SongContextMenu.showForSong(
          context,
          ref,
          song,
          position: position,
          onPlay: onPlay,
          onDeleted: onDeleted,
        );
      },
      icon: const Icon(Icons.more_vert_rounded, size: 18),
    );
  }
}
