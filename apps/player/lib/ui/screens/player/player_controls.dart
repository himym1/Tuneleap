import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/playback_mode_listener.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/utils/cover_color.dart';

/// 播放器进度条与时间标签
class PlayerProgressBar extends StatelessWidget {
  final AudioPlayerService playerService;
  final Color? activeColor;
  final Color? textColor;

  const PlayerProgressBar({
    super.key,
    required this.playerService,
    this.activeColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final actColor = activeColor ?? Theme.of(context).colorScheme.primary;
    final txtColor =
        textColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return StreamBuilder<Duration>(
      stream: playerService.positionStream,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: playerService.durationStream,
          builder: (context, durSnap) {
            final position = posSnap.data ?? Duration.zero;
            final duration = durSnap.data ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: actColor,
                    inactiveTrackColor: txtColor.withValues(alpha: 0.18),
                    thumbColor: actColor,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      final newPos = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      playerService.seekTo(newPos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(position),
                        style: Theme.of(context).textTheme.playerTimestamp
                            .copyWith(
                              color: txtColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        _fmt(duration),
                        style: Theme.of(context).textTheme.playerTimestamp
                            .copyWith(
                              color: txtColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// 播放控制按钮 — AnimatedIcon play/pause + 响应式 Repeat 状态
class PlaybackControls extends StatefulWidget {
  final AudioPlayerService playerService;
  final Color? accentColor;
  final Color? iconColor;

  const PlaybackControls({
    super.key,
    required this.playerService,
    this.accentColor,
    this.iconColor,
  });

  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;
  StreamSubscription<bool>? _playingSub;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _playing = widget.playerService.player.playing;
    _playPauseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: _playing ? 1.0 : 0.0,
    );
    _playingSub = widget.playerService.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _playing = playing);
      if (playing) {
        _playPauseController.forward();
      } else {
        _playPauseController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _playPauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btnColor = widget.accentColor ?? context.colors.primary;
    final btnFg = foregroundOn(btnColor);
    final controlColor =
        widget.iconColor ?? Theme.of(context).colorScheme.onSurface;
    final l10n = S.of(context);

    return PlaybackModeListener(
      playerService: widget.playerService,
      builder: (context, shuffle, repeatMode) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlaybackModeIconButton(
            selected: shuffle,
            icon: Icons.shuffle_rounded,
            iconColor: controlColor,
            tooltip: playbackShuffleTooltip(l10n, shuffle),
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.playerService.toggleShuffle();
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 32),
            color: controlColor,
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.playerService.previous();
            },
            tooltip: S.of(context).playerPrevious,
          ),
          const SizedBox(width: 8),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: btnColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: btnColor.withValues(alpha: 0.42),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              icon: AnimatedIcon(
                icon: AnimatedIcons.play_pause,
                progress: _playPauseController,
                size: 34,
                color: btnFg,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                if (_playing) {
                  widget.playerService.pause();
                } else {
                  widget.playerService.play();
                }
              },
              tooltip: S.of(context).playerPlayPause,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 32),
            color: controlColor,
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.playerService.next();
            },
            tooltip: S.of(context).playerNext,
          ),
          const SizedBox(width: 12),
          PlaybackModeIconButton(
            selected: repeatMode != PlaybackRepeatMode.off,
            icon: playbackRepeatIcon(repeatMode),
            iconColor: controlColor,
            tooltip: playbackRepeatTooltip(l10n, repeatMode),
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.playerService.cycleRepeatMode();
            },
          ),
        ],
      ),
    );
  }
}

/// GPU 合成的下拉关闭手势包裹器
class DragDismissWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const DragDismissWrapper({
    super.key,
    required this.child,
    required this.onDismiss,
  });

  @override
  State<DragDismissWrapper> createState() => _DragDismissWrapperState();
}

class _DragDismissWrapperState extends State<DragDismissWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragExtent = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dy).clamp(0.0, 300.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent > 120 || (details.primaryVelocity ?? 0) > 600) {
      widget.onDismiss();
    } else {
      final startValue = _dragExtent;
      _controller.reset();
      _controller.forward();
      late final VoidCallback listener;
      listener = () {
        if (!mounted) return;
        setState(() {
          _dragExtent =
              startValue * (1 - Curves.easeOut.transform(_controller.value));
        });
        if (_controller.isCompleted) {
          _controller.removeListener(listener);
        }
      };
      _controller.addListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent / 300).clamp(0.0, 1.0);
    return GestureDetector(
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Transform.translate(
        offset: Offset(0, _dragExtent),
        child: Opacity(opacity: 1.0 - progress * 0.4, child: widget.child),
      ),
    );
  }
}

/// 播放器右上角曲库操作菜单
class PlayerOverflowMenu extends ConsumerWidget {
  const PlayerOverflowMenu({super.key, required this.song, this.iconColor});

  final Song song;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canMutate = ref
        .read(songMediaResolverProvider)
        .supportsLibraryMutations(song);
    if (!canMutate) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: const Key('player-overflow-menu'),
      tooltip: S.of(context).playerMoreActions,
      icon: Icon(Icons.more_vert_rounded, color: iconColor),
      onSelected: (value) {
        if (value == 'playlist') {
          SongContextMenu.addToPlaylist(context, ref, song);
        } else if (value == 'delete') {
          SongContextMenu.deleteSong(context, ref, song);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'playlist',
          child: Text(S.of(context).contextMenuAddPlaylist),
        ),
        PopupMenuItem(
          key: const Key('player-delete-song-button'),
          value: 'delete',
          child: Text(
            S.of(context).contextMenuDelete,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}

/// 播放器底部音量与倍速控制条
class BottomVolumeAndUtilityRow extends StatelessWidget {
  const BottomVolumeAndUtilityRow({
    super.key,
    required this.playerService,
    required this.foreground,
    this.showSpeed = true,
  });

  final AudioPlayerService playerService;
  final Color foreground;
  final bool showSpeed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (showSpeed) ...[
            StreamBuilder<double>(
              stream: playerService.player.speedStream,
              builder: (context, snap) {
                final speed = snap.data ?? 1.0;
                return PopupMenuButton<double>(
                  tooltip: S.of(context).playerSpeed,
                  onSelected: (v) {
                    HapticFeedback.selectionClick();
                    playerService.setSpeed(v);
                  },
                  itemBuilder: (_) => [
                    for (final value in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                      PopupMenuItem(
                        value: value,
                        child: Text(S.of(context).playerSpeedValue(value)),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      S.of(context).playerSpeedValue(speed),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
          ],
          Icon(
            Icons.volume_down_rounded,
            size: 17,
            color: foreground.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: StreamBuilder<double>(
              stream: playerService.player.volumeStream,
              builder: (context, snapshot) {
                final volume = snapshot.data ?? playerService.player.volume;
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: foreground.withValues(alpha: 0.65),
                    inactiveTrackColor: foreground.withValues(alpha: 0.16),
                    thumbColor: foreground,
                  ),
                  child: Slider(
                    value: volume.clamp(0.0, 1.0),
                    onChanged: playerService.setVolume,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.volume_up_rounded,
            size: 17,
            color: foreground.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
