import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/save_queue_playlist_button.dart';
import 'package:navidrome_player/ui/widgets/import_to_navidrome_button.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/theme/app_glass.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/api/subsonic_client.dart' show LyricsLine;
import 'package:navidrome_player/utils/cover_color.dart';
import 'package:navidrome_player/utils/duration_format.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/utils/request_generation.dart';
import 'package:navidrome_player/providers/server_scope.dart';

/// 响应式播放器页面 — 移动端单栏 / PC 端双栏布局
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // 跨 widget 实例保留的静态状态
  static final Map<String, List<LyricsLine>> _lyricsCache = {};
  static const int _lyricsCacheLimit = 100;
  static bool _lastShowLyrics = false;
  static bool _lastShowQueue = false;

  bool _showQueue = _lastShowQueue;
  bool _showLyrics = _lastShowLyrics;
  List<LyricsLine>? _lyrics;
  String? _lyricsForSongId;
  final RequestGeneration _lyricsRequests = RequestGeneration();
  final _lyricsScrollController = ScrollController();
  bool _userScrolling = false;
  Timer? _userScrollTimer;
  int _seekLineIndex = 0;
  StreamSubscription<Song?>? _songChangeSub;

  @override
  void initState() {
    super.initState();
    // 监听歌曲变化，在生命周期方法中触发歌词加载，避免在 build 中调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final playerService = ref.read(audioPlayerServiceProvider);
      _songChangeSub = playerService.currentSongStream.listen((song) {
        if (song != null && _showLyrics) _loadLyrics(song);
      });
      final currentSong = playerService.currentSong;
      if (currentSong != null && _showLyrics) _loadLyrics(currentSong);
    });
  }

  @override
  void dispose() {
    _songChangeSub?.cancel();
    _userScrollTimer?.cancel();
    _lyricsRequests.invalidate();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  String _lyricsKey(Song song) =>
      scopedSongKey(ref.read(serverConfigProvider).serverId, song.storageKey);

  Future<void> _loadLyrics(Song song) async {
    final request = _lyricsRequests.begin();
    final cacheKey = _lyricsKey(song);
    if (_lyricsForSongId == cacheKey && _lyrics != null) return;
    if (_lyricsCache.containsKey(cacheKey)) {
      debugPrint('[PlayerScreen] lyrics cache hit');
      setState(() {
        _lyrics = _lyricsCache[cacheKey];
        _lyricsForSongId = cacheKey;
      });
      return;
    }
    debugPrint('[PlayerScreen] loading lyrics: backend=${song.backend.name}');
    try {
      final resolver = ref.read(songMediaResolverProvider);
      final downloads = ref.read(downloadManagerProvider);
      final dlTask = downloads.where(
        (t) => t.id == song.storageKey && t.status == DownloadStatus.completed,
      );
      final localPath = dlTask.isNotEmpty ? dlTask.first.localPath : null;

      final result = await resolver.lyrics(song, localAudioPath: localPath);
      if (!_lyricsRequests.isCurrent(request) || !mounted) return;
      if (_lyricsKey(song) != cacheKey) return;
      final currentSong = ref.read(audioPlayerServiceProvider).currentSong;
      if (currentSong?.storageKey != song.storageKey) return;

      debugPrint(
        '[PlayerScreen] _loadLyrics result: ${result?.lines.length ?? 0} lines, synced=${result?.synced}',
      );
      final lines = result?.lines ?? [];
      if (!_lyricsCache.containsKey(cacheKey) &&
          _lyricsCache.length >= _lyricsCacheLimit) {
        _lyricsCache.remove(_lyricsCache.keys.first);
      }
      _lyricsCache[cacheKey] = lines;
      setState(() {
        _lyrics = lines;
        _lyricsForSongId = cacheKey;
      });
    } catch (e) {
      debugPrint('[PlayerScreen] lyrics load failed: ${e.runtimeType}');
      if (!_lyricsRequests.isCurrent(request) || !mounted) return;
      if (_lyricsKey(song) != cacheKey) return;
      final currentSong = ref.read(audioPlayerServiceProvider).currentSong;
      if (currentSong?.storageKey != song.storageKey) return;
      setState(() {
        _lyrics = [];
        _lyricsForSongId = cacheKey;
      });
    }
  }

  void _showMobileQueue(
    BuildContext context,
    AudioPlayerService playerService,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
                              SaveQueuePlaylistButton(
                                queue: playerService.queue,
                              ),
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
                                    if (mounted) setState(() {});
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
                                      trailing: _QueueSongMenuButton(
                                        song: song,
                                        onPlay: () {
                                          playerService.skipToIndex(index);
                                          Navigator.pop(ctx);
                                        },
                                        onDeleted: () {
                                          if (mounted) setState(() {});
                                        },
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

  Widget _buildLyricsPanel(
    Song currentSong,
    AudioPlayerService playerService, {
    Color? activeFg,
    Color? inactiveFg,
  }) {
    final lyrics = _lyrics;
    if (lyrics == null || _lyricsForSongId != _lyricsKey(currentSong)) {
      // 歌词尚未加载：不在 build 中直接调用 _loadLyrics（会触发 setState during build）。
      // 加载由 initState 中的 stream 监听 / onPageChanged / lyrics 按钮回调统一触发。
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
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
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
          // Auto-scroll to active line (skip when user is scrolling)
          if (!_userScrolling) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_lyricsScrollController.hasClients) {
                final target =
                    (activeIndex * AppDimensions.lyricsLineHeight) -
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
          }

          // Calculate the lyric line at the center of the viewport for seek indicator
          int seekLineIndex = _seekLineIndex.clamp(0, lyrics.length - 1);
          final seekMs = lyrics[seekLineIndex].startMs;
          final seekTimeStr = seekMs != null
              ? formatDuration(seekMs ~/ 1000)
              : '--:--';

          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is UserScrollNotification) {
                        if (!_userScrolling &&
                            _lyricsScrollController.hasClients) {
                          // First scroll event: immediately calculate seek line
                          final offset = _lyricsScrollController.offset;
                          final viewportH = _lyricsScrollController
                              .position
                              .viewportDimension;
                          final centerOffset = offset + viewportH / 2 - 24;
                          final idx =
                              (centerOffset / AppDimensions.lyricsLineHeight)
                                  .round()
                                  .clamp(0, lyrics.length - 1);
                          _seekLineIndex = idx;
                        }
                        setState(() => _userScrolling = true);
                        _userScrollTimer?.cancel();
                        _userScrollTimer = Timer(
                          const Duration(seconds: 3),
                          () {
                            if (mounted) {
                              setState(() => _userScrolling = false);
                            }
                          },
                        );
                      }
                      if (notification is ScrollUpdateNotification &&
                          _userScrolling &&
                          _lyricsScrollController.hasClients) {
                        final offset = _lyricsScrollController.offset;
                        final viewportH =
                            _lyricsScrollController.position.viewportDimension;
                        final centerOffset =
                            offset + viewportH / 2 - 24; // subtract top padding
                        final idx =
                            (centerOffset / AppDimensions.lyricsLineHeight)
                                .round()
                                .clamp(0, lyrics.length - 1);
                        if (idx != _seekLineIndex) {
                          setState(() => _seekLineIndex = idx);
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _lyricsScrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 20,
                      ),
                      itemCount: lyrics.length,
                      itemBuilder: (context, index) {
                        final isActive = index == activeIndex;
                        return Container(
                          height: AppDimensions.lyricsLineHeight,
                          alignment: Alignment.center,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: isActive ? 22 : 15,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              letterSpacing: isActive ? -0.3 : 0.0,
                              color: isActive
                                  ? (activeFg ?? context.colors.primary)
                                  : (inactiveFg ??
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant)
                                        .withValues(alpha: 0.40),
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        color:
                                            (activeFg ?? context.colors.primary)
                                                .withValues(alpha: 0.35),
                                        blurRadius: 16,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              lyrics[index].text,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Seek timeline indicator (shown during user scroll)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: constraints.maxHeight / 2 - 16,
                    child: IgnorePointer(
                      ignoring: !_userScrolling,
                      child: AnimatedOpacity(
                        opacity: _userScrolling ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                seekTimeStr,
                                style: Theme.of(context).textTheme.chipLabel
                                    .copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: activeFg ?? context.colors.primary,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: (activeFg ?? context.colors.primary)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 20,
                                  tooltip: S.of(context).tooltipPlay,
                                  icon: Icon(
                                    Icons.play_arrow_rounded,
                                    color: activeFg ?? context.colors.primary,
                                  ),
                                  onPressed: () {
                                    if (seekMs != null) {
                                      playerService.seekTo(
                                        Duration(milliseconds: seekMs),
                                      );
                                    }
                                    _userScrollTimer?.cancel();
                                    setState(() => _userScrolling = false);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    // Unsynced lyrics — simple scrollable list
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      itemCount: lyrics.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            lyrics[index].text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.songSubtitle.copyWith(
              fontSize: 15,
              color:
                  inactiveFg ?? Theme.of(context).colorScheme.onSurfaceVariant,
              shadows: [
                Shadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.8),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closePlayer() {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _toggleLyrics(Song currentSong) {
    setState(() => _showLyrics = !_showLyrics);
    _lastShowLyrics = _showLyrics;
    if (_showLyrics) _loadLyrics(currentSong);
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final resolver = ref.watch(songMediaResolverProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _closePlayer,
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<Song?>(
          stream: playerService.currentSongStream,
          builder: (context, snapshot) {
            final currentSong = snapshot.data ?? playerService.currentSong;

            if (currentSong == null) {
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_off_rounded,
                        size: 80,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        S.of(context).playerNoContent,
                        style: Theme.of(context).textTheme.playerSongName
                            .copyWith(
                              fontWeight: FontWeight.normal,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        S.of(context).playerNoContentHint,
                        style: Theme.of(context).textTheme.playerSubtitle
                            .copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                    ? context.colors.primary
                    : (ref.watch(coverColorProvider(coverUrl)).value ??
                          context.colors.primary);
                final isMobile = AppBreakpoints.isMobile(
                  MediaQuery.of(context).size.width,
                );
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final surfaceColor = Theme.of(context).colorScheme.surface;

                // High-contrast atmospheric gradient
                final gradientTop = isDark
                    ? Color.lerp(const Color(0xFF131316), accentColor, 0.35)!
                    : Color.lerp(const Color(0xFFEFF0F4), accentColor, 0.16)!;
                final gradientBottom = isDark
                    ? const Color(0xFF0C0C0E)
                    : const Color(0xFFFAFAFC);

                return Scaffold(
                  backgroundColor: surfaceColor,
                  body: isMobile
                      // ── 移动端：全屏沉浸式高对比度渐变 ──
                      ? AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [gradientTop, gradientBottom],
                              stops: const [0.0, 0.80],
                            ),
                          ),
                          child: _buildDismissibleMobilePlayer(
                            context,
                            currentSong,
                            playerService,
                            coverUrl,
                            accentColor,
                          ),
                        )
                      // ── 桌面端：模糊封面背景 + 渐变叠加 ──
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            // 层 1：模糊封面图
                            if (coverUrl.isNotEmpty)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 800),
                                child: SizedBox.expand(
                                  key: ValueKey(coverUrl),
                                  child: ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: 80,
                                      sigmaY: 80,
                                    ),
                                    child: Opacity(
                                      opacity: 0.18,
                                      child: Image.network(
                                        coverUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // 层 2：半透明渐变叠加层（保证文字可读性）
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color.lerp(
                                      surfaceColor,
                                      accentColor,
                                      0.40,
                                    )!.withValues(alpha: 0.85),
                                    surfaceColor.withValues(alpha: 0.92),
                                  ],
                                ),
                              ),
                            ),
                            // 层 3：播放器内容
                            _buildDesktopPlayer(
                              currentSong,
                              playerService,
                              coverUrl,
                              accentColor,
                            ),
                          ],
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Wraps mobile player with drag-down-to-dismiss gesture (GPU-composited)
  Widget _buildDismissibleMobilePlayer(
    BuildContext context,
    Song currentSong,
    AudioPlayerService playerService,
    String coverUrl,
    Color accentColor,
  ) {
    return _DragDismissWrapper(
      onDismiss: _closePlayer,
      child: _buildMobilePlayer(
        context,
        currentSong,
        playerService,
        coverUrl,
        accentColor,
      ),
    );
  }

  /// 移动端播放器 — 单栏垂直布局，全屏
  Widget _buildMobilePlayer(
    BuildContext context,
    Song currentSong,
    AudioPlayerService playerService,
    String coverUrl,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 严谨计算高对比度前景色，杜绝浅色模式下白字白底的问题
    final playerFg = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111827); // 深炭黑
    final playerFgMuted = isDark
        ? const Color(0xB3FFFFFF) // 70% 白色
        : const Color(0xFF4B5563); // 深石板灰
    final themePrimary = context.colors.primary;
    final effectiveAccent = isDark ? accentColor : themePrimary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            // 1. 顶部导航栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _closePlayer,
                  tooltip: S.of(context).commonBack,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 28,
                    color: playerFg,
                  ),
                ),
                Text(
                  S.of(context).playerNowPlaying,
                  style: Theme.of(context).textTheme.chipLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: playerFgMuted,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _toggleLyrics(currentSong),
                      tooltip: S.of(context).playerLyrics,
                      icon: Icon(
                        Icons.lyrics_rounded,
                        size: 22,
                        color: _showLyrics ? effectiveAccent : playerFgMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (currentSong.isOnline)
                      ImportToNavidromeButton(
                        song: currentSong,
                        iconColor: playerFgMuted,
                      ),
                    IconButton(
                      onPressed: () => _showMobileQueue(context, playerService),
                      tooltip: S.of(context).playerQueue,
                      icon: Icon(
                        Icons.queue_music_rounded,
                        size: 24,
                        color: playerFgMuted,
                      ),
                    ),
                    _PlayerOverflowMenu(
                      song: currentSong,
                      iconColor: playerFgMuted,
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(flex: 1),
            // 2. 大封面 / 歌词 — 点击切换，播放状态弹性缩放
            Flexible(
              flex: 6,
              child: GestureDetector(
                onTap: () => _toggleLyrics(currentSong),
                behavior: HitTestBehavior.opaque,
                child: _showLyrics
                    ? _buildLyricsPanel(
                        currentSong,
                        playerService,
                        activeFg: isDark
                            ? const Color(0xFFFFFFFF)
                            : effectiveAccent,
                        inactiveFg: playerFgMuted,
                      )
                    : AspectRatio(
                        aspectRatio: 1,
                        child: StreamBuilder<bool>(
                          stream: playerService.playingStream,
                          builder: (context, snapshot) {
                            final playing =
                                snapshot.data ?? playerService.player.playing;
                            return AnimatedScale(
                              scale: playing ? 1.0 : 0.93,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              child: Hero(
                                tag: 'player-cover',
                                child: CoverArt(
                                  url: coverUrl,
                                  borderRadius: 20,
                                  hasShadow: true,
                                  shadowColor: effectiveAccent,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            // 3. 歌曲信息
            Text(
              currentSong.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.playerMediumTitle.copyWith(
                color: playerFg,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${currentSong.artist} · ${currentSong.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.playerSubtitle.copyWith(
                color: playerFgMuted,
                fontSize: 14,
              ),
            ),
            if (currentSong.suffix != null ||
                currentSong.bitRate != null ||
                currentSong.isOnline) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  if (currentSong.isOnline && currentSong.sourceLabel != null)
                    AudioFormatBadge(
                      label: currentSong.sourceLabel!,
                      primary: true,
                    ),
                  if (currentSong.suffix != null)
                    AudioFormatBadge(label: currentSong.suffix!.toUpperCase()),
                  if (currentSong.bitRate != null)
                    AudioFormatBadge(label: '${currentSong.bitRate} kbps'),
                ],
              ),
            ],
            const SizedBox(height: 18),
            // 4. 进度条 (时间位于进度条正下方两侧)
            _ProgressBar(
              playerService: playerService,
              activeColor: effectiveAccent,
              textColor: playerFgMuted,
            ),
            const SizedBox(height: 10),
            // 5. 核心播放控制区 (Shuffle / Prev / PlayPause / Next / Repeat)
            _PlaybackControls(
              playerService: playerService,
              accentColor: effectiveAccent,
              iconColor: playerFg,
            ),
            const SizedBox(height: 14),
            // 6. 底部细致音量条与倍速 (带左右喇叭图标)
            _BottomVolumeAndUtilityRow(
              playerService: playerService,
              foreground: playerFgMuted,
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  /// PC 全屏播放页覆盖 shell，因此必须自带进度与控制，不能依赖 MiniPlayer。
  Widget _buildDesktopPlayer(
    Song currentSong,
    AudioPlayerService playerService,
    String coverUrl,
    Color accentColor,
  ) {
    final wide = MediaQuery.of(context).size.width >= AppBreakpoints.medium;
    final showLyricsPane = _showLyrics || wide;
    if (showLyricsPane &&
        (_lyrics == null || _lyricsForSongId != _lyricsKey(currentSong))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLyrics(currentSong);
      });
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _closePlayer,
                      tooltip: S.of(context).playerClose,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentSong.isOnline)
                          ImportToNavidromeButton(song: currentSong),
                        if (!currentSong.isOnline && !currentSong.isRadio) ...[
                          IconButton(
                            key: const Key('player-add-to-playlist-button'),
                            onPressed: () => SongContextMenu.addToPlaylist(
                              context,
                              ref,
                              currentSong,
                            ),
                            tooltip: S.of(context).contextMenuAddPlaylist,
                            icon: const Icon(Icons.playlist_add_rounded),
                          ),
                          _PlayerOverflowMenu(song: currentSong),
                        ],
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .songTitle
                                          .copyWith(
                                            fontWeight: s == speed
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            color: s == speed
                                                ? context.colors.primary
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .playerTimestamp
                                      .copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (!wide)
                          IconButton(
                            icon: Icon(
                              Icons.lyrics_rounded,
                              size: 22,
                              color: _showLyrics
                                  ? context.colors.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () => _toggleLyrics(currentSong),
                            tooltip: S.of(context).playerLyrics,
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.queue_music_rounded,
                            size: 22,
                            color: _showQueue
                                ? context.colors.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() => _showQueue = !_showQueue);
                            _lastShowQueue = _showQueue;
                          },
                          tooltip: _showQueue
                              ? S.of(context).playerHideQueue
                              : S.of(context).playerShowQueue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildDesktopInfoPage(
                              coverUrl,
                              accentColor,
                              playerService,
                            ),
                          ),
                          Expanded(
                            child: _buildDesktopLyricsPage(
                              currentSong,
                              playerService,
                            ),
                          ),
                        ],
                      )
                    : (_showLyrics
                          ? _buildDesktopLyricsPage(currentSong, playerService)
                          : _buildDesktopInfoPage(
                              coverUrl,
                              accentColor,
                              playerService,
                            )),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Text(
                      currentSong.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.playerLargeSongName
                          .copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currentSong.artist} · ${currentSong.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.playerSubtitle
                          .copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (currentSong.suffix != null ||
                        currentSong.bitRate != null ||
                        currentSong.isOnline) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          if (currentSong.isOnline &&
                              currentSong.sourceLabel != null)
                            AudioFormatBadge(
                              label: currentSong.sourceLabel!,
                              primary: true,
                            ),
                          if (currentSong.suffix != null)
                            AudioFormatBadge(
                              label: currentSong.suffix!.toUpperCase(),
                            ),
                          if (currentSong.bitRate != null)
                            AudioFormatBadge(
                              label: '${currentSong.bitRate} kbps',
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: _ProgressBar(playerService: playerService),
                    ),
                    const SizedBox(height: 4),
                    _PlaybackControls(
                      playerService: playerService,
                      accentColor: accentColor,
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
  Widget _buildDesktopInfoPage(
    String coverUrl,
    Color accentColor,
    AudioPlayerService playerService,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 380),
          child: AspectRatio(
            aspectRatio: 1,
            child: StreamBuilder<bool>(
              stream: playerService.playingStream,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? playerService.player.playing;
                return AnimatedScale(
                  scale: playing ? 1.0 : 0.94,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: Hero(
                    tag: 'player-cover',
                    child: CoverArt(
                      url: coverUrl,
                      borderRadius: 24,
                      hasShadow: true,
                      shadowColor: accentColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// PC 歌词页 — 全屏歌词滚动高亮
  Widget _buildDesktopLyricsPage(
    Song currentSong,
    AudioPlayerService playerService,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: _buildLyricsPanel(currentSong, playerService),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 监听当前歌曲变化以刷新高亮
    return StreamBuilder<Song?>(
      stream: ps.currentSongStream,
      builder: (context, _) {
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: AppDimensions.queuePanelWidth,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh
                    .withValues(alpha: isDark ? 0.85 : 0.90),
                border: Border(
                  left: BorderSide(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: isDark ? 0.10 : 0.06,
                    ),
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
                                        _QueueSongMenuButton(
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

class _QueueSongMenuButton extends ConsumerWidget {
  final Song song;
  final VoidCallback onPlay;
  final VoidCallback? onDeleted;

  const _QueueSongMenuButton({
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

class _ProgressBar extends StatelessWidget {
  final AudioPlayerService playerService;
  final Color? activeColor;
  final Color? textColor;

  const _ProgressBar({
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
class _PlaybackControls extends StatefulWidget {
  final AudioPlayerService playerService;
  final Color? accentColor;
  final Color? iconColor;

  const _PlaybackControls({
    required this.playerService,
    this.accentColor,
    this.iconColor,
  });

  @override
  State<_PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<_PlaybackControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;
  StreamSubscription<bool>? _playingSub;
  bool _playing = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;

  @override
  void initState() {
    super.initState();
    _repeatMode = widget.playerService.repeatMode;
    _playPauseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
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
    // 播放按钮使用主强调色
    final btnColor = widget.accentColor ?? context.colors.primary;
    // 确保按钮上的图标可见：深色按钮用白色图标，浅色按钮用深色图标
    final btnFg = foregroundOn(btnColor);
    final controlColor =
        widget.iconColor ?? Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            size: 22,
            color: widget.playerService.shuffle ? btnColor : controlColor,
          ),
          tooltip: S.of(context).playerShuffle,
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
        IconButton(
          icon: Icon(
            _repeatMode == PlaybackRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            size: 22,
            color: _repeatMode != PlaybackRepeatMode.off
                ? btnColor
                : controlColor,
          ),
          tooltip: S.of(context).playerRepeat,
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.playerService.cycleRepeatMode();
            setState(() => _repeatMode = widget.playerService.repeatMode);
          },
        ),
      ],
    );
  }
}

/// GPU-composited drag-down dismiss wrapper with spring-back animation.
class _DragDismissWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const _DragDismissWrapper({required this.child, required this.onDismiss});

  @override
  State<_DragDismissWrapper> createState() => _DragDismissWrapperState();
}

class _DragDismissWrapperState extends State<_DragDismissWrapper>
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
      // Spring back with animation
      final startValue = _dragExtent;
      _controller.reset();
      _controller.forward();
      late final VoidCallback listener;
      listener = () {
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

class _PlayerOverflowMenu extends ConsumerWidget {
  const _PlayerOverflowMenu({required this.song, this.iconColor});

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

class _BottomVolumeAndUtilityRow extends StatelessWidget {
  const _BottomVolumeAndUtilityRow({
    required this.playerService,
    required this.foreground,
  });

  final AudioPlayerService playerService;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // 播放倍速微小胶囊
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
          // 小喇叭图标 (音量小)
          Icon(
            Icons.volume_down_rounded,
            size: 17,
            color: foreground.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          // 极简细音量滑块
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
          // 大喇叭图标 (音量大)
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
