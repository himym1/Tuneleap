import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/library_audit.dart';
import 'package:navidrome_player/providers/library_audit_provider.dart';
import 'package:navidrome_player/providers/server_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.onFetch);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  )
  onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('parses audit snapshot and findings without host paths', () {
    final snapshot = LibraryAuditSnapshot.fromJson({
      'active': false,
      'stage': 'completed',
      'scanned': 6,
      'total': 6,
      'summary': {
        'scanned': 6,
        'passed': 1,
        'issues': 5,
        'missing': 1,
        'low_bitrate': 1,
        'suspect_transcode': 1,
        'duplicate_version': 2,
      },
    });
    expect(snapshot.hasResult, isTrue);
    expect(snapshot.summary.issues, 5);

    final finding = LibraryAuditFinding.fromJson({
      'song_id': 'low',
      'title': '低码率',
      'artist': '歌手',
      'album': '专辑',
      'suffix': 'mp3',
      'bit_rate': 128,
      'duration': 200,
      'codes': ['low_bitrate'],
      'severity': 'warn',
      'path': '/music/secret.mp3',
    });
    expect(finding.songId, 'low');
    expect(finding.searchQuery(), '低码率 歌手');
    expect(finding.toSong().id, 'low');
    expect(finding.toSong().isOnline, isFalse);
    expect(
      LibraryAuditFinding.fromJson({
        'song_id': 'broken',
        'codes': ['deep_failed'],
        'deep_error': 'invalid_sample_rate',
      }).deepError,
      'invalid_sample_rate',
    );
    expect(
      LibraryAuditFinding.fromJson({
        'song_id': 'a1',
        'album_id': 'album-9',
        'codes': ['missing'],
      }).toSong().albumId,
      'album-9',
    );
    expect(
      LibraryAuditRules.clamped(
        lowBitrateKbps: 10,
        suspectLosslessKbps: 900,
        durationToleranceSeconds: 99,
      ).toJson(),
      {
        'low_bitrate_kbps': 64,
        'suspect_lossless_kbps': 800,
        'duration_tolerance_seconds': 15,
      },
    );
    expect(
      LibraryAuditSnapshot.fromJson({
        'active': true,
        'stage': 'deep_scanning',
        'scanned': 1,
        'total': 4,
      }).isDeepScanning,
      isTrue,
    );

    final lossy = LibraryAuditFinding.fromJson({
      'song_id': 'lossy',
      'codes': ['lossy_transcode', 'duplicate_version'],
    });
    final versionOnly = LibraryAuditFinding.fromJson({
      'song_id': 'ok',
      'codes': ['duplicate_version'],
      'cutoff_hz': 20570,
    });
    expect(lossy.hasQualityIssue, isTrue);
    expect(lossy.isVersionOnly, isFalse);
    expect(versionOnly.hasQualityIssue, isFalse);
    expect(versionOnly.isVersionOnly, isTrue);

    final grouped = LibraryAuditState(
      findings: [lossy, versionOnly],
    );
    expect(grouped.qualityIssueCount, 1);
    expect(grouped.versionOnlyCount, 1);
    expect(grouped.qualityFindings.single.songId, 'lossy');
    expect(grouped.versionOnlyFindings.single.songId, 'ok');
    expect(grouped.showGroupedFindings, isTrue);
  });

  test('library audit always uses the NAS agent, not Cloud', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
        captured = options;
        return _jsonBody({
          'active': true,
          'stage': 'scanning',
          'scanned': 0,
          'total': 0,
        }, statusCode: 202);
      });
    final client = BackendClient(dio: dio)
      ..configure(
        cloudBaseUrl: 'http://cloud:8600',
        nasAgentUrl: 'http://192.168.1.10:8504',
        nasAgentKey: 'nas-key',
      );

    expect(client.canAuditLibrary, isTrue);
    final snapshot = await client.startLibraryAudit(
      rules: const LibraryAuditRules(lowBitrateKbps: 256),
    );
    expect(captured.path, 'http://192.168.1.10:8504/v1/nas/library-audit');
    expect(captured.method, 'POST');
    expect(captured.headers['X-API-Key'], 'nas-key');
    expect(captured.data, {
      'low_bitrate_kbps': 256,
      'suspect_lossless_kbps': 500,
      'duration_tolerance_seconds': 3,
    });
    expect(snapshot.isScanning, isTrue);
  });

  test('library audit deep scan posts to the NAS agent', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
        captured = options;
        return _jsonBody({
          'active': true,
          'stage': 'deep_scanning',
          'scanned': 0,
          'total': 2,
        }, statusCode: 202);
      });
    final client = BackendClient(dio: dio)
      ..configure(
        cloudBaseUrl: 'http://cloud:8600',
        nasAgentUrl: 'http://192.168.1.10:8504',
        nasAgentKey: 'nas-key',
      );

    final snapshot = await client.startLibraryAuditDeep();
    expect(
      captured.path,
      'http://192.168.1.10:8504/v1/nas/library-audit/deep',
    );
    expect(captured.method, 'POST');
    expect(snapshot.isDeepScanning, isTrue);
  });

  test('library audit is unavailable without a direct NAS agent', () {
    final client = BackendClient(dio: Dio())
      ..configure(cloudBaseUrl: 'https://cloud.example.com');
    expect(client.canMutateNas, isTrue);
    expect(client.canAuditLibrary, isFalse);
    expect(client.getLibraryAudit, throwsStateError);
  });

  test('busy audit start reads the existing snapshot', () async {
    var posts = 0;
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
        if (options.method == 'POST') {
          posts += 1;
          return _jsonBody({
            'detail': 'library audit already running',
          }, statusCode: 409);
        }
        return _jsonBody({
          'active': true,
          'stage': 'scanning',
          'scanned': 3,
          'total': 10,
        });
      });
    final client = BackendClient(dio: dio)
      ..configure(
        nasAgentUrl: 'http://192.168.1.10:8504',
        nasAgentKey: 'nas-key',
      );

    final snapshot = await client.startLibraryAudit();
    expect(posts, 1);
    expect(snapshot.scanned, 3);
    expect(snapshot.total, 10);
  });

  test('findings pages until the reported total', () async {
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((options, _, _) async {
        final offset = int.parse('${options.queryParameters['offset']}');
        if (offset == 0) {
          return _jsonBody({
            'items': [
              {
                'song_id': 'a',
                'codes': ['missing'],
              },
            ],
            'offset': 0,
            'limit': 1,
            'total': 2,
          });
        }
        return _jsonBody({
          'items': [
            {
              'song_id': 'b',
              'codes': ['low_bitrate'],
            },
          ],
          'offset': 1,
          'limit': 1,
          'total': 2,
        });
      });
    final client = BackendClient(dio: dio)
      ..configure(
        nasAgentUrl: 'http://192.168.1.10:8504',
        nasAgentKey: 'nas-key',
      );

    final items = await client.getLibraryAuditFindings();
    expect(items.map((item) => item.songId), ['a', 'b']);
  });

  test(
    'replace session queues the next song after the current import',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        libraryAuditReplaceTargetProvider.notifier,
      );
      notifier.setQueue([
        const LibraryAuditReplaceTarget(
          songId: 'a',
          title: '第一首',
          artist: '歌手',
        ),
        const LibraryAuditReplaceTarget(
          songId: 'b',
          title: '第二首',
          artist: '歌手',
        ),
      ]);
      expect(
        container.read(libraryAuditReplaceTargetProvider)?.current.songId,
        'a',
      );
      expect(container.read(libraryAuditReplaceTargetProvider)?.total, 2);
      expect(notifier.completeCurrent()?.songId, 'b');
      expect(notifier.completeCurrent(), isNull);
      expect(container.read(libraryAuditReplaceTargetProvider), isNull);
    },
  );

  test('audit rules persist in SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(libraryAuditRulesProvider).lowBitrateKbps,
      LibraryAuditRules.defaultLowBitrateKbps,
    );
    await container
        .read(libraryAuditRulesProvider.notifier)
        .update(lowBitrateKbps: 192, durationToleranceSeconds: 8);
    expect(container.read(libraryAuditRulesProvider).lowBitrateKbps, 192);
    expect(prefs.getInt(libraryAuditLowBitratePrefKey), 192);
    expect(prefs.getInt(libraryAuditDurationTolerancePrefKey), 8);
  });
}
