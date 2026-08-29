import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/utils/library_style.dart';

import 'audio_providers.dart';
import 'library_cache_provider.dart';
import 'server_config_provider.dart';

enum LibraryStyleStage { idle, analyzing, preview, applying, done }

enum LibraryStyleListFilter { suggested, review }

class LibraryStyleItem {
  LibraryStyleItem({
    required this.song,
    required this.suggestion,
    this.style,
    this.selected = true,
  });

  final Song song;
  final LibraryStyleSuggestion suggestion;
  String? style;
  bool selected;

  bool get isReview => style == null || !libraryStyleSet.contains(style);

  LibraryStyleItem copyWith({
    String? style,
    bool? selected,
    bool clearStyle = false,
  }) {
    return LibraryStyleItem(
      song: song,
      suggestion: suggestion,
      style: clearStyle ? null : (style ?? this.style),
      selected: selected ?? this.selected,
    );
  }
}

class LibraryStyleState {
  const LibraryStyleState({
    this.stage = LibraryStyleStage.idle,
    this.missingOnly = true,
    this.items = const [],
    this.filter = LibraryStyleListFilter.suggested,
    this.applied = 0,
    this.failedIds = const {},
    this.progress = 0,
    this.total = 0,
    this.error,
  });

  final LibraryStyleStage stage;
  final bool missingOnly;
  final List<LibraryStyleItem> items;
  final LibraryStyleListFilter filter;
  final int applied;
  final Set<String> failedIds;
  final int progress;
  final int total;
  final String? error;

  List<LibraryStyleItem> get suggestedItems => [
    for (final item in items)
      if (!item.isReview) item,
  ];

  List<LibraryStyleItem> get reviewItems => [
    for (final item in items)
      if (item.isReview) item,
  ];

  List<LibraryStyleItem> get visibleItems =>
      filter == LibraryStyleListFilter.review ? reviewItems : suggestedItems;

  int get selectedWriteCount => suggestedItems.where((item) {
    return item.selected && item.style != null;
  }).length;

  LibraryStyleState copyWith({
    LibraryStyleStage? stage,
    bool? missingOnly,
    List<LibraryStyleItem>? items,
    LibraryStyleListFilter? filter,
    int? applied,
    Set<String>? failedIds,
    int? progress,
    int? total,
    String? error,
    bool clearError = false,
  }) {
    return LibraryStyleState(
      stage: stage ?? this.stage,
      missingOnly: missingOnly ?? this.missingOnly,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      applied: applied ?? this.applied,
      failedIds: failedIds ?? this.failedIds,
      progress: progress ?? this.progress,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final libraryStyleProvider =
    NotifierProvider<LibraryStyleNotifier, LibraryStyleState>(
      LibraryStyleNotifier.new,
    );

class LibraryStyleNotifier extends Notifier<LibraryStyleState> {
  static const _applyWorkers = 3;
  static const _lookupBatch = 20;

  @override
  LibraryStyleState build() {
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    return const LibraryStyleState();
  }

  void reset() {
    state = LibraryStyleState(missingOnly: state.missingOnly);
  }

  void setFilter(LibraryStyleListFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setStyle(String songId, String? style) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.song.id == songId)
            item.copyWith(
              style: style,
              selected: style != null,
              clearStyle: style == null,
            )
          else
            item,
      ],
    );
  }

