import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

const _updateOrigin = 'https://player.himym.us.ci';
const _versionUrl = '$_updateOrigin/version.json';

class AppUpdateInfo {
  final String version;
  final int build;
  final String url;
  final String sha256;
  final String? changelog;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.url,
    required this.sha256,
    this.changelog,
  });

  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    String? platform,
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
    _validatePrivateDownloadUrl(url);
    return AppUpdateInfo(
      version: version,
      build: build,
      url: url,
      sha256: checksum.toLowerCase(),
      changelog: json['changelog'] as String?,
    );
  }
}

void _validatePrivateDownloadUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'player.himym.us.ci' ||
      uri.port != 443 ||
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
  required String apiKey,
  Dio? dio,
}) async {
  if (apiKey.isEmpty) return null;
  try {
    final client = dio ?? Dio();
    final response = await client.get<dynamic>(
      _versionUrl,
      options: Options(
        headers: {'X-API-Key': apiKey},
        followRedirects: false,
        validateStatus: (status) => status == 200,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return AppUpdateInfo.fromJson(data);
    if (data is Map) {
      return AppUpdateInfo.fromJson(Map<String, dynamic>.from(data));
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

Future<String?> downloadUpdate(
  AppUpdateInfo info, {
  required String apiKey,
  void Function(double progress)? onProgress,
  Dio? dio,
  @visibleForTesting String? savePathOverride,
}) async {
  if (apiKey.isEmpty) return null;
  _validatePrivateDownloadUrl(info.url);
  final savePath =
      savePathOverride ??
      '${(await getTemporaryDirectory()).path}/app_update.${Platform.isAndroid ? 'apk' : 'dmg'}';
  final file = File(savePath);
  try {
    if (file.existsSync()) file.deleteSync();
    final client = dio ?? Dio();
    await client.download(
      info.url,
      savePath,
      options: Options(
        headers: {'X-API-Key': apiKey},
        followRedirects: false,
        validateStatus: (status) => status == 200,
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
    if (!await verifyFileSha256(savePath, info.sha256)) {
      await file.delete();
      return null;
    }
    return savePath;
  } catch (error) {
    debugPrint('Download update failed: ${error.runtimeType}');
    if (await file.exists()) await file.delete();
    return null;
  }
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
    final result = await Process.run('open', [dmgPath]);
    return result.exitCode == 0;
  } catch (error) {
    debugPrint('Open DMG failed: ${error.runtimeType}');
    return false;
  }
}
