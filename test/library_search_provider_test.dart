import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/album.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/library_search_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SearchClient extends SubsonicClient {
  final pending = Completer<SearchResult>();
  int calls = 0;
  String? query;

  @override
  Future<SearchResult> search3(
    String value, {
    int artistCount = 10,
    int albumCount = 10,
    int songCount = 20,
    int artistOffset = 0,
    int albumOffset = 0,
    int songOffset = 0,
  }) {
    calls++;
    query = value;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'debounces search and ignores a result after same-id reconfiguration',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_server_id': 'a',
        'server_url': 'http://a',
        'server_username': 'a',
      });
      final prefs = await SharedPreferences.getInstance();
      final client = _SearchClient();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          subsonicClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final provider = librarySearchProvider(LibrarySearchType.albums);
      final subscription = container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(provider.notifier);

      notifier.onQueryChanged('jazz');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(client.calls, 0);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(client.calls, 1);
      expect(client.query, 'jazz');

      await container
          .read(serverConfigProvider.notifier)
          .save(
            serverId: 'a',
            url: 'http://new-a',
            username: 'new-a',
            password: '',
            backendUrl: 'http://backend-a',
            backendApiKey: '',
          );
      await Future<void>.delayed(Duration.zero);

      client.pending.complete(
        const SearchResult(
          albums: [Album(id: 'old', name: 'Old server')],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider).albums, isNull);
      expect(container.read(provider).serverId, isNull);
    },
  );
}
