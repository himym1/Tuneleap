import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/services/update_checker.dart';

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.onFetch);

  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => onFetch(options);

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _metadata({String host = 'player.himym.sbs'}) => {
  'android': {
    'version': '1.0.5',
    'build': 3,
    'url': 'https://$host/releases/navidrome_player-1.0.5+3-android.apk',
    'sha256': List.filled(64, 'a').join(),
  },
  'macos': {
    'version': '1.0.8',
    'build': 3,
    'url': 'https://$host/releases/navidrome_player-1.0.8+3-macos.dmg',
    'sha256': List.filled(64, 'b').join(),
  },
};

void main() {
  test('platform metadata requires trusted private release URL', () {
    final android = AppUpdateInfo.fromJson(_metadata(), platform: 'android');

    expect(android.version, '1.0.5');
    expect(android.build, 3);
    expect(android.sha256, List.filled(64, 'a').join());
    expect(
      () => AppUpdateInfo.fromJson(
        _metadata(host: 'downloads.example.com'),
        platform: 'android',
      ),
      throwsFormatException,
    );
  });

  test('version comparison uses build when semantic versions are equal', () {
    expect(
      isNewerVersion('1.0.5', '1.0.5', remoteBuild: 3, localBuild: 2),
      isTrue,
    );
    expect(
      isNewerVersion('1.0.5', '1.0.5', remoteBuild: 2, localBuild: 2),
      isFalse,
    );
    expect(
      isNewerVersion('1.0.4', '1.0.5', remoteBuild: 99, localBuild: 1),
      isFalse,
    );
  });

  test(
    'update metadata request is authenticated and does not redirect',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options) async {
          expect(
            options.uri.toString(),
            'https://player.himym.sbs/version.json',
          );
          expect(options.headers['X-API-Key'], 'private-key');
          expect(options.followRedirects, isFalse);
          return ResponseBody.fromString(
            jsonEncode(_metadata()),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

      final info = await checkForUpdate(apiKey: 'private-key', dio: dio);

      expect(info, isNotNull);
    },
  );

  test(
    'artifact download is authenticated, non-redirecting, and verified',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'update-download-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final destination = '${directory.path}/release.apk';
      final bytes = utf8.encode('private release');
      final checksum = sha256.convert(bytes).toString();
      final dio = Dio()
        ..httpClientAdapter = _CaptureAdapter((options) async {
          expect(options.uri.host, 'player.himym.sbs');
          expect(options.headers['X-API-Key'], 'private-key');
          expect(options.followRedirects, isFalse);
          return ResponseBody.fromBytes(
            bytes,
            200,
            headers: {
              Headers.contentLengthHeader: ['${bytes.length}'],
            },
          );
        });
      final info = AppUpdateInfo(
        version: '1.0.5',
        build: 3,
        url:
            'https://player.himym.sbs/releases/navidrome_player-1.0.5+3-android.apk',
        sha256: checksum,
      );

      final path = await downloadUpdate(
        info,
        apiKey: 'private-key',
        dio: dio,
        savePathOverride: destination,
      );

      expect(path, destination);
      expect(await File(destination).readAsBytes(), bytes);
    },
  );

  test('bad artifact checksum deletes the downloaded file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'update-bad-hash-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final destination = '${directory.path}/release.apk';
    final dio = Dio()
      ..httpClientAdapter = _CaptureAdapter((_) async {
        return ResponseBody.fromBytes(utf8.encode('tampered'), 200);
      });
    final info = AppUpdateInfo(
      version: '1.0.5',
      build: 3,
      url:
          'https://player.himym.sbs/releases/navidrome_player-1.0.5+3-android.apk',
      sha256: List.filled(64, '0').join(),
    );

    final path = await downloadUpdate(
      info,
      apiKey: 'private-key',
      dio: dio,
      savePathOverride: destination,
    );

    expect(path, isNull);
    expect(await File(destination).exists(), isFalse);
  });

  test('downloaded file SHA256 is verified', () async {
    final directory = await Directory.systemTemp.createTemp('update-hash-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/release.bin');
    await file.writeAsString('private release');
    final expected = sha256.convert(utf8.encode('private release')).toString();

    expect(await verifyFileSha256(file.path, expected), isTrue);
    expect(
      await verifyFileSha256(file.path, List.filled(64, '0').join()),
      isFalse,
    );
  });
}
