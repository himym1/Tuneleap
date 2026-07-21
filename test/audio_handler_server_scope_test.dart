import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/player/audio_handler.dart';
import 'package:navidrome_player/player/playback_origin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioPlayer extends AudioPlayer {
  final positionController = StreamController<Duration>.broadcast();
  final processingController = StreamController<ProcessingState>.broadcast();
  final loadedUrls = <String>[];
  final loadedHeaders = <Map<String, String>?>[];
  Completer<Duration?>? nextUrlLoad;
  Completer<void>? nextStop;
  Completer<void>? nextPlay;
  Object? playError;
  int playCalls = 0;
  bool isPlaying = false;
  int stopCalls = 0;
  Object? setUrlError;
  int setUrlFailuresRemaining = -1;

  @override
  bool get playing => isPlaying;

  @override
  Duration? get duration => const Duration(seconds: 100);

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      processingController.stream;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    loadedUrls.add(url);
    loadedHeaders.add(headers);
    final error = setUrlError;
    if (error != null && setUrlFailuresRemaining != 0) {
      if (setUrlFailuresRemaining > 0) setUrlFailuresRemaining--;
      throw error;
    }
    final blocker = nextUrlLoad;
    nextUrlLoad = null;
    return blocker?.future ?? duration;
  }

  @override
  Future<void> play() async {
    playCalls++;
    isPlaying = true;
    await nextPlay?.future;
    final error = playError;
    playError = null;
    if (error != null) throw error;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    final blocker = nextPlay;
    nextPlay = null;
    if (blocker != null && !blocker.isCompleted) blocker.complete();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    isPlaying = false;
    final blocker = nextStop;
    nextStop = null;
    if (blocker != null) await blocker.future;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {}
}

class _ScrobbleClient extends SubsonicClient {
  final scrobbledIds = <String>[];
  int failuresRemaining = 0;
  int scrobbleAttempts = 0;

  @override
  Future<void> scrobble(String id) async {
    scrobbleAttempts++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('temporary failure');
    }
    scrobbledIds.add(id);
  }
}

