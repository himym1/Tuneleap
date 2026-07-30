import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

const _legacyUpdateOrigin = 'https://player.himym.us.ci';
typedef UpdateAccessTokenProvider =
    Future<String?> Function({bool forceRefresh});

String _normalizeUpdateOrigin(String? value) {
  final raw = value?.trim() ?? '';
  final origin = raw.isEmpty ? _legacyUpdateOrigin : raw;
  return origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
}

Uri _trustedUpdateOrigin(String value) {
  final uri = Uri.tryParse(_normalizeUpdateOrigin(value));
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException('Invalid update origin');
  }
  return uri;
}

class AppUpdateInfo {
  final String version;
  final int build;
  final String url;
  final String sha256;
  final String? changelog;
  final String trustedOrigin;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.url,
    required this.sha256,
    this.changelog,
    this.trustedOrigin = _legacyUpdateOrigin,
  });

  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    String? platform,
    String trustedOrigin = _legacyUpdateOrigin,
  }) {
    final platformKey =
        platform ??
        (Platform.isAndroid
            ? 'android'
            : Platform.isMacOS
            ? 'macos'
            : null);
    final platformInfo = platformKey == null ? null : json[platformKey];
    if (platformInfo is! Map) {
      throw const FormatException('Missing platform update metadata');
    }
    final info = Map<String, dynamic>.from(platformInfo);
    final version = info['version'];
    final build = info['build'];
    final url = info['url'];
    final checksum = info['sha256'];
    if (version is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        build is! int ||
        build < 1 ||
        url is! String ||
        checksum is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum)) {
      throw const FormatException('Invalid platform update metadata');
    }
    final normalizedOrigin = _normalizeUpdateOrigin(trustedOrigin);
    _validatePrivateDownloadUrl(url, normalizedOrigin);
    return AppUpdateInfo(
      version: version,
      build: build,
      url: url,
      sha256: checksum.toLowerCase(),
      changelog: json['changelog'] as String?,
      trustedOrigin: normalizedOrigin,
    );
  }
}

void _validatePrivateDownloadUrl(String value, String trustedOrigin) {
  final uri = Uri.tryParse(value);
  final trusted = _trustedUpdateOrigin(trustedOrigin);
  if (uri == null ||
      uri.scheme != trusted.scheme ||
      uri.host != trusted.host ||
      uri.port != trusted.port ||
      !uri.path.startsWith('/releases/')) {
    throw const FormatException('Untrusted update download URL');
  }
}

bool isNewerVersion(
  String remote,
  String local, {
  int remoteBuild = 0,
  int localBuild = 0,
}) {
  final r = _versionParts(remote);
  final l = _versionParts(local);
  for (int i = 0; i < 3; i++) {
    final rv = r[i];
    final lv = l[i];
    if (rv > lv) return true;
    if (rv < lv) return false;
  }
  return remoteBuild > localBuild;
}

List<int> _versionParts(String value) {
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
    throw const FormatException('Invalid semantic version');
  }
  return value.split('.').map(int.parse).toList(growable: false);
}

Future<AppUpdateInfo?> checkForUpdate({
  required UpdateAccessTokenProvider accessTokenProvider,
  String updateOrigin = '',
  Dio? dio,
}) async {
  try {
    final origin = _normalizeUpdateOrigin(updateOrigin);
    _trustedUpdateOrigin(origin);
    final client = dio ?? Dio();
    for (final forceRefresh in [false, true]) {
      final token = await accessTokenProvider(forceRefresh: forceRefresh);
      if (token == null || token.isEmpty) return null;
      final response = await client.get<dynamic>(
        '$origin/version.json',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          followRedirects: false,
          validateStatus: (status) => status == 200 || status == 401,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.statusCode == 401) continue;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AppUpdateInfo.fromJson(data, trustedOrigin: origin);
      }
      if (data is Map) {
        return AppUpdateInfo.fromJson(
          Map<String, dynamic>.from(data),
          trustedOrigin: origin,
        );
      }
      return null;
    }
  } catch (error) {
    debugPrint('Update check failed: ${error.runtimeType}');
  }
  return null;
}

Future<bool> verifyFileSha256(String path, String expected) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString() == expected.toLowerCase();
}

Future<String> defaultUpdateSavePath() async {
  final dir = await getTemporaryDirectory();
  final ext = Platform.isAndroid ? 'apk' : 'dmg';
  return '${dir.path}/app_update.$ext';
}

/// Returns a local path when a previously downloaded package still matches.
Future<String?> findCachedUpdate(AppUpdateInfo info, {String? savePath}) async {
  final path = savePath ?? await defaultUpdateSavePath();
  final file = File(path);
  if (!file.existsSync()) return null;
  if (!await verifyFileSha256(path, info.sha256)) {
    try {
      await file.delete();
    } catch (_) {}
    return null;
  }
  return path;
}

Future<String?> downloadUpdate(
  AppUpdateInfo info, {
  required UpdateAccessTokenProvider accessTokenProvider,
  void Function(double progress)? onProgress,
  Dio? dio,
  @visibleForTesting String? savePathOverride,
}) async {
  _validatePrivateDownloadUrl(info.url, info.trustedOrigin);
  final savePath = savePathOverride ?? await defaultUpdateSavePath();
  final file = File(savePath);

  final cached = await findCachedUpdate(info, savePath: savePath);
  if (cached != null) {
    onProgress?.call(1);
    return cached;
  }

  try {
    final client = dio ?? Dio();
    for (final forceRefresh in [false, true]) {
      final token = await accessTokenProvider(forceRefresh: forceRefresh);
      if (token == null || token.isEmpty) return null;
      if (file.existsSync()) file.deleteSync();
      final response = await client.download(
        info.url,
        savePath,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          followRedirects: false,
          validateStatus: (status) => status == 200 || status == 401,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
      if (response.statusCode == 401) continue;
      if (!await verifyFileSha256(savePath, info.sha256)) {
        await file.delete();
        return null;
      }
      onProgress?.call(1);
      return savePath;
    }
  } catch (error) {
    debugPrint('Download update failed: ${error.runtimeType}');
  }
  if (await file.exists()) await file.delete();
  return null;
}

Future<bool> installUpdate(String filePath) async {
  if (Platform.isAndroid) return _installAndroid(filePath);
  if (Platform.isMacOS) return _installMacOS(filePath);
  return false;
}

Future<bool> _installAndroid(String apkPath) async {
  try {
    final result = await OpenFilex.open(apkPath);
    return result.type == ResultType.done;
  } catch (error) {
    debugPrint('Install APK failed: ${error.runtimeType}');
    return false;
  }
}

Future<bool> _installMacOS(String dmgPath) async {
  try {
    // Downloaded DMGs get com.apple.quarantine; combined with adhoc/unsigned
    // builds this makes macOS report the app as damaged / not permitted.
    await Process.run('xattr', ['-cr', dmgPath]);
    final result = await Process.run('open', [dmgPath]);
    return result.exitCode == 0;
  } catch (error) {
    debugPrint('Open DMG failed: ${error.runtimeType}');
    return false;
  }
}
