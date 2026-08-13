import 'dart:convert';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/models/models.dart';

void main() {
  test('parses ai and fallback fixture pages', () async {
    final raw = await File(
      'test/fixtures/recommendation_page.v1.json',
    ).readAsString();
    final fixture = jsonDecode(raw) as Map<String, dynamic>;

    final ai = RecommendationPage.fromJson(
      Map<String, dynamic>.from(fixture['ai'] as Map),
    );
    final fallback = RecommendationPage.fromJson(
      Map<String, dynamic>.from(fixture['fallback'] as Map),
    );

    expect(ai.mode, RecommendationMode.ai);
    expect(ai.sessionId, 'session-ai-001');
    expect(ai.items, hasLength(2));
    expect(ai.items.first.type, RecommendationType.similar);
    expect(ai.items.first.song.isOnline, isTrue);
    expect(ai.items.first.song.onlineSource, 'netease');
    expect(ai.items.first.song.urlId, 'netease-url-001');
    expect(ai.nextCursor, 'cursor-ai-002');
    expect(ai.hasMore, isTrue);
    expect(fallback.mode, RecommendationMode.fallback);
    expect(fallback.nextCursor, isNull);
    expect(fallback.hasMore, isFalse);
  });

  test('rejects unsupported contract versions', () {
    expect(
      () => RecommendationPage.fromJson({'contractVersion': 2}),
      throwsA(
        isA<RecommendationApiException>()
            .having(
              (error) => error.code,
              'code',
              'recommendation_unsupported_contract',
            )
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('rejects recommendation songs without online source and url id', () {
    expect(
      () => RecommendationItem.fromJson({
        'candidateId': 'candidate',
        'recommendationType': 'explore',
        'song': {
          'id': 'local-id',
          'title': 'Local',
          'album': '',
          'albumId': '',
          'artist': '',
          'artistId': '',
        },
      }),
      throwsFormatException,
    );
  });

  test('recent summary maps local and online source ids', () {
    const local = Song(
      id: 'local-1',
      title: 'Local Track',
      album: 'Album',
      albumId: 'a',
      artist: 'Artist',
      artistId: 'ar',
    );
    const online = Song(
      id: 'online-1',
      title: 'Online Track',
      album: 'Album',
      albumId: 'a',
      artist: 'Artist',
      artistId: 'ar',
      backend: SongBackend.solara,
      onlineSource: 'netease',
      urlId: 'url-1',
    );

    final localSummary = RecentRecommendationSongSummary.fromSong(local);
    final onlineSummary = RecentRecommendationSongSummary.fromSong(online);

    expect(localSummary.toJson(), {
      'title': 'Local Track',
      'artist': 'Artist',
      'album': 'Album',
      'source': 'subsonic',
      'sourceId': 'local-1',
    });
    expect(onlineSummary.toJson(), {
      'title': 'Online Track',
      'artist': 'Artist',
      'album': 'Album',
      'source': 'netease',
      'sourceId': 'url-1',
    });
  });

  test('feedback response requires contract and booleans', () {
    final response = RecommendationFeedbackResponse.fromJson({
      'contractVersion': 1,
      'accepted': true,
      'duplicate': false,
    });
    expect(response.accepted, isTrue);
    expect(response.duplicate, isFalse);
    expect(
      () => RecommendationFeedbackResponse.fromJson({
        'contractVersion': 1,
        'accepted': true,
      }),
      throwsFormatException,
    );
  });

  test('exception toString omits detail payload', () {
    const error = RecommendationApiException(
      code: 'recommendation_invalid_request',
      detail: 'secret detail payload',
      retryable: false,
      statusCode: 400,
    );
    expect(error.toString(), contains('recommendation_invalid_request'));
    expect(error.toString(), isNot(contains('secret detail payload')));
  });

  test('rejects unknown enums and cursor invariants', () {
    expect(
      () => RecommendationPage.fromJson({
        'contractVersion': 1,
        'sessionId': 's',
        'mode': 'mystery',
        'items': <Object>[],
        'nextCursor': null,
        'hasMore': false,
      }),
      throwsFormatException,
    );
    expect(
      () => RecommendationPage.fromJson({
        'contractVersion': 1,
        'sessionId': 's',
        'mode': 'ai',
        'items': ['bad'],
        'nextCursor': null,
        'hasMore': false,
      }),
      throwsFormatException,
    );
    expect(
      () => RecommendationPage.fromJson({
        'contractVersion': 1,
        'sessionId': 's',
        'mode': 'ai',
        'items': <Object>[],
        'nextCursor': null,
        'hasMore': true,
      }),
      throwsFormatException,
    );
    expect(
      () => RecommendationPage.fromJson({
        'contractVersion': 1,
        'sessionId': 's',
        'mode': 'ai',
        'items': <Object>[],
        'nextCursor': 'cursor',
        'hasMore': false,
      }),
      throwsFormatException,
    );
  });
}
