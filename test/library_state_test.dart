import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/artist.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/library_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingLibraryClient extends SubsonicClient {
  @override
  Future<List<Artist>> getArtists() => Future.error(StateError('offline'));
}

void main() {
  test(
    'initial library failure is represented as an error, not an empty library',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_server_id': 'a',
        'server_url': 'http://a',
        'server_username': 'a',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          subsonicClientProvider.overrideWithValue(_FailingLibraryClient()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        libraryProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await Future<void>.delayed(Duration.zero);

      final state = container.read(libraryProvider);
      expect(state.loading, isFalse);
      expect(state.error, isA<StateError>());
    },
  );
}
