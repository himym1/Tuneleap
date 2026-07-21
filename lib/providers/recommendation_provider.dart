import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/navidrome_import_provider.dart';
import 'package:navidrome_player/services/recommendation_playback_tracker.dart';

import 'audio_providers.dart';
import 'server_config_provider.dart';
import 'server_scope.dart';

class RecommendationState {
  RecommendationState({
    List<RecommendationItem> items = const [],
    this.sessionId,
    this.cursor,
    this.mode,
    this.initialLoading = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.resetting = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
    Set<String> hiddenCandidateIds = const {},
    Set<String> pendingCandidateIds = const {},
    Set<String> importingCandidateIds = const {},
    this.fallbackNoticeShown = false,
  }) : items = List.unmodifiable(items),
       hiddenCandidateIds = Set.unmodifiable(hiddenCandidateIds),
       pendingCandidateIds = Set.unmodifiable(pendingCandidateIds),
       importingCandidateIds = Set.unmodifiable(importingCandidateIds);

  final List<RecommendationItem> items;
  final String? sessionId;
  final String? cursor;
  final RecommendationMode? mode;
  final bool initialLoading;
  final bool loadingMore;
  final bool refreshing;
  final bool resetting;
  final bool hasMore;
  final Object? error;
  final Object? loadMoreError;
  final Set<String> hiddenCandidateIds;
  final Set<String> pendingCandidateIds;
  final Set<String> importingCandidateIds;
  final bool fallbackNoticeShown;

  List<RecommendationItem> get visibleItems => items
      .where((item) => !hiddenCandidateIds.contains(item.candidateId))
      .toList(growable: false);

