import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';

/// 底部迷你播放条
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final currentSong = playerService.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final client = ref.watch(subsonicClientProvider);
    final coverUrl = client.coverArtUrl(currentSong.coverArt, size: 100);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // 封面
              if (coverUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(coverUrl, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.music_note),
                  ),
                ),

              // 歌曲信息
              Expanded(
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
                        currentSong.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              // 播放控制
              StreamBuilder<bool>(
                stream: playerService.playingStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                    onPressed: () => playing ? playerService.pause() : playerService.play(),
                  );
                },
              ),
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
}
