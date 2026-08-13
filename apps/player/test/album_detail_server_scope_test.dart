import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/album.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/album_detail_provider.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AlbumClient extends SubsonicClient {
  _AlbumClient(this.album);

  final Album album;

  @override
  Future<Album> getAlbum(String id) async => album;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('album detail reloads when the active server changes', () async {
    SharedPreferences.setMockInitialValues({
      'active_server_id': 'a',
      'server_url': 'http://a',
      'server_username': 'a',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        subsonicClientProvider.overrideWith((ref) {
          final serverId = ref.watch(
            serverConfigProvider.select((config) => config.serverId),
          );
          return _AlbumClient(Album(id: 'same', name: 'Album $serverId'));
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      albumDetailProvider('same'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);
    expect(container.read(albumDetailProvider('same')).album?.name, 'Album a');

    await container
        .read(serverConfigProvider.notifier)
        .save(
          serverId: 'b',
          url: 'http://b',
          username: 'b',
          password: '',
          backendUrl: 'http://backend-b',
          backendApiKey: '',
        );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(albumDetailProvider('same')).album?.name, 'Album b');
  });
}