  RecommendationState copyWith({
    List<RecommendationItem>? items,
    String? sessionId,
    bool clearSessionId = false,
    String? cursor,
    bool clearCursor = false,
    RecommendationMode? mode,
    bool clearMode = false,
    bool? initialLoading,
    bool? loadingMore,
    bool? refreshing,
    bool? resetting,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
    Set<String>? hiddenCandidateIds,
    Set<String>? pendingCandidateIds,
    Set<String>? importingCandidateIds,
    bool? fallbackNoticeShown,
  }) {
    return RecommendationState(
      items: List.unmodifiable(items ?? this.items),
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      mode: clearMode ? null : (mode ?? this.mode),
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      resetting: resetting ?? this.resetting,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
      hiddenCandidateIds: Set.unmodifiable(
        hiddenCandidateIds ?? this.hiddenCandidateIds,
      ),
      pendingCandidateIds: Set.unmodifiable(
        pendingCandidateIds ?? this.pendingCandidateIds,
      ),
      importingCandidateIds: Set.unmodifiable(
        importingCandidateIds ?? this.importingCandidateIds,
      ),
      fallbackNoticeShown: fallbackNoticeShown ?? this.fallbackNoticeShown,
    );
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationNotifier, RecommendationState>(
      RecommendationNotifier.new,
    );

final recommendationRecentSongsProvider = Provider<List<Song>>((ref) {
  return ref.watch(audioPlayerServiceProvider).playHistory;
});

class RecommendationNotifier extends Notifier<RecommendationState> {
  int _requestGeneration = 0;
  Future<void>? _loadMoreFuture;
  Future<void> _outboxChain = Future<void>.value();
  bool _recoveringSession = false;
  String? _scope;

  @override
  RecommendationState build() {
    final config = ref.watch(serverConfigProvider);
    ref.watch(recommendationRecentSongsProvider);
    ref.watch(navidromeImportServiceProvider);
    _scope = _scopeFor(
      config.serverId,
      config.backendUrl,
      config.backendApiKey,
    );
    ref.onDispose(() => _requestGeneration++);
    unawaited(_retryOutbox());
    return RecommendationState();
  }

  Future<T> _withOutboxLock<T>(Future<T> Function() action) {
    final previous = _outboxChain;
    final gate = Completer<void>();
    _outboxChain = gate.future;
    return previous.catchError((_) {}).then((_) => action()).whenComplete(() {
      if (!gate.isCompleted) gate.complete();
    });
  }

  String _scopeFor(String serverId, String url, String key) =>
      '${normalizeServerId(serverId)}|${_normalizeBackendUrl(url)}|${Object.hash(key, 0)}';

  String _normalizeBackendUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  bool _current(int generation, String scope) =>
      generation == _requestGeneration && scope == _scope;

  Future<void> ensureLoaded() async {
    if (state.items.isNotEmpty ||
        state.initialLoading ||
        state.refreshing ||
        state.resetting) {
      return;
    }
    await _load(refresh: false);
  }

  Future<void> refresh() => _load(refresh: true);

  Future<void> _load({required bool refresh}) async {
    final config = ref.read(serverConfigProvider);
    final client = ref.read(backendClientProvider);
    if (!client.isConfigured) {
      state = state.copyWith(error: StateError('Backend is not configured'));
      return;
    }
    final generation = ++_requestGeneration;
    final scope = _scopeFor(
      config.serverId,
      config.backendUrl,
      config.backendApiKey,
    );
    state = state.copyWith(
      initialLoading: !refresh && state.items.isEmpty,
      refreshing: refresh,
      clearError: true,
      clearLoadMoreError: true,
    );
    try {
      final page = await client.createRecommendationSession(
        _recentSongs(),
        refresh: refresh,
      );
      if (!_current(generation, scope)) return;
      _applyPage(page, replace: true);
      unawaited(_retryOutbox());
    } on RecommendationApiException catch (error) {
      if (!_current(generation, scope)) return;
      if (error.statusCode == 410) {
        await _recoverFromExpiredSession(
          generation: generation,
          scope: scope,
          preserveItems: false,
        );
        return;
      }
      state = state.copyWith(
        initialLoading: false,
        refreshing: false,
        error: error,
      );
    } catch (error) {
      if (_current(generation, scope)) {
        state = state.copyWith(
          initialLoading: false,
          refreshing: false,
          error: error,
        );
      }
    }
  }

  List<Song> _recentSongs() {
    final history = ref.read(recommendationRecentSongsProvider);
    if (history.length <= 30) return List<Song>.from(history);
    return history.sublist(0, 30);
  }

  Future<void> loadMore() {
    final running = _loadMoreFuture;
    if (running != null) return running;
    if (!state.hasMore ||
        state.sessionId == null ||
        state.cursor == null ||
        state.initialLoading ||
        state.refreshing) {
      return Future<void>.value();
    }
    late final Future<void> future;
    future = _loadMore().whenComplete(() {
      if (identical(_loadMoreFuture, future)) {
        _loadMoreFuture = null;
      }
    });
    _loadMoreFuture = future;
    return future;
  }

  Future<void> _loadMore() async {
    final config = ref.read(serverConfigProvider);
    final generation = _requestGeneration;
    final scope = _scopeFor(
      config.serverId,
      config.backendUrl,
      config.backendApiKey,
    );
    final session = state.sessionId;
    final cursor = state.cursor;
    if (session == null || cursor == null) return;
    state = state.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final page = await ref
          .read(backendClientProvider)
          .getRecommendationItems(session, cursor: cursor);
      if (!_current(generation, scope) || state.cursor != cursor) return;
      _applyPage(page, replace: false);
      unawaited(_retryOutbox());
    } on RecommendationApiException catch (error) {
      if (!_current(generation, scope)) return;
      if (error.statusCode == 410) {
        await _recoverFromExpiredSession(
          generation: generation,
          scope: scope,
          preserveItems: true,
        );
        return;
      }
      state = state.copyWith(loadingMore: false, loadMoreError: error);
    } catch (error) {
      if (_current(generation, scope)) {
        state = state.copyWith(loadingMore: false, loadMoreError: error);
      }
    } finally {
      if (_current(generation, scope) && state.loadingMore) {
        state = state.copyWith(loadingMore: false);
      }
    }
  }

  Future<void> _recoverFromExpiredSession({
    required int generation,
    required String scope,
    required bool preserveItems,
  }) async {
    if (!_current(generation, scope) || _recoveringSession) return;
    _recoveringSession = true;
    try {
      state = state.copyWith(
        clearSessionId: true,
        clearCursor: true,
        hasMore: true,
        loadingMore: false,
        initialLoading: !preserveItems,
        refreshing: false,
        clearLoadMoreError: true,
        items: preserveItems ? state.items : const [],
      );
      final client = ref.read(backendClientProvider);
      final page = await client.createRecommendationSession(
        _recentSongs(),
        refresh: false,
      );
      if (!_current(generation, scope)) return;
      _applyPage(page, replace: !preserveItems);
    } catch (error) {
      if (_current(generation, scope)) {
        state = state.copyWith(
          initialLoading: false,
          loadingMore: false,
          refreshing: false,
          error: error,
        );
      }
    } finally {
      _recoveringSession = false;
    }
  }

  void _applyPage(RecommendationPage page, {required bool replace}) {
    final existing = replace ? <RecommendationItem>[] : [...state.items];
    final keys = existing.map((item) => item.song.storageKey).toSet();
    for (final item in page.items) {
      if (state.hiddenCandidateIds.contains(item.candidateId)) continue;
      if (keys.add(item.song.storageKey)) {
        existing.add(item);
      }
    }
    state = state.copyWith(
      items: existing,
      sessionId: page.sessionId,
      cursor: page.nextCursor,
      clearCursor: page.nextCursor == null,
      mode: page.mode,
      initialLoading: false,
      loadingMore: false,
      refreshing: false,
      hasMore: page.hasMore,
      clearError: true,
      clearLoadMoreError: true,
      fallbackNoticeShown:
          state.fallbackNoticeShown || page.mode == RecommendationMode.fallback,
    );
  }

  Future<void> dislike(RecommendationItem item) async {
    state = state.copyWith(
      hiddenCandidateIds: {...state.hiddenCandidateIds, item.candidateId},
      pendingCandidateIds: {...state.pendingCandidateIds, item.candidateId},
    );
    await _send(item, RecommendationFeedbackEvent.disliked);
  }

  Future<void> importItem(RecommendationItem item) async {
    final config = ref.read(serverConfigProvider);
    final scope = _scopeFor(
      config.serverId,
      config.backendUrl,
      config.backendApiKey,
    );
    state = state.copyWith(
      importingCandidateIds: {...state.importingCandidateIds, item.candidateId},
    );
    try {
      await ref
          .read(navidromeImportServiceProvider)
          .importOnlineSong(item.song);
      if (!ref.mounted || _scope != scope) return;
      await _send(item, RecommendationFeedbackEvent.imported);
    } catch (error) {
      rethrow;
    } finally {
      if (ref.mounted && _scope == scope) {
        state = state.copyWith(
          importingCandidateIds: {...state.importingCandidateIds}
            ..remove(item.candidateId),
        );
      }
    }
  }

  Future<void> recordFeedback(
    RecommendationItem item,
    RecommendationFeedbackEvent event,
  ) => _send(item, event);

  Future<void> _send(
    RecommendationItem item,
    RecommendationFeedbackEvent event,
  ) {
    final session = state.sessionId;
    if (session == null) return Future<void>.value();
    final config = ref.read(serverConfigProvider);
    final backendUrl = config.backendUrl;
    final scope = _scopeFor(
      config.serverId,
      config.backendUrl,
      config.backendApiKey,
    );
    return _withOutboxLock(() async {
      if (!ref.mounted || _scope != scope) return;
      // Capture-time session/backendUrl/scope only.
      final records = await _readOutbox(backendUrl);
      if (!ref.mounted || _scope != scope) return;
      final existingIndex = records.indexWhere(
        (record) =>
            record['sessionId'] == session &&
            record['candidateId'] == item.candidateId &&
            record['event'] == event.name,
      );
      final Map<String, dynamic> record;
      if (existingIndex >= 0) {
        record = records[existingIndex];
      } else {
        record = <String, dynamic>{
          'idempotencyKey': _uuidV4(),
          'sessionId': session,
          'candidateId': item.candidateId,
          'event': event.name,
        };
        records.add(record);
        await _writeOutbox(backendUrl, records);
      }
      await _deliverOutboxRecord(
        record,
        item.candidateId,
        backendUrl: backendUrl,
        scope: scope,
      );
    });
  }

  bool _isRetryableFeedbackError(Object error) {
    if (error is RecommendationApiException) return error.retryable;
    if (error is DioException) {
      if (error.type == DioExceptionType.cancel) return false;
      final status = error.response?.statusCode;
      if (status == null) return true;
      return status >= 500 || status == 429;
    }
    return false;
  }

  Future<void> _deliverOutboxRecord(
    Map<String, dynamic> record,
    String candidateId, {
    required String backendUrl,
    required String scope,
  }) async {
    if (!ref.mounted || _scope != scope) return;
    try {
      await ref
          .read(backendClientProvider)
          .sendRecommendationFeedback(
            idempotencyKey: record['idempotencyKey'] as String,
            sessionId: record['sessionId'] as String,
            candidateId: record['candidateId'] as String,
            event: RecommendationFeedbackEvent.values.byName(
              record['event'] as String,
            ),
          );
      if (!ref.mounted || _scope != scope) return;
      final records = await _readOutbox(backendUrl);
      if (!ref.mounted || _scope != scope) return;
      records.removeWhere(
        (value) => value['idempotencyKey'] == record['idempotencyKey'],
      );
      await _writeOutbox(backendUrl, records);
      if (!ref.mounted || _scope != scope) return;
      state = state.copyWith(
        pendingCandidateIds: {...state.pendingCandidateIds}
          ..remove(candidateId),
      );
    } catch (error) {
      if (!ref.mounted || _scope != scope) return;
      if (_isRetryableFeedbackError(error)) return;
      final records = await _readOutbox(backendUrl);
      if (!ref.mounted || _scope != scope) return;
      records.removeWhere(
        (value) => value['idempotencyKey'] == record['idempotencyKey'],
      );
      await _writeOutbox(backendUrl, records);
      if (!ref.mounted || _scope != scope) return;
      final restoreHidden =
          record['event'] == RecommendationFeedbackEvent.disliked.name;
      state = state.copyWith(
        hiddenCandidateIds: restoreHidden
            ? ({...state.hiddenCandidateIds}..remove(candidateId))
            : state.hiddenCandidateIds,
        pendingCandidateIds: {...state.pendingCandidateIds}
          ..remove(candidateId),
        error: error,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _readOutbox(String url) async {
    if (!ref.mounted) return [];
    final raw = ref.read(sharedPreferencesProvider).getString(_outboxKey(url));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeOutbox(
    String url,
    List<Map<String, dynamic>> records,
  ) async {
    if (!ref.mounted) return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (records.isEmpty) {
      await prefs.remove(_outboxKey(url));
    } else {
      await prefs.setString(_outboxKey(url), jsonEncode(records));
    }
  }

  Future<void> _retryOutbox() {
    return _withOutboxLock(() async {
      if (!ref.mounted) return;
      final config = ref.read(serverConfigProvider);
      if (!ref.read(backendClientProvider).isConfigured) return;
      final backendUrl = config.backendUrl;
      final scope = _scopeFor(
        config.serverId,
        config.backendUrl,
        config.backendApiKey,
      );
      final records = await _readOutbox(backendUrl);
      if (!ref.mounted || _scope != scope) return;
      for (final record in List<Map<String, dynamic>>.from(records)) {
        final candidateId = record['candidateId'];
        if (candidateId is! String || candidateId.isEmpty) continue;
        await _deliverOutboxRecord(
          record,
          candidateId,
          backendUrl: backendUrl,
          scope: scope,
        );
        if (!ref.mounted || _scope != scope) return;
      }
    });
  }

  Future<void> reset() async {
    state = state.copyWith(resetting: true, clearError: true);
    final config = ref.read(serverConfigProvider);
    final scope = _scopeFor(
      config.serverId,
      config.backendUrl,
      config.backendApiKey,
    );
    try {
      await ref.read(backendClientProvider).resetRecommendationProfile();
      if (!ref.mounted || _scope != scope) return;
      await _withOutboxLock(() async {
        if (!ref.mounted || _scope != scope) return;
        await ref
            .read(sharedPreferencesProvider)
            .remove(_outboxKey(config.backendUrl));
      });
      if (!ref.mounted || _scope != scope) return;
      _requestGeneration++;
      state = RecommendationState();
    } catch (error) {
      if (!ref.mounted || _scope != scope) return;
      state = state.copyWith(resetting: false, error: error);
    }
  }

  String _outboxKey(String url) =>
      'recommendation_outbox::${_normalizeBackendUrl(url)}';

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

final recommendationPlaybackTrackerProvider =
    Provider<RecommendationPlaybackTracker>((ref) {
      final player = ref.watch(audioPlayerServiceProvider);
      final tracker = RecommendationPlaybackTracker(
        player: player,
        onFeedback: (origin, event) async {
          final notifier = ref.read(recommendationProvider.notifier);
          final state = ref.read(recommendationProvider);
          RecommendationItem? item;
          for (final candidate in state.items) {
            if (candidate.candidateId == origin.candidateId) {
              item = candidate;
              break;
            }
          }
          if (item == null) return;
          await notifier.recordFeedback(item, event);
        },
      );
      ref.onDispose(tracker.dispose);
      return tracker;
    });
