import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';

import 'audio_providers.dart';

final navidromeDeleteServiceProvider = Provider<NavidromeDeleteService>((ref) {
  return NavidromeDeleteService(
    backendClient: ref.watch(backendClientProvider),
  );
});

const navidromeDeleteChunkSize = 50;

class NavidromeDeleteService {
  NavidromeDeleteService({required this.backendClient});

  final BackendClient backendClient;

  Future<NasDeleteResult> deleteLibrarySong(Song song) async {
    if (song.isOnline || song.isRadio) {
      throw ArgumentError('Only local library songs can be deleted');
    }
    return deleteLibrarySongIds([song.id]);
  }

  Future<NasDeleteResult> deleteLibrarySongIds(List<String> songIds) async {
    final ids = [
      for (final id in songIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    if (ids.isEmpty) {
      throw ArgumentError('song ids required');
    }
    if (!backendClient.canMutateNas) {
      throw StateError('Cloud is not configured');
    }
    var deleted = 0;
    var skipped = 0;
    var errors = 0;
    var message = '';
    NasDeleteException? lastNotFound;
    for (
      var offset = 0;
      offset < ids.length;
      offset += navidromeDeleteChunkSize
    ) {
      final end = offset + navidromeDeleteChunkSize;
      final chunk = ids.sublist(offset, end > ids.length ? ids.length : end);
      try {
        final result = await backendClient.deleteLibrarySongs(chunk);
        deleted += result.deleted;
        skipped += result.skipped;
        errors += result.errors;
        if (result.message.isNotEmpty) message = result.message;
      } on NasDeleteException catch (error) {
        if (error.message.toLowerCase().contains('not found')) {
          skipped += chunk.length;
          lastNotFound = error;
          continue;
        }
        rethrow;
      }
    }
    if (deleted == 0 && skipped > 0 && errors == 0 && lastNotFound != null) {
      throw lastNotFound;
    }
    return NasDeleteResult(
      deleted: deleted,
      skipped: skipped,
      errors: errors,
      message: message,
    );
  }
}
