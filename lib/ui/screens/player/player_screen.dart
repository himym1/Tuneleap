import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/api/subsonic_client.dart' show LyricsLine;
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 响应式播放器页面 — 移动端单栏 / PC 端双栏布局
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _showQueue = false;
  bool _showLyrics = false;
  List<LyricsLine>? _lyrics;
  String? _lyricsForSongId;
  final _lyricsScrollController = ScrollController();
  // PC 端页面切换
  final _desktopPageController = PageController();
  int _desktopCurrentPage = 0;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    _desktopPageController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics(Song song) async {
    if (_lyricsForSongId == song.storageKey && _lyrics != null) return;
    try {
      final resolver = ref.read(songMediaResolverProvider);
      final result = await resolver.lyrics(song);
      if (mounted) {
        setState(() {
          _lyrics = result?.lines ?? [];
          _lyricsForSongId = song.storageKey;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lyrics = [];
          _lyricsForSongId = song.storageKey;
        });
      }
    }
  }

  void _showMobileQueue(
    BuildContext context,
    AudioPlayerService playerService,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowStrong,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            S.of(context).commonSongs(queue.length),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: queue.isEmpty
                          ? Center(
                              child: Text(
                                S.of(context).playerQueueEmpty,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: queue.length,
                              itemBuilder: (context, index) {
                                final song = queue[index];
                                final isCurrent =
                                    index == playerService.currentIndex;
                                return ListTile(
                                  dense: true,
                                  leading: isCurrent
                                      ? Icon(
                                          Icons.equalizer,
                                          color: AppColors.primary,
                                          size: 18,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                  title: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isCurrent
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isCurrent
                                          ? AppColors.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  onTap: () {
                                    playerService.skipToIndex(index);
                                    Navigator.pop(ctx);
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

  Widget _buildLyricsPanel(Song currentSong, AudioPlayerService playerService) {
    final lyrics = _lyrics;
    if (lyrics == null || _lyricsForSongId != currentSong.storageKey) {
      _loadLyrics(currentSong);
      return Center(child: CircularProgressIndicator());
    }
    if (lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context).playerNoLyrics,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final hasSyncedLyrics = lyrics.any((l) => l.startMs != null);

    if (hasSyncedLyrics) {
      return StreamBuilder<Duration>(
        stream: playerService.player.positionStream,
        builder: (context, snapshot) {
          final posMs = (snapshot.data?.inMilliseconds ?? 0);
          int activeIndex = 0;
          for (int i = 0; i < lyrics.length; i++) {
            if (lyrics[i].startMs != null && lyrics[i].startMs! <= posMs) {
              activeIndex = i;
            }
          }
          // Auto-scroll to active line
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_lyricsScrollController.hasClients) {
              final target =
                  (activeIndex * 44.0) -
                  (_lyricsScrollController.position.viewportDimension / 2);
              _lyricsScrollController.animateTo(
                target.clamp(
                  0.0,
                  _lyricsScrollController.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.builder(
              controller: _lyricsScrollController,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              itemCount: lyrics.length,
              itemBuilder: (context, index) {
                final isActive = index == activeIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isActive ? 18 : 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: Text(
                      lyrics[index].text,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    // Unsynced lyrics — simple scrollable list
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        itemCount: lyrics.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              lyrics[index].text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final resolver = ref.watch(songMediaResolverProvider);

    return StreamBuilder<Song?>(
      stream: playerService.currentSongStream,
      builder: (context, snapshot) {
        final currentSong = snapshot.data ?? playerService.currentSong;

        if (currentSong == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_off,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    S.of(context).playerNoContent,
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.of(context).playerNoContentHint,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<String>(
          future: resolver.coverArtUrl(currentSong, size: 300),
          builder: (context, coverSnapshot) {
            final coverUrl = coverSnapshot.data ?? '';
            final accentColor = coverUrl.isEmpty
                ? AppColors.primary
                : (ref.watch(coverColorProvider(coverUrl)).value ??
                      AppColors.primary);
            final isMobile = MediaQuery.of(context).size.width < 600;

            return Scaffold(
              backgroundColor: AppColors.transparent,
              body: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.18),
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
                child: isMobile
                    ? _buildMobilePlayer(
                        context,
                        currentSong,
                        playerService,
                        coverUrl,
                      )
                    : _buildDesktopPlayer(currentSong, playerService, coverUrl),
              ),
            );
          },
        );
      },
    );
  }

  /// 移动端播放器 — 单栏垂直布局，全屏
  Widget _buildMobilePlayer(
    BuildContext context,
    Song currentSong,
    AudioPlayerService playerService,
    String coverUrl,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // 顶部导航栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 28,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  S.of(context).playerNowPlaying,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _showLyrics = !_showLyrics);
                        if (_showLyrics) {
                          _loadLyrics(currentSong);
                        }
                      },
                      child: Icon(
                        Icons.lyrics_outlined,
                        size: 22,
                        color: _showLyrics
                            ? AppColors.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _showMobileQueue(context, playerService),
                      child: Icon(
                        Icons.queue_music,
                        size: 24,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(flex: 1),
            // 大封面 / 歌词
            Flexible(
              flex: 5,
              child: _showLyrics
                  ? _buildLyricsPanel(currentSong, playerService)
                  : AspectRatio(
                      aspectRatio: 1,
                      child: CoverArt(url: coverUrl, borderRadius: 20),
                    ),
            ),
            const SizedBox(height: 28),
            // 歌曲信息
            Text(
              currentSong.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${currentSong.artist} · ${currentSong.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            // 进度条
            _ProgressBar(playerService: playerService),
            const SizedBox(height: 16),
            // 播放控制
            _PlaybackControls(playerService: playerService),
            const SizedBox(height: 12),
            // 底部操作
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_BottomActions(song: currentSong)],
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  /// PC 端播放器 — PageView 双页布局（信息页 ←→ 歌词页）+ 右侧队列面板
  Widget _buildDesktopPlayer(
    Song currentSong,
    AudioPlayerService playerService,
    String coverUrl,
  ) {
    // 滑到歌词页时自动加载
    if (_desktopCurrentPage == 1) {
      _loadLyrics(currentSong);
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // 主内容区 — 鼠标滚轮/触控板滑动切换
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: PageView(
                    controller: _desktopPageController,
                    scrollDirection: Axis.horizontal,
                    onPageChanged: (page) =>
                        setState(() => _desktopCurrentPage = page),
                    children: [
                      _buildDesktopInfoPage(coverUrl),
                      _buildDesktopLyricsPage(currentSong, playerService),
                    ],
                  ),
                ),
              ),
              // 页面指示器（小圆点）
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, (i) {
                    final isActive = _desktopCurrentPage == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
              // 底部固定：歌曲信息 + 进度条 + 播放控制 + 操作栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Text(
                      currentSong.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currentSong.artist} · ${currentSong.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProgressBar(playerService: playerService),
                    const SizedBox(height: 16),
                    _PlaybackControls(playerService: playerService),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BottomActions(song: currentSong),
                        const SizedBox(width: 8),
                        // 音量控制
                        StreamBuilder<double>(
                          stream: playerService.player.volumeStream,
                          builder: (context, snap) {
                            final vol = snap.data ?? 1.0;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  vol == 0
                                      ? Icons.volume_off
                                      : vol < 0.5
                                      ? Icons.volume_down
                                      : Icons.volume_up,
                                  size: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Slider(
                                    value: vol,
                                    min: 0.0,
                                    max: 1.0,
                                    onChanged: (v) =>
                                        playerService.setVolume(v),
                                    activeColor: AppColors.primary,
                                    inactiveColor: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // 播放速度
                        StreamBuilder<double>(
                          stream: playerService.player.speedStream,
                          builder: (context, snap) {
                            final speed = snap.data ?? 1.0;
                            return PopupMenuButton<double>(
                              tooltip: S.of(context).playerSpeed,
                              onSelected: (v) => playerService.setSpeed(v),
                              itemBuilder: (_) => [
                                for (final s in [
                                  0.5,
                                  0.75,
                                  1.0,
                                  1.25,
                                  1.5,
                                  2.0,
                                ])
                                  PopupMenuItem(
                                    value: s,
                                    child: Text(
                                      S.of(context).playerSpeedValue(s),
                                      style: TextStyle(
                                        fontWeight: s == speed
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: s == speed
                                            ? AppColors.primary
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  S.of(context).playerSpeedValue(speed),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.queue_music,
                            size: 22,
                            color: _showQueue
                                ? AppColors.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () =>
                              setState(() => _showQueue = !_showQueue),
                          tooltip: _showQueue
                              ? S.of(context).playerHideQueue
                              : S.of(context).playerShowQueue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_showQueue) _QueuePanel(playerService: playerService),
      ],
    );
  }

  /// PC 信息页 — 居中大封面
  Widget _buildDesktopInfoPage(String coverUrl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 360),
          child: AspectRatio(
            aspectRatio: 1,
            child: CoverArt(url: coverUrl, borderRadius: 16),
          ),
        ),
      ),
    );
  }

  /// PC 歌词页 — 全屏歌词滚动高亮
  Widget _buildDesktopLyricsPage(
    dynamic currentSong,
    AudioPlayerService playerService,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: _buildLyricsPanel(currentSong, playerService),
    );
  }
}

/// 底部操作栏 — 收藏按钮（全局 provider + 弹跳动画）
class _BottomActions extends ConsumerStatefulWidget {
  final Song song;
  const _BottomActions({required this.song});

  @override
  ConsumerState<_BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends ConsumerState<_BottomActions>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _toggleStar() {
    if (widget.song.isOnline) return;
    final isStarred =
        ref.read(starredSongsProvider).value?.contains(widget.song.id) ?? false;
    if (isStarred) {
      ref.read(starredSongsProvider.notifier).unstar(widget.song.id);
    } else {
      ref.read(starredSongsProvider.notifier).star(widget.song.id);
      _bounceController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.song.isOnline) {
      return const SizedBox.shrink();
    }
    final isStarred =
        ref.watch(starredSongsProvider).value?.contains(widget.song.id) ??
        false;
    return ScaleTransition(
      scale: _bounceAnimation,
      child: IconButton(
        icon: Icon(
          isStarred ? Icons.favorite : Icons.favorite_border,
          size: 22,
          color: isStarred
              ? AppColors.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: _toggleStar,
        tooltip: isStarred
            ? S.of(context).playerUnfavorite
            : S.of(context).navFavorites,
      ),
    );
  }
}

/// 右侧队列面板 — ReorderableListView + Dismissible
class _QueuePanel extends StatefulWidget {
  final AudioPlayerService playerService;
  const _QueuePanel({required this.playerService});

  @override
  State<_QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<_QueuePanel> {
  @override
  Widget build(BuildContext context) {
    final ps = widget.playerService;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  S.of(context).commonSongs(ps.queue.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ps.queue.isEmpty
                ? Center(
                    child: Text(
                      S.of(context).playerQueueEmpty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: ps.queue.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        ps.reorderQueue(oldIndex, newIndex);
                      });
                    },
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: AppColors.primarySoft,
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
                          color: AppColors.errorSoft,
                          child: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            ps.removeFromQueue(index);
                          });
                        },
                        child: Container(
                          color: isCurrent ? AppColors.primarySoftSubtle : null,
                          child: ListTile(
                            dense: true,
                            leading: isCurrent
                                ? Icon(
                                    Icons.equalizer,
                                    color: AppColors.primary,
                                    size: 18,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isCurrent
                                    ? AppColors.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
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
                                    '${song.duration! ~/ 60}:${(song.duration! % 60).toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(
                                    Icons.drag_handle,
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
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final dynamic playerService;
  const _ProgressBar({required this.playerService});

  @override
  Widget build(BuildContext context) {
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
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(position),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _fmt(duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
class _PlaybackControls extends StatefulWidget {
  final dynamic playerService;
  const _PlaybackControls({required this.playerService});

  @override
  State<_PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<_PlaybackControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;
  StreamSubscription<bool>? _playingSub;
  bool _playing = false;
  RepeatMode _repeatMode = RepeatMode.off;

  @override
  void initState() {
    super.initState();
    _repeatMode = widget.playerService.repeatMode as RepeatMode;
    _playPauseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _playingSub = (widget.playerService.playingStream as Stream<bool>).listen((
      playing,
    ) {
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            size: 22,
            color: widget.playerService.shuffle
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () => widget.playerService.toggleShuffle(),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 32),
          color: Theme.of(context).colorScheme.onSurface,
          onPressed: () => widget.playerService.previous(),
        ),
        const SizedBox(width: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _playPauseController,
              size: 32,
              color: AppColors.onEmphasis,
            ),
            onPressed: () => _playing
                ? widget.playerService.pause()
                : widget.playerService.play(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 32),
          color: Theme.of(context).colorScheme.onSurface,
          onPressed: () => widget.playerService.next(),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: Icon(
            _repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
            size: 22,
            color: _repeatMode != RepeatMode.off
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            widget.playerService.cycleRepeatMode();
            setState(
              () => _repeatMode = widget.playerService.repeatMode as RepeatMode,
            );
          },
        ),
      ],
    );
  }
}
