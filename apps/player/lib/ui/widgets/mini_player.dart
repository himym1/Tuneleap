import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'dart:ui';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/audio_visualizer_bars.dart';
import 'package:navidrome_player/utils/duration_format.dart';
import 'package:navidrome_player/utils/player_navigation.dart';

/// 底部迷你播放条
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.alwaysVisible = false});

  final bool alwaysVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<Song?>(
      stream: playerService.currentSongStream,
      builder: (context, snapshot) {
        final currentSong = snapshot.data ?? playerService.currentSong;
        if (currentSong == null && !alwaysVisible) {
          return const SizedBox.shrink();
        }

        return _buildChrome(
          context,
          ref,
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = AppBreakpoints.isDesktop(constraints.maxWidth);
              if (currentSong == null) {
                return isDesktop
                    ? _buildDesktopIdleLayout(context)
                    : const SizedBox.shrink();
              }

              final resolver = ref.watch(songMediaResolverProvider);
              return FutureBuilder<String>(
                future: resolver.coverArtUrl(currentSong, size: 100),
                builder: (context, coverSnapshot) {
                  final coverUrl = coverSnapshot.data ?? '';
                  if (isDesktop) {
                    return _buildDesktopLayout(
                      context,
                      ref,
                      playerService,
                      currentSong,
                      coverUrl,
                    );
                  }
                  return _buildMobileLayout(
                    context,
                    ref,
                    playerService,
                    currentSong,
                    coverUrl,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChrome(BuildContext context, WidgetRef ref, Widget child) {
    final useCoverTint = ref.watch(themePresetProvider) == ThemePreset.dynamic;
    final accentColor = ref.watch(globalAccentColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = context.colors.surfaceContainer;
    final chromeColor = Color.lerp(
      baseColor,
      useCoverTint ? accentColor : baseColor,
      useCoverTint ? 0.08 : 0,
    )!.withValues(alpha: isDark ? 0.82 : 0.88);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          decoration: BoxDecoration(
            color: chromeColor,
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.12 : 0.06,
                ),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(top: false, bottom: !alwaysVisible, child: child),
        ),
      ),
    );
  }

  /// Mobile: cover + info + play/next (modern frosted floating card)
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    AudioPlayerService playerService,
    Song currentSong,
    String coverUrl,
  ) {
    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label: '${currentSong.title} - ${currentSong.artist}',
        hint: S.of(context).playerNowPlaying,
        child: InkWell(
          onTap: () => openPlayer(context),
          child: SizedBox(
            width: double.infinity,
            height: AppDimensions.miniPlayerHeightMobile,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _buildCover(coverUrl, useHero: true),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildSongInfo(
                          context,
                          currentSong,
                          playerService,
                        ),
                      ),
                      _buildPlayPauseButton(playerService),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 24),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          playerService.next();
                        },
                        tooltip: S.of(context).playerNext,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                // Seamless bottom progress line for mobile
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: StreamBuilder<Duration>(
                    stream: playerService.positionStream,
                    builder: (context, posSnapshot) {
                      final pos = posSnapshot.data ?? Duration.zero;
                      return StreamBuilder<Duration?>(
                        stream: playerService.durationStream,
                        builder: (context, durSnapshot) {
                          final dur = durSnapshot.data ?? Duration.zero;
                          final fraction = dur.inMilliseconds > 0
                              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0.0;
                          return LinearProgressIndicator(
                            value: fraction,
                            minHeight: 2,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.colors.primary.withValues(alpha: 0.8),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Desktop: [left: cover+info] [center: controls+progress] [right: volume+queue]
  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    AudioPlayerService playerService,
    Song currentSong,
    String coverUrl,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: AppDimensions.miniPlayerHeightDesktop,
        child: Row(
          children: [
            // ── Left: cover ──
            Semantics(
              button: true,
              label: '${currentSong.title} - ${currentSong.artist}',
              hint: S.of(context).playerNowPlaying,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => openPlayer(context),
                child: _buildCover(coverUrl, useHero: true, size: 46),
              ),
            ),
            const SizedBox(width: 4),
            // ── Left: song info ──
            Expanded(
              flex: 3,
              child: Semantics(
                button: true,
                label: '${currentSong.title} - ${currentSong.artist}',
                hint: S.of(context).playerNowPlaying,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => openPlayer(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.songTitle
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${currentSong.artist} - ${currentSong.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.songSubtitle
                                .copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Center: controls + progress ──
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Transport controls
                  StatefulBuilder(
                    builder: (context, setLocalState) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            size: 18,
                            color: playerService.shuffle
                                ? context.colors.primary
                                : context.colors.onSurfaceVariant,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            playerService.toggleShuffle();
                            setLocalState(() {});
                          },
                          tooltip: S.of(context).playerShuffle,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            size: 24,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            playerService.previous();
                          },
                          tooltip: S.of(context).playerPrevious,
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPlayPauseButton(playerService),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 24),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            playerService.next();
                          },
                          tooltip: S.of(context).playerNext,
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            playerService.repeatMode == PlaybackRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            size: 18,
                            color:
                                playerService.repeatMode !=
                                    PlaybackRepeatMode.off
                                ? context.colors.primary
                                : context.colors.onSurfaceVariant,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            playerService.cycleRepeatMode();
                            setLocalState(() {});
                          },
                          tooltip: S.of(context).playerRepeat,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  _buildProgressBar(context, playerService),
                ],
              ),
            ),

            // ── Right: volume + actions ──
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildVolumeControl(context, playerService),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.queue_music_rounded, size: 22),
                    tooltip: S.of(context).playerQueue,
                    onPressed: () => openPlayer(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopIdleLayout(BuildContext context) {
    final strings = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: AppDimensions.miniPlayerHeightDesktop,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: context.colors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.queue_music_rounded,
                color: context.colors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.playerIdleTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.playerIdleSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(
    String coverUrl, {
    bool useHero = false,
    double size = 40,
  }) {
    final art = CoverArt(
      url: coverUrl,
      size: size,
      borderRadius: 8,
      hasShadow: true,
    );
    return Padding(
      padding: const EdgeInsets.all(4),
      child: useHero ? Hero(tag: 'player-cover', child: art) : art,
    );
  }

  Widget _buildSongInfo(
    BuildContext context,
    Song currentSong,
    AudioPlayerService playerService,
  ) {
    return StreamBuilder<bool>(
      stream: playerService.playingStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentSong.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.songTitle.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                AudioVisualizerBars(
                  isPlaying: isPlaying,
                  size: 13,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 4),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${currentSong.artist} - ${currentSong.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayPauseButton(AudioPlayerService playerService) {
    return StreamBuilder<bool>(
      stream: playerService.playingStream,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: context.colors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 22,
              color: context.colors.onEmphasis,
            ),
            tooltip: S.of(context).playerPlayPause,
            onPressed: () {
              HapticFeedback.lightImpact();
              if (playing) {
                playerService.pause();
              } else {
                playerService.play();
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    AudioPlayerService playerService,
  ) {
    return StreamBuilder<Duration>(
      stream: playerService.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: playerService.durationStream,
          builder: (context, durSnapshot) {
            final duration = durSnapshot.data ?? Duration.zero;
            final maxVal = duration.inMilliseconds.toDouble();
            final curVal = position.inMilliseconds.toDouble().clamp(
              0.0,
              maxVal > 0 ? maxVal : 1.0,
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    formatPositionDuration(position),
                    style: Theme.of(context).textTheme.playerTimestamp.copyWith(
                      fontSize: 11,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: AppTextStyles.miniSliderTheme(context),
                      child: Slider(
                        value: curVal,
                        max: maxVal > 0 ? maxVal : 1.0,
                        onChanged: (value) {
                          playerService.seekTo(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                  ),
                  Text(
                    formatPositionDuration(duration),
                    style: Theme.of(context).textTheme.playerTimestamp.copyWith(
                      fontSize: 11,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVolumeControl(
    BuildContext context,
    AudioPlayerService playerService,
  ) {
    return StreamBuilder<double>(
      stream: playerService.player.volumeStream,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? playerService.player.volume;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              volume <= 0
                  ? Icons.volume_off_rounded
                  : volume < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
              size: 18,
              color: context.colors.onSurfaceVariant,
            ),
            SizedBox(
              width: AppDimensions.volumeSliderWidth,
              child: SliderTheme(
                data: AppTextStyles.miniSliderTheme(context),
                child: Slider(
                  value: volume,
                  onChanged: (value) {
                    playerService.setVolume(value);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
