import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';

import 'audio_providers.dart';

final navidromeDeleteServiceProvider = Provider<NavidromeDeleteService>((ref) {
  return NavidromeDeleteService(
    backendClient: ref.watch(backendClientProvider),
  );
});

class NavidromeDeleteService {
  NavidromeDeleteService({required this.backendClient});

  final BackendClient backendClient;

  Future<NasDeleteResult> deleteLibrarySong(Song song) async {
    if (song.isOnline || song.isRadio) {
      throw ArgumentError('Only local library songs can be deleted');
    }
    if (!backendClient.canMutateNas) {
      throw StateError('Cloud is not configured');
    }
    return backendClient.deleteLibrarySongs([song.id]);
  }
}
