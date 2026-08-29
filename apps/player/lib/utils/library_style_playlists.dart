import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/utils/library_style.dart';

class StylePlaylistBucket {
  const StylePlaylistBucket({
    required this.name,
    required this.toAdd,
    this.existingPlaylistId,
    this.alreadyIn = 0,
    this.selected = true,
  });

  final String name;
  final List<Song> toAdd;
  final String? existingPlaylistId;
  final int alreadyIn;
  final bool selected;

  bool get isNew => existingPlaylistId == null;

  StylePlaylistBucket copyWith({
    List<Song>? toAdd,
    bool? selected,
    String? existingPlaylistId,
    int? alreadyIn,
  }) {
    return StylePlaylistBucket(
      name: name,
      toAdd: toAdd ?? this.toAdd,
      existingPlaylistId: existingPlaylistId ?? this.existingPlaylistId,
      alreadyIn: alreadyIn ?? this.alreadyIn,
      selected: selected ?? this.selected,
    );
  }
}

class StylePlaylistDraft {
  const StylePlaylistDraft({
    required this.buckets,
    required this.leftover,
    required this.scanned,
  });

  final List<StylePlaylistBucket> buckets;
  final List<Song> leftover;
  final int scanned;

  int get addCount => buckets.fold<int>(0, (sum, bucket) {
    return sum + (bucket.selected ? bucket.toAdd.length : 0);
  });
}

/// Group tagged songs into the closed style lists. Membership comes from
/// file genre already visible on Subsonic songs, not from media-tags.
StylePlaylistDraft buildStylePlaylistDraft({
  required List<Song> songs,
  required Map<String, Set<String>> existingStyleSongIds,
  required Map<String, String> existingPlaylistIds,
  bool onlyMissingFromPlaylists = true,
}) {
  final alreadyInAny = <String>{};
  if (onlyMissingFromPlaylists) {
    for (final ids in existingStyleSongIds.values) {
      alreadyInAny.addAll(ids);
    }
  }

  final leftover = <Song>[];
  final grouped = <String, List<Song>>{
    for (final name in libraryStyleNames) name: <Song>[],
  };
  final seen = <String>{};

  for (final song in songs) {
    if (!seen.add(song.id)) continue;
    if (onlyMissingFromPlaylists && alreadyInAny.contains(song.id)) {
      continue;
    }
    final style = closedStyleOf(song.genre);
    if (style == null) {
      leftover.add(song);
      continue;
    }
    if (existingStyleSongIds[style]?.contains(song.id) ?? false) {
      continue;
    }
    grouped[style]!.add(song);
  }

  return StylePlaylistDraft(
    scanned: seen.length,
    leftover: leftover,
    buckets: [
      for (final name in libraryStyleNames)
        if (grouped[name]!.isNotEmpty)
          StylePlaylistBucket(
            name: name,
            toAdd: grouped[name]!,
            existingPlaylistId: existingPlaylistIds[name],
            alreadyIn: existingStyleSongIds[name]?.length ?? 0,
          ),
    ],
  );
}

List<List<String>> chunkSongIds(List<String> ids, {int size = 80}) {
  if (ids.isEmpty) return const [];
  return [
    for (var offset = 0; offset < ids.length; offset += size)
      ids.sublist(
        offset,
        offset + size > ids.length ? ids.length : offset + size,
      ),
  ];
}
