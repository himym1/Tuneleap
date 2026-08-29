import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/utils/library_style.dart';
import 'package:navidrome_player/utils/library_style_playlists.dart';

import 'audio_providers.dart';
import 'library_cache_provider.dart';
import 'playlist_provider.dart';
import 'server_config_provider.dart';

enum LibraryPlaylistStage { idle, analyzing, preview, applying, done }

enum LibraryPlaylistFilter { lists, leftover }

class LibraryPlaylistState {
  const LibraryPlaylistState({
    this.stage = LibraryPlaylistStage.idle,
    this.onlyMissing = true,
    this.draft = const StylePlaylistDraft(
      buckets: [],
      leftover: [],
      scanned: 0,
    ),
    this.filter = LibraryPlaylistFilter.lists,
    this.appliedLists = 0,
    this.failedLists = const {},
    this.progress = 0,
    this.total = 0,
    this.error,
  });

  final LibraryPlaylistStage stage;
  final bool onlyMissing;
  final StylePlaylistDraft draft;
  final LibraryPlaylistFilter filter;
  final int appliedLists;
  final Set<String> failedLists;
  final int progress;
  final int total;
  final String? error;

  LibraryPlaylistState copyWith({
    LibraryPlaylistStage? stage,
    bool? onlyMissing,
    StylePlaylistDraft? draft,
    LibraryPlaylistFilter? filter,
    int? appliedLists,
    Set<String>? failedLists,
    int? progress,
    int? total,
    String? error,
    bool clearError = false,
  }) {
    return LibraryPlaylistState(
      stage: stage ?? this.stage,
      onlyMissing: onlyMissing ?? this.onlyMissing,
      draft: draft ?? this.draft,
      filter: filter ?? this.filter,
      appliedLists: appliedLists ?? this.appliedLists,
      failedLists: failedLists ?? this.failedLists,
      progress: progress ?? this.progress,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final libraryPlaylistOrganizeProvider =
    NotifierProvider<LibraryPlaylistOrganizeNotifier, LibraryPlaylistState>(
      LibraryPlaylistOrganizeNotifier.new,
    );

class LibraryPlaylistOrganizeNotifier extends Notifier<LibraryPlaylistState> {
  @override
  LibraryPlaylistState build() {
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    return const LibraryPlaylistState();
  }

  void reset() {
    state = LibraryPlaylistState(onlyMissing: state.onlyMissing);
  }

  void setFilter(LibraryPlaylistFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void toggleBucket(String name) {
    state = state.copyWith(
      draft: StylePlaylistDraft(
        scanned: state.draft.scanned,
        leftover: state.draft.leftover,
        buckets: [
          for (final bucket in state.draft.buckets)
            if (bucket.name == name)
              bucket.copyWith(selected: !bucket.selected)
            else
              bucket,
        ],
      ),
    );
  }

  Future<void> analyze({required bool onlyMissing}) async {
    state = state.copyWith(
      stage: LibraryPlaylistStage.analyzing,
      onlyMissing: onlyMissing,
      clearError: true,
    );
    try {
      final client = ref.read(subsonicClientProvider);
      final songs = await client.getLibrarySongs();
      final playlists = await client.getPlaylists();
      final existingIds = <String, String>{};
      final existingSongs = <String, Set<String>>{};
      for (final playlist in playlists) {
        if (!libraryStyleSet.contains(playlist.name)) continue;
        existingIds.putIfAbsent(playlist.name, () => playlist.id);
        final detail = await client.getPlaylist(playlist.id);
        existingSongs.putIfAbsent(playlist.name, () => <String>{});
        existingSongs[playlist.name]!.addAll([
          for (final song in detail.songs) song.id,
        ]);
      }
      final draft = buildStylePlaylistDraft(
        songs: songs,
        existingStyleSongIds: existingSongs,
        existingPlaylistIds: existingIds,
        onlyMissingFromPlaylists: onlyMissing,
      );
      state = state.copyWith(
        stage: LibraryPlaylistStage.preview,
        draft: draft,
        filter: draft.buckets.isEmpty
            ? LibraryPlaylistFilter.leftover
            : LibraryPlaylistFilter.lists,
      );
    } catch (error) {
      state = state.copyWith(
        stage: LibraryPlaylistStage.idle,
        error: error.toString(),
      );
    }
  }

  Future<void> applySelected() async {
    final pending = [
      for (final bucket in state.draft.buckets)
        if (bucket.selected && bucket.toAdd.isNotEmpty) bucket,
    ];
    if (pending.isEmpty) {
      state = state.copyWith(stage: LibraryPlaylistStage.done);
      return;
    }
    state = state.copyWith(
      stage: LibraryPlaylistStage.applying,
      progress: 0,
      total: pending.length,
      appliedLists: 0,
      failedLists: const {},
      clearError: true,
    );
    var applied = 0;
    var done = 0;
    final failed = <String>{};
    final service = ref.read(playlistServiceProvider);
    for (final bucket in pending) {
      try {
        await _writeBucket(service, bucket);
        applied += 1;
      } catch (_) {
        failed.add(bucket.name);
      }
      done += 1;
      state = state.copyWith(
        progress: done,
        appliedLists: applied,
        failedLists: {...failed},
      );
    }
    ref.invalidate(playlistsProvider);
    state = state.copyWith(
      stage: LibraryPlaylistStage.done,
      appliedLists: applied,
      failedLists: failed,
    );
  }

  Future<void> assignLeftover(Song song, String style) async {
    if (!libraryStyleSet.contains(style)) return;
    final backend = ref.read(backendClientProvider);
    if (backend.canAuditLibrary) {
      try {
        await backend.updateMediaTags(songId: song.id, genre: style);
        try {
          await ref.read(subsonicClientProvider).startScan();
        } catch (_) {}
        ref.invalidate(genresProvider);
      } catch (error) {
        state = state.copyWith(error: error.toString());
        return;
      }
    }
    final tagged = song.copyWith(genre: style);
    final leftover = [
      for (final item in state.draft.leftover)
        if (item.id != song.id) item,
    ];
    final buckets = [...state.draft.buckets];
    final index = buckets.indexWhere((bucket) => bucket.name == style);
    if (index >= 0) {
      buckets[index] = buckets[index].copyWith(
        toAdd: [...buckets[index].toAdd, tagged],
      );
    } else {
      buckets.add(StylePlaylistBucket(name: style, toAdd: [tagged]));
    }
    state = state.copyWith(
      draft: StylePlaylistDraft(
        scanned: state.draft.scanned,
        leftover: leftover,
        buckets: [
          for (final name in libraryStyleNames)
            for (final bucket in buckets)
              if (bucket.name == name) bucket,
        ],
      ),
      filter: LibraryPlaylistFilter.lists,
      clearError: true,
    );
    if (state.stage == LibraryPlaylistStage.done) {
      StylePlaylistBucket? bucket;
      for (final item in state.draft.buckets) {
        if (item.name == style) bucket = item;
      }
      if (bucket != null) {
        try {
          await _writeBucket(
            ref.read(playlistServiceProvider),
            bucket.copyWith(toAdd: [tagged]),
          );
          ref.invalidate(playlistsProvider);
        } catch (error) {
          state = state.copyWith(error: error.toString());
        }
      }
    }
  }

  void removeSongs(Iterable<String> songIds) {
    final ids = songIds.toSet();
    state = state.copyWith(
      draft: StylePlaylistDraft(
        scanned: state.draft.scanned,
        leftover: [
          for (final song in state.draft.leftover)
            if (!ids.contains(song.id)) song,
        ],
        buckets: [
          for (final bucket in state.draft.buckets)
            bucket.copyWith(
              toAdd: [
                for (final song in bucket.toAdd)
                  if (!ids.contains(song.id)) song,
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _writeBucket(
    PlaylistService service,
    StylePlaylistBucket bucket,
  ) async {
    final ids = [for (final song in bucket.toAdd) song.id];
    if (ids.isEmpty) return;
    final existingId = bucket.existingPlaylistId;
    if (existingId == null) {
      final chunks = chunkSongIds(ids);
      await service.createPlaylist(bucket.name, songIds: chunks.first);
      if (chunks.length == 1) return;
      final created = await _playlistIdByName(bucket.name);
      if (created == null) {
        throw StateError('created playlist not found');
      }
      for (final chunk in chunks.skip(1)) {
        await service.updatePlaylist(created, songIdsToAdd: chunk);
      }
      return;
    }
    for (final chunk in chunkSongIds(ids)) {
      await service.updatePlaylist(existingId, songIdsToAdd: chunk);
    }
  }

  Future<String?> _playlistIdByName(String name) async {
    final playlists = await ref.read(playlistServiceProvider).getPlaylists();
    for (final playlist in playlists) {
      if (playlist.name == name) return playlist.id;
    }
    return null;
  }
}