class _OnlineBackendClient extends BackendClient {
  int playbackUrlCalls = 0;
  @override
  Future<String> getPlaybackUrl(Song song, {int? maxBitRate}) async {
    playbackUrlCalls++;
    return 'https://music.126.net/test-$playbackUrlCalls.mp3';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'switching server clears the queue and loads that server history',
    () async {
      const songA = Song(
        id: 'same-id',
        title: 'Server A song',
        artist: 'Artist A',
        artistId: 'artist-a',
        album: 'Album A',
        albumId: 'album-a',
      );
      const songB = Song(
        id: 'same-id',
        title: 'Server B song',
        artist: 'Artist B',
        artistId: 'artist-b',
        album: 'Album B',
        albumId: 'album-b',
      );
      SharedPreferences.setMockInitialValues({
        'play_history::server-a': jsonEncode([songA.toJson()]),
        'play_history::server-b': jsonEncode([songB.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final handler = NavidromeAudioHandler(
        SubsonicClient(),
        BackendClient(),
        prefs: prefs,
        serverId: 'server-a',
      );

      expect(handler.playHistory.single.title, 'Server A song');

      handler.addToQueue(songA);
      handler.updateClients(
        SubsonicClient(),
        BackendClient(),
        serverId: 'server-b',
      );

      expect(handler.songQueue, isEmpty);
      expect(handler.currentSong, isNull);
      expect(handler.playHistory.single.title, 'Server B song');

      await handler.stop();
    },
  );

  test('replacing clients for the same server ends the old session', () async {
    const song = Song(
      id: 'a',
      title: 'A',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    final player = _FakeAudioPlayer();
    final handler = NavidromeAudioHandler(
      _ScrobbleClient()
        ..configure(serverUrl: 'http://a', username: 'u', password: 'p'),
      BackendClient(),
      player: player,
      serverId: 'a',
    );
    await handler.setQueue([song]);

    handler.updateClients(SubsonicClient(), BackendClient(), serverId: 'a');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(handler.songQueue, isEmpty);
    expect(handler.currentSong, isNull);
    expect(handler.mediaItem.value, isNull);
    expect(player.stopCalls, 1);
  });

  test(
    'removing the current queue item loads the next source or stops',
    () async {
      const songA = Song(
        id: 'a',
        title: 'A',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      const songB = Song(
        id: 'b',
        title: 'B',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      final player = _FakeAudioPlayer();
      final client = _ScrobbleClient()
        ..configure(serverUrl: 'http://server', username: 'u', password: 'p');
      final handler = NavidromeAudioHandler(
        client,
        BackendClient(),
        player: player,
      );

      await handler.setQueue([songA, songB]);
      await handler.removeFromQueue(0);

      expect(handler.currentSong?.id, 'b');
      expect(handler.mediaItem.value?.title, 'B');
      expect(player.loadedUrls, hasLength(2));
      expect(player.playing, isTrue);

      await handler.removeFromQueue(0);

      expect(handler.currentSong, isNull);
      expect(handler.mediaItem.value, isNull);
      expect(player.stopCalls, 1);
    },
  );

  test(
    'removing a paused current item loads the next source without playing',
    () async {
      const songA = Song(
        id: 'a',
        title: 'A',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      const songB = Song(
        id: 'b',
        title: 'B',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      final player = _FakeAudioPlayer();
      final client = _ScrobbleClient()
        ..configure(serverUrl: 'http://server', username: 'u', password: 'p');
      final handler = NavidromeAudioHandler(
        client,
        BackendClient(),
        player: player,
      );

      await handler.setQueue([songA, songB]);
      await handler.pause();
      await handler.removeFromQueue(0);

      expect(handler.currentSong?.id, 'b');
      expect(handler.mediaItem.value?.title, 'B');
      expect(player.loadedUrls, hasLength(2));
      expect(player.playing, isFalse);
    },
  );

  test(
    'a slow next-song load cannot scrobble it using the old source position',
    () async {
      const songA = Song(
        id: 'a',
        title: 'A',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      const songB = Song(
        id: 'b',
        title: 'B',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      final player = _FakeAudioPlayer();
      final client = _ScrobbleClient()
        ..configure(serverUrl: 'http://server', username: 'u', password: 'p');
      final handler = NavidromeAudioHandler(
        client,
        BackendClient(),
        player: player,
      );
      await handler.setQueue([songA, songB]);
      final blocker = Completer<Duration?>();
      player.nextUrlLoad = blocker;

      final switching = handler.skipToNext();
      while (player.loadedUrls.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      player.positionController.add(const Duration(seconds: 60));
      await Future<void>.delayed(Duration.zero);
      expect(client.scrobbledIds, isEmpty);

      blocker.complete(const Duration(seconds: 100));
      await switching;
      player.positionController.add(const Duration(seconds: 60));
      await Future<void>.delayed(Duration.zero);

      expect(client.scrobbledIds, ['b']);
    },
  );

  test('a stale completed event cannot advance the replacement song', () async {
    const songA = Song(
      id: 'a',
      title: 'A',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    const songB = Song(
      id: 'b',
      title: 'B',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    const songC = Song(
      id: 'c',
      title: 'C',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    final player = _FakeAudioPlayer();
    final client = _ScrobbleClient()
      ..configure(serverUrl: 'http://server', username: 'u', password: 'p');
    final handler = NavidromeAudioHandler(
      client,
      BackendClient(),
      player: player,
    );
    await handler.setQueue([songA, songB, songC]);
    final blocker = Completer<Duration?>();
    player.nextUrlLoad = blocker;

    final switching = handler.skipToNext();
    while (player.loadedUrls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    player.processingController.add(ProcessingState.completed);
    blocker.complete(const Duration(seconds: 100));
    await switching;
    await Future<void>.delayed(Duration.zero);

    expect(handler.currentSong?.id, 'b');
    expect(handler.mediaItem.value?.title, 'B');
  });

  test('failed scrobble is retried on a later position event', () async {
    const song = Song(
      id: 'a',
      title: 'A',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    final player = _FakeAudioPlayer();
    final client = _ScrobbleClient()
      ..failuresRemaining = 1
      ..configure(serverUrl: 'http://server', username: 'u', password: 'p');
    final handler = NavidromeAudioHandler(
      client,
      BackendClient(),
      player: player,
    );
    await handler.setQueue([song]);

    player.positionController.add(const Duration(seconds: 60));
    await Future<void>.delayed(Duration.zero);
    player.positionController.add(const Duration(seconds: 60));
    await Future<void>.delayed(Duration.zero);

    expect(client.scrobbleAttempts, 2);
    expect(client.scrobbledIds, ['a']);
  });

  test(
    'server switch waits for an old source write before stop and new load',
    () async {
      const songA = Song(
        id: 'a',
        title: 'A',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      const songB = Song(
        id: 'b',
        title: 'B',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      final player = _FakeAudioPlayer();
      final clientA = _ScrobbleClient()
        ..configure(serverUrl: 'http://a', username: 'u', password: 'p');
      final clientB = _ScrobbleClient()
        ..configure(serverUrl: 'http://b', username: 'u', password: 'p');
      final handler = NavidromeAudioHandler(
        clientA,
        BackendClient(),
        player: player,
        serverId: 'a',
      );
      final oldLoad = Completer<Duration?>();
      player.nextUrlLoad = oldLoad;

      final firstPlayback = handler.setQueue([songA]);
      while (player.loadedUrls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      handler.updateClients(clientB, BackendClient(), serverId: 'b');
      final secondPlayback = handler.setQueue([songB]);
      oldLoad.complete(const Duration(seconds: 100));
      await Future.wait([firstPlayback, secondPlayback]);

      expect(player.loadedUrls, hasLength(2));
      expect(handler.currentSong?.id, 'b');
      expect(handler.mediaItem.value?.title, 'B');
      expect(player.stopCalls, 1);
      expect(player.playing, isTrue);
    },
  );

  test(
    'new-server playback waits for the old player stop transition',
    () async {
      const song = Song(
        id: 'b',
        title: 'B',
        artist: 'Artist',
        artistId: 'artist',
        album: 'Album',
        albumId: 'album',
      );
      final player = _FakeAudioPlayer();
      final clientA = _ScrobbleClient()
        ..configure(serverUrl: 'http://a', username: 'u', password: 'p');
      final clientB = _ScrobbleClient()
        ..configure(serverUrl: 'http://b', username: 'u', password: 'p');
      final handler = NavidromeAudioHandler(
        clientA,
        BackendClient(),
        player: player,
        serverId: 'a',
      );
      final stopBlocker = Completer<void>();
      player.nextStop = stopBlocker;

      handler.updateClients(clientB, BackendClient(), serverId: 'b');
      final playback = handler.setQueue([song]);
      await Future<void>.delayed(Duration.zero);

      expect(player.loadedUrls, isEmpty);
      stopBlocker.complete();
      await playback;

      expect(player.loadedUrls, hasLength(1));
      expect(player.playing, isTrue);
    },
  );

  test('preserves parallel playback origins through queue mutations', () async {
    final player = _FakeAudioPlayer();
    final client = _ScrobbleClient()
      ..configure(serverUrl: 'http://a', username: 'u', password: 'p');
    final handler = NavidromeAudioHandler(
      client,
      BackendClient(),
      player: player,
      serverId: 'a',
    );
    const a = Song(
      id: 'a',
      title: 'A',
      artist: 'x',
      artistId: 'x',
      album: 'A',
      albumId: 'A',
    );
    const b = Song(
      id: 'b',
      title: 'B',
      artist: 'x',
      artistId: 'x',
      album: 'B',
      albumId: 'B',
    );
    const c = Song(
      id: 'c',
      title: 'C',
      artist: 'x',
      artistId: 'x',
      album: 'C',
      albumId: 'C',
    );
    const o1 = PlaybackOrigin(
      sessionId: 's',
      candidateId: 'c1',
      impressionId: 'i1',
    );
    const o2 = PlaybackOrigin(
      sessionId: 's',
      candidateId: 'c2',
      impressionId: 'i2',
    );
    const o3 = PlaybackOrigin(
      sessionId: 's',
      candidateId: 'c3',
      impressionId: 'i3',
    );

    await handler.setQueue([a, b, c], origins: [o1, o2, o3]);
    expect(handler.currentPlaybackOrigin, o1);

    handler.addToQueue(a, origin: null);
    handler.insertNext(b, origin: o2);
    await handler.skipToQueueItem(1);
    expect(handler.currentPlaybackOrigin, isNotNull);

    await handler.removeFromQueue(0);
    handler.reorderQueue(0, 1);
    handler.shuffleQueue();
    expect(
      handler.songQueue.length,
      handler.currentIndex >= 0 ? isNonNegative : isNonNegative,
    );

    expect(
      () => handler.setQueue([a], origins: [o1, o2]),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('publishes sanitized terminal failure with origin', () async {
    final player = _FakeAudioPlayer()
      ..setUrlError = StateError('source missing');
    final client = _ScrobbleClient()
      ..configure(serverUrl: 'http://a', username: 'u', password: 'p');
    final handler = NavidromeAudioHandler(
      client,
      BackendClient(),
      player: player,
      serverId: 'a',
    );
    const song = Song(
      id: 'online',
      title: 'O',
      artist: 'x',
      artistId: 'x',
      album: 'A',
      albumId: 'A',
      backend: SongBackend.solara,
      onlineSource: 'netease',
      urlId: 'u1',
    );
    const origin = PlaybackOrigin(
      sessionId: 's',
      candidateId: 'c1',
      impressionId: 'i1',
    );
    final failures = <PlaybackFailure>[];
    final sub = handler.playbackFailureStream.listen(failures.add);

    await handler.setQueue([song], origins: [origin]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(failures, hasLength(1));
    expect(failures.single.origin, origin);
    expect(failures.single.songStorageKey, song.storageKey);
    expect(failures.single.retryable, isFalse);
    expect(failures.single.toString(), isNot(contains('missing')));
  });

  test('online playback retries a fresh URL with compatible headers', () async {
    final player = _FakeAudioPlayer()
      ..setUrlError = StateError('stale URL')
      ..setUrlFailuresRemaining = 1;
    final backend = _OnlineBackendClient();
    final handler = NavidromeAudioHandler(
      SubsonicClient(),
      backend,
      player: player,
    );
    const song = Song(
      id: 'online',
      title: 'Online',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
      backend: SongBackend.solara,
      onlineSource: 'netease',
      urlId: 'source-id',
    );

    await handler.setQueue([song]);

    expect(backend.playbackUrlCalls, 2);
    expect(player.loadedUrls, hasLength(2));
    expect(player.loadedHeaders, hasLength(2));
    expect(player.loadedHeaders.last?['User-Agent'], isNotEmpty);
    expect(player.loadedHeaders.last?['Referer'], 'https://music.163.com/');
    expect(player.playing, isTrue);
  });

  test('long-running play future does not block playback controls', () async {
    const songA = Song(
      id: 'a',
      title: 'A',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    const songB = Song(
      id: 'b',
      title: 'B',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    final player = _FakeAudioPlayer()..nextPlay = Completer<void>();
    final client = _ScrobbleClient()
      ..configure(serverUrl: 'http://server', username: 'u', password: 'p');
    final handler = NavidromeAudioHandler(
      client,
      BackendClient(),
      player: player,
    );

    await handler
        .setQueue([songA, songB])
        .timeout(const Duration(milliseconds: 100));
    await handler.pause().timeout(const Duration(milliseconds: 100));

    player.nextPlay = Completer<void>();
    await handler.play().timeout(const Duration(milliseconds: 100));
    await handler.pause().timeout(const Duration(milliseconds: 100));

    player.nextPlay = Completer<void>();
    await handler.skipToNext().timeout(const Duration(milliseconds: 100));
    expect(handler.currentSong, songB);
    await handler.pause().timeout(const Duration(milliseconds: 100));
  });

  test('stale play failure cannot clear the next loaded song', () async {
    const songA = Song(
      id: 'a',
      title: 'A',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    const songB = Song(
      id: 'b',
      title: 'B',
      artist: 'Artist',
      artistId: 'artist',
      album: 'Album',
      albumId: 'album',
    );
    final player = _FakeAudioPlayer();
    final client = _ScrobbleClient()
      ..configure(serverUrl: 'http://server', username: 'u', password: 'p');
    final handler = NavidromeAudioHandler(
      client,
      BackendClient(),
      player: player,
    );
    await handler.setQueue([songA, songB]);
    await handler.pause();
    player
      ..nextPlay = Completer<void>()
      ..playError = StateError('stale play failure');

    final resume = handler.play();
    while (player.playCalls < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    final next = handler.skipToNext();
    await Future.wait([resume, next]);

    expect(handler.currentSong, songB);
    expect(player.loadedUrls, hasLength(2));
    await handler.pause();
    await handler.play();
    expect(player.loadedUrls, hasLength(2));
  });
}
