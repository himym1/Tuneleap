import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_providers.dart';

// ============================================================
// 全局收藏
// ============================================================

final starredSongsProvider =
    AsyncNotifierProvider<StarredSongsNotifier, Set<String>>(
      StarredSongsNotifier.new,
    );

class StarredSongsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    try {
      final client = ref.read(subsonicClientProvider);
      final starred = await client.getStarred2();
      return starred.songs.map((s) => s.id).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> star(String songId) async {
    final prev = state.value ?? <String>{};
    state = AsyncData({...prev, songId});
    try {
      await ref.read(subsonicClientProvider).star(id: songId);
    } catch (_) {
      state = AsyncData(Set<String>.from(prev));
    }
  }

  Future<void> unstar(String songId) async {
    final prev = state.value ?? <String>{};
    state = AsyncData(Set<String>.from(prev)..remove(songId));
    try {
      await ref.read(subsonicClientProvider).unstar(id: songId);
    } catch (_) {
      state = AsyncData(Set<String>.from(prev));
    }
  }
}
