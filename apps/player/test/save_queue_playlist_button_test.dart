import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/widgets/save_queue_playlist_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingClient extends SubsonicClient {
  String? playlistName;
  List<String>? songIds;

  @override
  Future<void> createPlaylist(String name, {List<String>? songIds}) async {
    playlistName = name;
    this.songIds = songIds;
  }
}

class _TestServerConfigNotifier extends ServerConfigNotifier {
  @override
  ServerConfig build() => const ServerConfig(
    serverId: 'server-a',
    url: 'http://server-a',
    username: 'user',
    password: '',
    backendUrl: '',
    backendApiKey: '',
  );

  void switchTo(String serverId) {
    state = ServerConfig(
      serverId: serverId,
      url: 'http://$serverId',
      username: 'user',
      password: '',
      backendUrl: '',
      backendApiKey: '',
    );
  }
}

const _localSong = Song(
  id: 'local',
  title: 'Local',
  album: 'Album',
  albumId: 'album',
  artist: 'Artist',
  artistId: 'artist',
);

const _onlineSong = Song(
  id: 'online',
  title: 'Online',
  album: 'Album',
  albumId: '',
  artist: 'Artist',
  artistId: '',
  backend: SongBackend.solara,
  onlineSource: 'netease',
);

Future<(ProviderContainer, _RecordingClient)> _pumpButton(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({
    'active_server_id': 'server-a',
    'server_url': 'http://server-a',
    'server_username': 'user',
  });
  final prefs = await SharedPreferences.getInstance();
  final client = _RecordingClient();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      subsonicClientProvider.overrideWithValue(client),
      serverConfigProvider.overrideWith(_TestServerConfigNotifier.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(
          body: SaveQueuePlaylistButton(queue: [_localSong, _onlineSong]),
        ),
      ),
    ),
  );
  return (container, client);
}

void main() {
  testWidgets(
    'saving a queue keeps local songs and reports skipped online songs',
    (tester) async {
      final (_, client) = await _pumpButton(tester);

      await tester.tap(find.byTooltip('Save Queue as Playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Road Trip');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(client.playlistName, 'Road Trip');
      expect(client.songIds, ['local']);
      expect(
        find.text('Saved as "Road Trip"; skipped 1 online songs'),
        findsOneWidget,
      );
    },
  );

  testWidgets('server switch while naming prevents cross-server queue save', (
    tester,
  ) async {
    final (container, client) = await _pumpButton(tester);

    await tester.tap(find.byTooltip('Save Queue as Playlist'));
    await tester.pumpAndSettle();
    (container.read(serverConfigProvider.notifier) as _TestServerConfigNotifier)
        .switchTo('server-b');
    await tester.enterText(find.byType(TextField), 'Wrong Server');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(client.playlistName, isNull);
    expect(find.text('Failed to save queue'), findsOneWidget);
  });
}
