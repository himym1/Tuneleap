import 'package:flutter/material.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/audio_visualizer_bars.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';

/// 统一歌曲列表项组件 — 支持封面模式 / 曲序模式、悬停反馈与正在播放指示
class SongTile extends StatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool showCover;
  final bool cardStyle;
  final bool isActive;
  final bool isPlaying;
  final bool showHoverPlay;
  final Widget? trailingExtra;
  final double coverSize;
  final String? leadingText;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onMore,
    this.showCover = false,
    this.cardStyle = false,
    this.isActive = false,
    this.isPlaying = false,
    this.showHoverPlay = false,
    this.trailingExtra,
    this.coverSize = 44,
    this.leadingText,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final colors = context.colors;
    final metadata = [
      song.artist,
      song.album,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    final radius = widget.cardStyle ? AppDimensions.cardRadiusSmall : 10.0;
    final bgColor = widget.isActive
        ? colors.primarySoftSubtle
        : widget.cardStyle
        ? (_hovered ? colors.cardHoverSurface : colors.cardSurface)
        : (_hovered ? colors.cardSurface : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius),
          border: widget.cardStyle || widget.isActive
              ? Border.all(
                  color: widget.isActive
                      ? colors.primary.withValues(alpha: 0.35)
                      : (_hovered
                            ? colors.hairlineBorderStrong
                            : colors.hairlineBorder),
                  width: 0.7,
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: Semantics(
            button: widget.onTap != null,
            label: metadata.isEmpty ? song.title : '${song.title}, $metadata',
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: widget.onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.cardStyle ? 10 : 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildLeading(context),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.songTitle
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: widget.isActive
                                      ? colors.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          if (metadata.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              metadata,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.songSubtitle
                                  .copyWith(
                                    color: widget.isActive
                                        ? colors.primary.withValues(alpha: 0.78)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.trailingExtra != null) ...[
                      const SizedBox(width: 4),
                      widget.trailingExtra!,
                    ],
                    if (song.duration != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        song.formattedDuration,
                        style: Theme.of(context).textTheme.songDuration
                            .copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (widget.showHoverPlay) ...[
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        opacity: _hovered || widget.isActive ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          widget.isActive && widget.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          size: 24,
                          color: _hovered || widget.isActive
                              ? colors.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (widget.onMore != null) ...[
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                        tooltip: S.of(context).tooltipMore,
                        onPressed: widget.onMore,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    final colors = context.colors;
    if (widget.showCover) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ResolvedSongCoverArt(
            song: widget.song,
            size: widget.coverSize,
            borderRadius: 8,
            hasShadow: true,
          ),
          if (widget.isActive)
            Container(
              width: widget.coverSize,
              height: widget.coverSize,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: AudioVisualizerBars(
                isPlaying: widget.isPlaying,
                size: 16,
                color: Colors.white,
              ),
            ),
        ],
      );
    }

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.isActive ? colors.primarySoft : colors.subtleSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: widget.isActive
          ? AudioVisualizerBars(
              isPlaying: widget.isPlaying,
              size: 14,
              color: colors.primary,
            )
          : Text(
              widget.leadingText ?? widget.song.track?.toString() ?? '#',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}
