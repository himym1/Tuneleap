import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/providers/nas_import_queue_provider.dart';
import 'package:navidrome_player/providers/navidrome_import_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBackendClient extends BackendClient {
  _FakeBackendClient({this.delay = Duration.zero});

  final Duration delay;
  Object? failWith;
  final List<String> importedIds = [];

  @override
  bool get isConfigured => true;
  @override
  bool get canMutateNas => true;

  @override
  Future<String> getPlaybackUrl(Song song, {int? maxBitRate}) async {
    await Future<void>.delayed(delay);
    if (failWith != null) throw failWith!;
    return 'https://cdn.example.com/${song.urlId ?? song.id}.mp3';
  }

  @override
  Future<String> resolveCoverArtUrl(Song song, {int size = 300}) async =>
      'https://cdn.example.com/cover.jpg';

  @override
  Future<String?> getRawLyrics(Song song) async => null;

  @override
  Future<String?> queueNasDownload({
    required String url,
    required String filename,
    required Map<String, dynamic> song,
    String? picUrl,
    String? lyric,
    bool force = false,
  }) async {
    await Future<void>.delayed(delay);
    importedIds.add(song['id']?.toString() ?? filename);
    return 'imported';
  }
}

class _FakeSubsonic extends SubsonicClient {
  int scanCalls = 0;

  @override
  Future<void> startScan({bool fullScan = false}) async {
    scanCalls++;
  }
}

Song _song(String id, {String title = 'Track'}) => Song(
  id: id,
  title: title,
  album: 'Album',
  albumId: '',
  artist: 'Artist',
  artistId: '',
  backend: SongBackend.solara,
  onlineSource: 'netease',
  onlineProvider: 'gdstudio',
  urlId: id,
);

Future<ProviderContainer> _container({
  required _FakeBackendClient backend,
  _FakeSubsonic? subsonic,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      backendClientProvider.overrideWithValue(backend),
      navidromeImportServiceProvider.overrideWithValue(
        NavidromeImportService(backendClient: backend),
      ),
      subsonicClientProvider.overrideWithValue(subsonic ?? _FakeSubsonic()),
      serverConfigProvider.overrideWith(() => _FixedServerConfig()),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queue runs imports serially and marks completed', () async {
    final backend = _FakeBackendClient(delay: const Duration(milliseconds: 40));
    final container = await _container(backend: backend);
    addTearDown(container.dispose);

    final queue = container.read(nasImportQueueProvider.notifier);
    expect(queue.enqueue(_song('1', title: 'One')), isTrue);
    expect(queue.enqueue(_song('2', title: 'Two')), isTrue);
    expect(queue.enqueue(_song('1', title: 'One')), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    final tasks = container.read(nasImportQueueProvider);
    expect(tasks.where((t) => t.stage == NasImportStage.completed).length, 2);
    expect(backend.importedIds, ['1', '2']);
  });

  test('failed import can be retried', () async {
    final backend = _FakeBackendClient()..failWith = StateError('boom');
    final container = await _container(backend: backend);
    addTearDown(container.dispose);

    final queue = container.read(nasImportQueueProvider.notifier);
    queue.enqueue(_song('x'));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    var tasks = container.read(nasImportQueueProvider);
    expect(tasks.single.stage, NasImportStage.failed);

    backend.failWith = null;
    await queue.retry(tasks.single.id);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    tasks = container.read(nasImportQueueProvider);
    expect(tasks.single.stage, NasImportStage.completed);
    expect(backend.importedIds, ['x']);
  });
}

class _FixedServerConfig extends ServerConfigNotifier {
  @override
  ServerConfig build() => const ServerConfig(
    serverId: 'test',
    url: 'http://navidrome.example',
    username: 'u',
    password: 'p',
    backendUrl: 'https://player.himym.us.ci',
    backendApiKey: '',
  );
}
