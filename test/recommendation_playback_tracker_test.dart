import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/player/playback_origin.dart';
import 'package:navidrome_player/services/recommendation_playback_tracker.dart';

class _FakePlayer implements AudioPlayerService {
  _FakePlayer();

  final songController = StreamController<Song?>.broadcast();
  final originController = StreamController<PlaybackOrigin?>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration?>.broadcast();
  final playingController = StreamController<bool>.broadcast();
  final failureController = StreamController<PlaybackFailure>.broadcast();

  Song? _song;
  PlaybackOrigin? _origin;

  @override
  Song? get currentSong => _song;
  @override
  PlaybackOrigin? get currentPlaybackOrigin => _origin;
  @override
  Stream<Song?> get currentSongStream => songController.stream;
  @override
  Stream<PlaybackOrigin?> get currentPlaybackOriginStream =>
      originController.stream;
  @override
  Stream<Duration> get positionStream => positionController.stream;
  @override
  Stream<Duration?> get durationStream => durationController.stream;
  @override
  Stream<bool> get playingStream => playingController.stream;
  @override
  Stream<PlaybackFailure> get playbackFailureStream => failureController.stream;

  // Unused members
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const song = Song(
    id: '1',
    title: 'T',
    album: 'A',
    albumId: 'a',
    artist: 'R',
    artistId: 'r',
    backend: SongBackend.solara,
    onlineSource: 'netease',
    urlId: 'u1',
  );
  const origin = PlaybackOrigin(
    sessionId: 's',
    candidateId: 'c1',
    impressionId: 'i1',
  );

  test(
    'emits played/completed thresholds once and ignores null origin',
    () async {
      final player = _FakePlayer();
      final events = <RecommendationFeedbackEvent>[];
      final tracker = RecommendationPlaybackTracker(
        player: player,
        onFeedback: (o, e) => events.add(e),
      );

      player._song = song;
      player.songController.add(song);
      player._origin = origin;
      player.originController.add(origin);
      player.durationController.add(const Duration(seconds: 100));
      player.playingController.add(true);

      player.positionController.add(const Duration(seconds: 10));
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      player.positionController.add(const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);
      expect(events, [RecommendationFeedbackEvent.played]);

      player.positionController.add(const Duration(seconds: 40));
      await Future<void>.delayed(Duration.zero);
      expect(events, [RecommendationFeedbackEvent.played]);

      player.positionController.add(const Duration(seconds: 90));
      await Future<void>.delayed(Duration.zero);
      expect(events, [
        RecommendationFeedbackEvent.played,
        RecommendationFeedbackEvent.completed,
      ]);

      // null origin should not emit
      player._origin = null;
      player.originController.add(null);
      player.positionController.add(const Duration(seconds: 95));
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(2));

      await tracker.dispose();
    },
  );

  test('maps only non-retryable origin failure to unavailable', () async {
    final player = _FakePlayer();
    final events = <RecommendationFeedbackEvent>[];
    final tracker = RecommendationPlaybackTracker(
      player: player,
      onFeedback: (o, e) => events.add(e),
    );
    player._song = song;
    player._origin = origin;
    player.songController.add(song);
    player.originController.add(origin);

    player.failureController.add(
      const PlaybackFailure(
        serverId: 'a',
        songStorageKey: 'solara:netease:u1',
        requestGeneration: 1,
        kind: PlaybackFailureKind.network,
        retryable: true,
        origin: origin,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    player.failureController.add(
      const PlaybackFailure(
        serverId: 'a',
        songStorageKey: 'solara:netease:u1',
        requestGeneration: 2,
        kind: PlaybackFailureKind.sourceUnavailable,
        retryable: false,
        origin: origin,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, [RecommendationFeedbackEvent.unavailable]);

    await tracker.dispose();
  });
}
