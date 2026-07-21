import 'dart:async';

import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/player/playback_origin.dart';

typedef RecommendationFeedbackHandler =
    FutureOr<void> Function(
      PlaybackOrigin origin,
      RecommendationFeedbackEvent event,
    );

/// Observes playback only. Never controls the player.
class RecommendationPlaybackTracker {
  RecommendationPlaybackTracker({
    required AudioPlayerService player,
    required RecommendationFeedbackHandler onFeedback,
  }) : _player = player,
       _onFeedback = onFeedback {
    _subs.add(_player.currentSongStream.listen(_onSong));
    _subs.add(_player.currentPlaybackOriginStream.listen(_onOrigin));
    _subs.add(_player.positionStream.listen(_onPosition));
    _subs.add(_player.durationStream.listen(_onDuration));
    _subs.add(_player.playingStream.listen((playing) => _playing = playing));
    _subs.add(_player.playbackFailureStream.listen(_onFailure));
  }

  final AudioPlayerService _player;
  final RecommendationFeedbackHandler _onFeedback;
  final List<StreamSubscription<dynamic>> _subs = [];

  Song? _song;
  PlaybackOrigin? _origin;
  Duration? _duration;
  bool _playing = false;
  bool _playedSent = false;
  bool _completedSent = false;
  bool _unavailableSent = false;

  void _resetImpression() {
    _playedSent = false;
    _completedSent = false;
    _unavailableSent = false;
  }

  void _onSong(Song? song) {
    if (song?.storageKey != _song?.storageKey) {
      _song = song;
      _resetImpression();
    } else {
      _song = song;
    }
  }

  void _onOrigin(PlaybackOrigin? origin) {
    if (origin != _origin) {
      _origin = origin;
      _resetImpression();
    }
  }

  void _onDuration(Duration? duration) {
    _duration = duration;
  }

  void _onPosition(Duration position) {
    final origin = _origin;
    final song = _song;
    if (!_playing || origin == null || song == null) return;
    if (_player.currentPlaybackOrigin != origin) return;
    if (_player.currentSong?.storageKey != song.storageKey) return;

    final total = _duration;
    final ratio = (total != null && total.inMilliseconds > 0)
        ? position.inMilliseconds / total.inMilliseconds
        : 0.0;

    if (!_playedSent && (position.inSeconds >= 30 || ratio >= 0.25)) {
      _playedSent = true;
      unawaited(
        Future.sync(
          () => _onFeedback(origin, RecommendationFeedbackEvent.played),
        ),
      );
    }
    if (!_completedSent && ratio >= 0.90) {
      _completedSent = true;
      unawaited(
        Future.sync(
          () => _onFeedback(origin, RecommendationFeedbackEvent.completed),
        ),
      );
    }
  }

  void _onFailure(PlaybackFailure failure) {
    final origin = failure.origin;
    if (origin == null || failure.retryable || _unavailableSent) return;
    if (_origin != origin) return;
    if (_song?.storageKey != failure.songStorageKey &&
        _player.currentSong?.storageKey != failure.songStorageKey) {
      return;
    }
    _unavailableSent = true;
    unawaited(
      Future.sync(
        () => _onFeedback(origin, RecommendationFeedbackEvent.unavailable),
      ),
    );
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}