  void toggleSelected(String songId) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.song.id == songId)
            item.copyWith(selected: !item.selected)
          else
            item,
      ],
    );
  }

  Future<void> analyze({required bool missingOnly}) async {
    final backend = ref.read(backendClientProvider);
    if (!backend.canAuditLibrary) {
      state = state.copyWith(
        stage: LibraryStyleStage.idle,
        missingOnly: missingOnly,
        error: 'nas-required',
      );
      return;
    }
    state = state.copyWith(
      stage: LibraryStyleStage.analyzing,
      missingOnly: missingOnly,
      items: const [],
      applied: 0,
      failedIds: const {},
      progress: 0,
      total: 0,
      clearError: true,
    );
    try {
      final songs = await ref.read(subsonicClientProvider).getLibrarySongs();
      final items = <LibraryStyleItem>[];
      final seen = <String>{};
      for (final song in songs) {
        if (!seen.add(song.id)) continue;
        final suggestion = suggestLibraryStyle(
          title: song.title,
          artist: song.artist,
          album: song.album,
          year: song.year,
          currentGenre: song.genre,
          missingOnly: missingOnly,
        );
        if (suggestion.decision == LibraryStyleDecision.skip) continue;
        final style = suggestion.shouldWrite ? suggestion.style : null;
        items.add(
          LibraryStyleItem(
            song: song,
            suggestion: suggestion,
            style: style,
            selected: style != null,
          ),
        );
      }
      if (backend.isConfigured) {
        // Analyze-all must re-query even when genre is already a closed style
        // (e.g. coarse 华语流行), otherwise only untagged/review tracks hit Cloud.
        await _fillFromCloud(items, forceLookup: !missingOnly);
      }
      state = state.copyWith(
        stage: LibraryStyleStage.preview,
        items: items,
        filter: items.any((item) => !item.isReview)
            ? LibraryStyleListFilter.suggested
            : LibraryStyleListFilter.review,
      );
    } catch (error) {
      state = state.copyWith(
        stage: LibraryStyleStage.idle,
        error: error.toString(),
      );
    }
  }

  Future<void> _fillFromCloud(
    List<LibraryStyleItem> items, {
    bool forceLookup = false,
  }) async {
    final backend = ref.read(backendClientProvider);
    final pending = [
      for (final item in items)
        if (forceLookup || needsStyleLookup(item.suggestion)) item,
    ];
    if (pending.isEmpty) return;
    state = state.copyWith(progress: 0, total: pending.length);
    for (var offset = 0; offset < pending.length; offset += _lookupBatch) {
      final end = offset + _lookupBatch > pending.length
          ? pending.length
          : offset + _lookupBatch;
      final batch = pending.sublist(offset, end);
      try {
        final hits = await backend.lookupStyles([
          for (final item in batch)
            (
              title: item.song.title,
              artist: item.song.artist,
              album: item.song.album,
              year: item.song.year,
            ),
        ]);
        for (var i = 0; i < batch.length; i++) {
          final hit = i < hits.length ? hits[i] : null;
          final song = batch[i].song;
          final merged = mergeLookupStyle(
            local: batch[i].suggestion,
            remoteStyle: hit?.style,
            provider: hit?.provider,
            title: song.title,
            artist: song.artist,
            album: song.album,
            year: song.year,
          );
          if (!merged.shouldWrite) continue;
          final index = items.indexWhere(
            (item) => item.song.id == batch[i].song.id,
          );
          if (index < 0) continue;
          items[index] = LibraryStyleItem(
            song: batch[i].song,
            suggestion: merged,
            style: merged.style,
            selected: true,
          );
        }
      } catch (_) {}
      state = state.copyWith(progress: end, total: pending.length);
    }
  }

  Future<void> applySelected() async {
    final backend = ref.read(backendClientProvider);
    if (!backend.canAuditLibrary) {
      state = state.copyWith(error: 'nas-required');
      return;
    }
    final pending = [
      for (final item in state.suggestedItems)
        if (item.selected && item.style != null) item,
    ];
    if (pending.isEmpty) {
      state = state.copyWith(stage: LibraryStyleStage.done);
      return;
    }
    state = state.copyWith(
      stage: LibraryStyleStage.applying,
      progress: 0,
      total: pending.length,
      applied: 0,
      failedIds: const {},
      clearError: true,
    );
    var cursor = 0;
    var applied = 0;
    var done = 0;
    final failed = <String>{};

    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= pending.length) return;
        final item = pending[index];
        try {
          final result = await backend.updateMediaTags(
            songId: item.song.id,
            genre: item.style,
          );
          if (result.ok) {
            applied += 1;
          } else {
            failed.add(item.song.id);
          }
        } catch (_) {
          failed.add(item.song.id);
        }
        done += 1;
        state = state.copyWith(progress: done, applied: applied);
      }
    }

    await Future.wait([for (var i = 0; i < _applyWorkers; i++) worker()]);
    try {
      await ref.read(subsonicClientProvider).startScan();
    } catch (_) {}
    ref.invalidate(genresProvider);
    state = state.copyWith(
      stage: LibraryStyleStage.done,
      applied: applied,
      failedIds: failed,
      progress: pending.length,
    );
  }

  Future<void> writeOne(String songId, String style) async {
    final backend = ref.read(backendClientProvider);
    if (!backend.canAuditLibrary) {
      state = state.copyWith(error: 'nas-required');
      return;
    }
    if (!libraryStyleSet.contains(style)) return;
    try {
      final result = await backend.updateMediaTags(
        songId: songId,
        genre: style,
      );
      if (!result.ok) {
        state = state.copyWith(error: result.message);
        return;
      }
      setStyle(songId, style);
      try {
        await ref.read(subsonicClientProvider).startScan();
      } catch (_) {}
      ref.invalidate(genresProvider);
      if (state.stage == LibraryStyleStage.done) {
        state = state.copyWith(applied: state.applied + 1);
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  void removeSongs(Iterable<String> songIds) {
    final ids = songIds.toSet();
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (!ids.contains(item.song.id)) item,
      ],
    );
  }
}
