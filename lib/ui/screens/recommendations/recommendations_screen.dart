import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/player/playback_origin.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
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

  Future<void> _import(RecommendationItem item) async {
    try {
      await ref.read(recommendationProvider.notifier).importItem(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).commonError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationProvider);
    final backendReady = ref.watch(backendClientProvider).isConfigured;
    final h = AppBreakpoints.isMobile(MediaQuery.of(context).size.width)
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    final l10n = S.of(context);
    final visible = state.visibleItems;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.recommendationsTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: () =>
                ref.read(recommendationProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !backendReady
          ? ErrorState(
              message: l10n.recommendationsBackendMissing,
              onRetry: () =>
                  ref.read(recommendationProvider.notifier).ensureLoaded(),
              retryLabel: l10n.recommendationsRetry,
            )
          : state.initialLoading && visible.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && visible.isEmpty
          ? ErrorState(
              message: l10n.commonError,
              onRetry: () =>
                  ref.read(recommendationProvider.notifier).ensureLoaded(),
              retryLabel: l10n.recommendationsRetry,
            )
          : visible.isEmpty
          ? EmptyState(
              icon: Icons.recommend_outlined,
              message: l10n.recommendationsEmpty,
            )
          : ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(h, 8, h, h),
              itemCount:
                  visible.length +
                  (state.loadingMore || state.loadMoreError != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= visible.length) {
                  if (state.loadMoreError != null) {
                    return TextButton(
                      onPressed: () =>
                          ref.read(recommendationProvider.notifier).loadMore(),
                      child: Text(l10n.recommendationsRetry),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final item = visible[index];
                final origin = _originFor(item, state.sessionId);
                return SongContextMenu(
                  song: item.song,
                  playbackOrigin: origin,
                  // Menu already performed import; only emit recommendation feedback.
                  onImported: () {
                    ref
                        .read(recommendationProvider.notifier)
                        .recordFeedback(
                          item,
                          RecommendationFeedbackEvent.imported,
                        );
                  },
                  onPlay: () => _playAll(visible, index),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: ResolvedSongCoverArt(
                      song: item.song,
                      size: 52,
                      borderRadius: 8,
                    ),
                    title: Text(
                      item.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _playAll(visible, index),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.importingCandidateIds.contains(
                          item.candidateId,
                        ))
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            tooltip: l10n.recommendationsImport,
                            icon: const Icon(Icons.library_add_outlined),
                            onPressed: () => _import(item),
                          ),
                        IconButton(
                          tooltip: l10n.recommendationsDislike,
                          icon: const Icon(Icons.thumb_down_alt_outlined),
                          onPressed: () => ref
                              .read(recommendationProvider.notifier)
                              .dislike(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
