import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/api/subsonic_client.dart'
    show LyricsLine, LyricsList;
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';

/// 底部迷你播放条
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static String _getCurrentLyricLine(
    List<LyricsLine> lines,
    Duration position,
  ) {
    final posMs = position.inMilliseconds;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].startMs != null && lines[i].startMs! <= posMs) {
        return lines[i].text;
      }
    }
    return lines.isNotEmpty ? lines.first.text : '';
  }

  static String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<Song?>(
      stream: playerService.currentSongStream,
      builder: (context, snapshot) {
        final currentSong = snapshot.data ?? playerService.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final resolver = ref.watch(songMediaResolverProvider);

        return FutureBuilder<String>(
          future: resolver.coverArtUrl(currentSong, size: 100),
          builder: (context, coverSnapshot) => ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 600;
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Mobile: cover + info + play/next (original layout)
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    dynamic playerService,
    Song currentSong,
    String coverUrl,
  ) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => context.go('/player'),
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: Row(
            children: [
              _buildCover(coverUrl),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildSongInfo(
                    context,
                    ref,
                    currentSong,
                    playerService,
                  ),
                ),
              ),
              _buildPlayPauseButton(playerService),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 28),
                onPressed: () => playerService.next(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Desktop: [left: cover+info] [center: controls+progress] [right: volume+queue]
  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    dynamic playerService,
    Song currentSong,
    String coverUrl,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: Row(
        children: [
          // ── Left: cover ──
          GestureDetector(
            onTap: () => context.go('/player'),
            child: _buildCover(coverUrl),
          ),
          // ── Left: song info ──
          Expanded(
            flex: 3,
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: () => context.go('/player'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${currentSong.artist} - ${currentSong.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 24),
                      onPressed: () => playerService.previous(),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    _buildPlayPauseButton(playerService),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 24),
                      onPressed: () => playerService.next(),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
                // Progress bar
                _buildProgressBar(context, playerService),
              ],
            ),
          ),

          // ── Right: volume + queue ──
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildVolumeControl(context, playerService),
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded, size: 22),
                  onPressed: () => context.go('/player'),
                  tooltip: 'Queue',
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(String coverUrl) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CoverArt(url: coverUrl, size: 48, borderRadius: 6),
    );
  }

  Widget _buildSongInfo(
    BuildContext context,
    WidgetRef ref,
    Song currentSong,
    dynamic playerService,
  ) {
    final resolver = ref.read(songMediaResolverProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentSong.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          '${currentSong.artist} - ${currentSong.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        FutureBuilder<LyricsList?>(
          future: resolver.lyrics(currentSong),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return const SizedBox.shrink();
            }
            final lyrics = snapshot.data!;
            if (lyrics.lines.isEmpty) {
              return const SizedBox.shrink();
            }
            return StreamBuilder<Duration>(
              stream: playerService.positionStream,
              builder: (context, posSnapshot) {
                final position = posSnapshot.data ?? Duration.zero;
                final currentLine = lyrics.synced
                    ? _getCurrentLyricLine(lyrics.lines, position)
                    : lyrics.lines.first.text;
                return Text(
                  currentLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton(dynamic playerService) {
    return StreamBuilder<bool>(
      stream: playerService.playingStream,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        return IconButton(
          icon: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 32,
          ),
          onPressed: () =>
              playing ? playerService.pause() : playerService.play(),
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, dynamic playerService) {
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
                    _formatDuration(position),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    _formatDuration(duration),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildVolumeControl(BuildContext context, dynamic playerService) {
    return StatefulBuilder(
      builder: (context, setState) {
        var volume = playerService.player.volume as double;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              volume <= 0
                  ? Icons.volume_off_rounded
                  : volume < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(
              width: 100,
              child: SliderTheme(
                data: AppTextStyles.miniSliderTheme(context),
                child: Slider(
                  value: volume,
                  onChanged: (value) {
                    playerService.setVolume(value);
                    setState(() => volume = value);
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
