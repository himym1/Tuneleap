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
  Future<String> getPlaybackUrl(
    Song song, {
    int? maxBitRate,
    bool bypassCache = false,
  }) async {
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

  NasImportProgress progress = const NasImportProgress();

  @override
  Future<NasImportProgress> getNasImportProgress() async => progress;
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

    await _waitUntil(
      () =>
          container
              .read(nasImportQueueProvider)
              .where((t) => t.stage == NasImportStage.completed)
              .length ==
          2,
    );

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
    await _waitUntil(
      () =>
          container.read(nasImportQueueProvider).single.stage ==
          NasImportStage.failed,
    );

    var tasks = container.read(nasImportQueueProvider);
    expect(tasks.single.stage, NasImportStage.failed);

    backend.failWith = null;
    await queue.retry(tasks.single.id);
    await _waitUntil(
      () =>
          container.read(nasImportQueueProvider).single.stage ==
          NasImportStage.completed,
    );

    tasks = container.read(nasImportQueueProvider);
    expect(tasks.single.stage, NasImportStage.completed);
    expect(backend.importedIds, ['x']);
  });

  test('uploading task shows NAS transfer progress', () async {
    final backend = _FakeBackendClient(delay: const Duration(milliseconds: 80))
      ..progress = const NasImportProgress(
        active: true,
        filename: 'solara_netease_via-gdstudio_p.mp3',
        bytesReceived: 12 * 1024 * 1024,
        bytesTotal: 160 * 1024 * 1024,
        speedBps: 48 * 1024,
        stage: 'downloading',
      );
    final container = await _container(backend: backend);
    addTearDown(container.dispose);

    container.read(nasImportQueueProvider.notifier).enqueue(_song('p'));
    await _waitUntil(() {
      final tasks = container.read(nasImportQueueProvider);
      return tasks.isNotEmpty &&
          tasks.single.bytesReceived > 0 &&
          tasks.single.stage == NasImportStage.uploading;
    });

    final task = container.read(nasImportQueueProvider).single;
    expect(task.bytesReceived, 12 * 1024 * 1024);
    expect(task.bytesTotal, 160 * 1024 * 1024);
    expect(formatNasImportTransfer(task), '12.0 MB / 160.0 MB · 48 KB/s');
  });

  test('transfer labels format bytes and speed', () {
    expect(formatNasImportBytes(900), '900 B');
    expect(formatNasImportBytes(48 * 1024), '48 KB');
    expect(formatNasImportBytes(12 * 1024 * 1024), '12.0 MB');
    expect(formatNasImportSpeed(48 * 1024), '48 KB/s');
  });
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final end = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
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
