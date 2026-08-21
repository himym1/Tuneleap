import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/player/playback_origin.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/import_to_navidrome_button.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/ui/widgets/segmented_control.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  final _scroll = ScrollController();
  final _impressionIds = <String, String>{};
  final _importingIds = <String>{};
  int _filterIndex = 0; // 0: all, 1: similar, 2: explore

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recommendationProvider.notifier).ensureLoaded();
      ref.read(recommendationPlaybackTrackerProvider);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) {
      ref.read(recommendationProvider.notifier).loadMore();
    }
  }

  String _impressionIdFor(String candidateId) {
    return _impressionIds.putIfAbsent(candidateId, () {
      final bytes = List<int>.generate(8, (_) => Random.secure().nextInt(256));
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    });
  }

  PlaybackOrigin? _originFor(RecommendationItem item, String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) return null;
    return PlaybackOrigin(
      sessionId: sessionId,
      candidateId: item.candidateId,
      impressionId: _impressionIdFor(item.candidateId),
    );
  }

  Future<void> _playAll(List<RecommendationItem> items, int index) async {
    final state = ref.read(recommendationProvider);
    final sessionId = state.sessionId;
    if (sessionId == null || items.isEmpty) return;
    final songs = items.map((e) => e.song).toList();
    final origins = [for (final item in items) _originFor(item, sessionId)];
    await ref
        .read(audioPlayerServiceProvider)
        .playAll(songs, startIndex: index, origins: origins);
    if (mounted) context.push('/player');
  }

  void _goBack() {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _import(RecommendationItem item) async {
    setState(() => _importingIds.add(item.candidateId));
    try {
      await importOnlineSongToNavidrome(
        context,
        ref,
        item.song,
        onImported: () {
          ref
              .read(recommendationProvider.notifier)
              .recordFeedback(item, RecommendationFeedbackEvent.imported);
        },
      );
    } finally {
      if (mounted) {
        setState(() => _importingIds.remove(item.candidateId));
      }
    }
  }

  Future<void> _refresh() async {
    if (ref.read(recommendationProvider).refreshing) return;
    await ref.read(recommendationProvider.notifier).refresh();
    if (!mounted) return;
    final refreshed = ref.read(recommendationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          refreshed.error == null
              ? S.of(context).recommendationsRefreshed
              : S.of(context).commonError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);
    final backendReady = ref.watch(backendClientProvider).isConfigured;
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    final l10n = S.of(context);
    final visible = state.visibleItems;
    final similarCount = visible
        .where((item) => item.type == RecommendationType.similar)
        .length;
    final exploreCount = visible.length - similarCount;
    final modeLabel = state.mode == RecommendationMode.ai
        ? l10n.recommendationsModeAi
        : l10n.recommendationsModeFallback;

    final filtered = _filterIndex == 1
        ? visible
              .where((item) => item.type == RecommendationType.similar)
              .toList()
        : _filterIndex == 2
        ? visible
              .where((item) => item.type == RecommendationType.explore)
              .toList()
        : visible;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    if (!backendReady) {
      return ResponsivePageScaffold(
        body: ErrorState(
          message: l10n.recommendationsBackendMissing,
          onRetry: () =>
              ref.read(recommendationProvider.notifier).ensureLoaded(),
          retryLabel: l10n.recommendationsRetry,
        ),
      );
    }

    if (state.initialLoading && visible.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && visible.isEmpty) {
      return ResponsivePageScaffold(
        body: ErrorState(
          message: l10n.commonError,
          onRetry: () =>
              ref.read(recommendationProvider.notifier).ensureLoaded(),
          retryLabel: l10n.recommendationsRetry,
        ),
      );
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: isMobile ? 188 : 196,
              elevation: 0,
              backgroundColor: surfaceColor,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                tooltip: l10n.tooltipBack,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              title: Text(
                l10n.recommendationsTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
              ),
              actions: [
                if (state.refreshing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: '换一批',
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _refresh();
                    },
                  ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 52, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.colors.primary.withValues(
                              alpha: isDark ? 0.22 : 0.14,
                            ),
                            context.colors.secondary.withValues(
                              alpha: isDark ? 0.14 : 0.08,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.cardRadius,
                        ),
                        border: Border.all(
                          color: context.colors.primary.withValues(
                            alpha: isDark ? 0.28 : 0.18,
                          ),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.primary.withValues(
                              alpha: isDark ? 0.15 : 0.06,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: context.colors.primary.withValues(
                                    alpha: 0.20,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: context.colors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      modeLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                          ),
                                    ),
                                    Text(
                                      l10n.recommendationsSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 11.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: visible.isEmpty
                                    ? null
                                    : () => _playAll(visible, 0),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  '${l10n.playlistPlay} (${visible.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 0,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: state.refreshing
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        _refresh();
                                      },
                                icon: state.refreshing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                      ),
                                label: const Text(
                                  '换一批',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySegmentedHeaderDelegate(
                backgroundColor: surfaceColor,
                child: AppSegmentedControl<int>(
                  items: [
                    AppSegmentItem(
                      value: 0,
                      label: l10n.recommendationsViewAll,
                      badge: '${visible.length}',
                    ),
                    AppSegmentItem(
                      value: 1,
                      label: l10n.recommendationsSimilar,
                      badge: '$similarCount',
                    ),
                    AppSegmentItem(
                      value: 2,
                      label: l10n.recommendationsExplore,
                      badge: '$exploreCount',
                    ),
                  ],
                  selected: _filterIndex,
                  onSelected: (i) => setState(() => _filterIndex = i),
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.recommend_outlined,
                  message: l10n.recommendationsEmpty,
                  actionLabel: '换一批',
                  onAction: _refresh,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, h + 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= filtered.length) {
                        if (state.loadMoreError != null) {
                          return TextButton(
                            onPressed: () => ref
                                .read(recommendationProvider.notifier)
                                .loadMore(),
                            child: Text(l10n.recommendationsRetry),
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final item = filtered[index];
                      final origin = _originFor(item, state.sessionId);
                      final isSimilar =
                          item.type == RecommendationType.similar;
                      final subtitleText = _filterIndex == 0
                          ? '${isSimilar ? l10n.recommendationsSimilar : l10n.recommendationsExplore} · ${item.song.artist}'
                          : item.song.artist;

                      return SongContextMenu(
                        song: item.song,
                        playbackOrigin: origin,
                        onImported: () {
                          ref
                              .read(recommendationProvider.notifier)
                              .recordFeedback(
                                item,
                                RecommendationFeedbackEvent.imported,
                              );
                        },
                        onPlay: () => _playAll(filtered, index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            leading: ResolvedSongCoverArt(
                              song: item.song,
                              size: 50,
                              borderRadius: 10,
                              hasShadow: true,
                            ),
                            title: Text(
                              item.song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12.5,
                                  ),
                            ),
                            onTap: () => _playAll(filtered, index),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (state.importingCandidateIds.contains(
                                      item.candidateId,
                                    ) ||
                                    _importingIds.contains(item.candidateId))
                                  const SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  IconButton(
                                    tooltip: l10n.recommendationsImport,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    icon: Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 22,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _import(item);
                                    },
                                  ),
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: l10n.recommendationsDislike,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  icon: Icon(
                                    Icons.thumb_down_outlined,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.35),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(recommendationProvider.notifier)
                                        .dislike(item);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filtered.length +
                        (state.loadingMore || state.loadMoreError != null
                            ? 1
                            : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StickySegmentedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color backgroundColor;

  _StickySegmentedHeaderDelegate({
    required this.child,
    required this.backgroundColor,
  });

  @override
  double get minExtent => 52.0;

  @override
  double get maxExtent => 52.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickySegmentedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
