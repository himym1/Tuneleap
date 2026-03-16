import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/api/subsonic_client.dart'
    show LyricsLine, LyricsList;
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/utils/duration_format.dart';

/// 底部迷你播放条
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.alwaysVisible = false});

  final bool alwaysVisible;

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
              final isDesktop = constraints.maxWidth > 600;
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
    final accentColor = ref.watch(globalAccentColorProvider);
    final baseColor = context.colors.surfaceContainer;
    // 将 accent color 以 6% 的比例混入播放条背景
    final chromeColor = Color.lerp(baseColor, accentColor, 0.06)!.withValues(alpha: 0.88);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          decoration: BoxDecoration(
            color: chromeColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }

  /// Mobile: cover + info + play/next (original layout)
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
          onTap: () => context.push('/player'),
          child: SizedBox(
            width: double.infinity,
            height: AppDimensions.miniPlayerHeightMobile,
            child: Row(
              children: [
                _buildCover(coverUrl, useHero: true),
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
                  tooltip: S.of(context).playerNext,
                ),
                const SizedBox(width: 8),
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
    return SizedBox(
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
              onTap: () => context.push('/player'),
              child: _buildCover(coverUrl),
            ),
          ),
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
                  onTap: () => context.push('/player'),
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
                      tooltip: S.of(context).playerPrevious,
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
                      tooltip: S.of(context).playerNext,
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

          // ── Right: volume + actions ──
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildVolumeControl(context, playerService),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopIdleLayout(BuildContext context) {
    final strings = S.of(context);
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.miniPlayerHeightDesktop,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.queue_music_rounded,
              color: context.colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
    );
  }

  Widget _buildCover(String coverUrl, {bool useHero = false}) {
    final art = CoverArt(url: coverUrl, size: 48, borderRadius: 6);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: useHero ? Hero(tag: 'player-cover', child: art) : art,
    );
  }

  Widget _buildSongInfo(
    BuildContext context,
    WidgetRef ref,
    Song currentSong,
    AudioPlayerService playerService,
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
                    color: context.colors.primary,
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

  Widget _buildPlayPauseButton(AudioPlayerService playerService) {
    return StreamBuilder<bool>(
      stream: playerService.playingStream,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        return IconButton(
          icon: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 32,
          ),
          tooltip: S.of(context).playerPlayPause,
          onPressed: () =>
              playing ? playerService.pause() : playerService.play(),
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
              size: 20,
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