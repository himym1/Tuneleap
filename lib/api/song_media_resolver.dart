import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/solara_client.dart';
import 'package:navidrome_player/api/subsonic_client.dart';

class SongMediaResolver {
  final SubsonicClient subsonicClient;
  final SolaraClient solaraClient;

  const SongMediaResolver({
    required this.subsonicClient,
    required this.solaraClient,
  });

  Future<String> coverArtUrl(Song song, {int size = 300}) async {
    if (song.isOnline) {
      return solaraClient.resolveCoverArtUrl(song, size: size);
    }
    return subsonicClient.coverArtUrl(song.coverArt, size: size);
  }

  Future<String> playbackUrl(Song song, {int? maxBitRate}) async {
    if (song.isOnline) {
      return solaraClient.getPlaybackUrl(song, maxBitRate: maxBitRate);
    }
    return subsonicClient.streamUrl(song.id, maxBitRate: maxBitRate);
  }

  Future<LyricsList?> lyrics(Song song) async {
    if (song.isOnline) {
      return solaraClient.getLyrics(song);
    }
    return subsonicClient.getLyricsBySongId(song.id);
  }

  Future<void> scrobble(Song song) async {
    if (song.isOnline) return;
    await subsonicClient.scrobble(song.id);
  }

  bool supportsLibraryMutations(Song song) => !song.isOnline;
}
