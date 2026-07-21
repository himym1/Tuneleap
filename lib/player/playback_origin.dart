/// Recommendation-only playback attribution. Never serialized into Song.
class PlaybackOrigin {
  const PlaybackOrigin({
    required this.sessionId,
    required this.candidateId,
    required this.impressionId,
  });

  final String sessionId;
  final String candidateId;
  final String impressionId;

  @override
  bool operator ==(Object other) {
    return other is PlaybackOrigin &&
        other.sessionId == sessionId &&
        other.candidateId == candidateId &&
        other.impressionId == impressionId;
  }

  @override
  int get hashCode => Object.hash(sessionId, candidateId, impressionId);
}

enum PlaybackFailureKind { sourceUnavailable, network, timeout, unknown }

/// Sanitized playback failure. Never contains URL, credentials, or exception text.
class PlaybackFailure {
  const PlaybackFailure({
    required this.serverId,
    required this.songStorageKey,
    required this.requestGeneration,
    required this.kind,
    required this.retryable,
    this.origin,
  });

  final String serverId;
  final String songStorageKey;
  final int requestGeneration;
  final PlaybackFailureKind kind;
  final bool retryable;
  final PlaybackOrigin? origin;

  @override
  String toString() =>
      'PlaybackFailure(serverId: $serverId, songStorageKey: $songStorageKey, '
      'requestGeneration: $requestGeneration, kind: $kind, retryable: $retryable, '
      'hasOrigin: ${origin != null})';
}
