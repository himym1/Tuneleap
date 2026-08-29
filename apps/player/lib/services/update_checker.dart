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
            : Platform.isWindows
            ? 'windows'
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

String updatePackageExtension({String? platform}) {
  final key =
      platform ??
      (Platform.isAndroid
          ? 'android'
          : Platform.isWindows
          ? 'windows'
          : 'macos');
  return switch (key) {
    'android' => 'apk',
    'windows' => 'zip',
    _ => 'dmg',
  };
}

Future<String> defaultUpdateSavePath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/app_update.${updatePackageExtension()}';
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

class UpdateInstallOutcome {
  const UpdateInstallOutcome({
    required this.ok,
    this.manualDesktopHint = false,
  });

  final bool ok;
  final bool manualDesktopHint;
}

Future<UpdateInstallOutcome> installUpdate(String filePath) async {
  if (Platform.isAndroid) {
    return UpdateInstallOutcome(ok: await _installAndroid(filePath));
  }
  if (Platform.isMacOS) return _installMacOS(filePath);
  if (Platform.isWindows) {
    if (await _applyWindowsZipUpdate(filePath)) {
      // Successful path terminates the process after launching the updater.
      return const UpdateInstallOutcome(ok: true);
    }
    try {
      await Process.start('explorer.exe', [filePath]);
      return const UpdateInstallOutcome(ok: true, manualDesktopHint: true);
    } catch (error) {
      debugPrint('Open Windows update zip failed: ${error.runtimeType}');
      return const UpdateInstallOutcome(ok: false);
    }
  }
  return const UpdateInstallOutcome(ok: false);
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

bool _windowsPayloadHasExe(String dir) {
  return File('$dir\\Tuneleap.exe').existsSync() ||
      File('$dir\\navidrome_player.exe').existsSync();
}

/// Extract the release zip beside the running exe via a detached cmd script
/// that waits for this process to exit, then relaunches.
///
/// Returns by terminating the process after starting the updater on success.
Future<bool> _applyWindowsZipUpdate(String zipPath) async {
  if (!Platform.isWindows) return false;
  final exePath = Platform.resolvedExecutable;
  final appDir = File(exePath).parent.path;
  final stagingRoot = Directory(
    '${Directory.systemTemp.path}\\tuneleap_update_staging',
  );
  final batPath = '${Directory.systemTemp.path}\\tuneleap_apply_update.bat';

  try {
    if (stagingRoot.existsSync()) {
      stagingRoot.deleteSync(recursive: true);
    }
    stagingRoot.createSync(recursive: true);

    final expand = await Process.run('powershell.exe', [
      '-NoProfile',
      '-Command',
      "Expand-Archive -LiteralPath '${zipPath.replaceAll("'", "''")}' "
          "-DestinationPath '${stagingRoot.path.replaceAll("'", "''")}' -Force",
    ]);
    if (expand.exitCode != 0) {
      debugPrint('Expand Windows update failed: ${expand.stderr}');
      return false;
    }

    var payloadDir = stagingRoot.path;
    final nested = Directory('${stagingRoot.path}\\Release');
    if (nested.existsSync()) {
      payloadDir = nested.path;
    } else {
      final children = stagingRoot.listSync().whereType<Directory>().toList();
      if (children.length == 1 &&
          _windowsPayloadHasExe(children.single.path)) {
        payloadDir = children.single.path;
      }
    }

    final exeName = File(exePath).uri.pathSegments.isNotEmpty
        ? File(exePath).uri.pathSegments.last
        : 'Tuneleap.exe';
    final bat = StringBuffer()
      ..writeln('@echo off')
      ..writeln('set "APPDIR=$appDir"')
      ..writeln('set "STAGE=$payloadDir"')
      ..writeln('set "EXE=$exePath"')
      ..writeln('set "ROOT=${stagingRoot.path}"')
      ..writeln(':wait')
      ..writeln('timeout /t 1 /nobreak >nul')
      ..writeln(
        'tasklist /FI "IMAGENAME eq $exeName" 2>nul | '
        'find /I "$exeName" >nul',
      )
      ..writeln('if not errorlevel 1 goto wait')
      ..writeln('xcopy /E /Y /Q "%STAGE%\\*" "%APPDIR%\\" >nul')
      // New packages ship Tuneleap.exe; older installs still run
      // navidrome_player.exe. Prefer the branded binary after copy.
      ..writeln('set "LAUNCH=%APPDIR%\\Tuneleap.exe"')
      ..writeln('if not exist "%LAUNCH%" set "LAUNCH=%EXE%"')
      ..writeln(
        'if exist "%APPDIR%\\Tuneleap.exe" if exist '
        '"%APPDIR%\\navidrome_player.exe" del '
        '"%APPDIR%\\navidrome_player.exe"',
      )
      ..writeln('start "" "%LAUNCH%"')
      ..writeln('rmdir /S /Q "%ROOT%"')
      ..writeln('del "%~f0"');
    await File(batPath).writeAsString(bat.toString());

    await Process.start('cmd.exe', [
      '/c',
      batPath,
    ], mode: ProcessStartMode.detached);
    // Free file locks so the updater can overwrite the running binary.
    exit(0);
  } catch (error) {
    debugPrint('Apply Windows update failed: ${error.runtimeType}');
    return false;
  }
}

const _macVolumeName = '音跃';
const _macAppName = '音跃';

@visibleForTesting
String macMountedAppPath({
  String volumeName = _macVolumeName,
  String appName = _macAppName,
}) => '/Volumes/$volumeName/$appName.app';

@visibleForTesting
String macInstalledAppPath({String appName = _macAppName}) =>
    '/Applications/$appName.app';

@visibleForTesting
Future<String?> waitForMountedMacApp({
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 250),
  bool Function(String path)? exists,
}) async {
  final path = macMountedAppPath();
  final present = exists ?? (candidate) => Directory(candidate).existsSync();
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (present(path)) return path;
    await Future<void>.delayed(interval);
  }
  return present(path) ? path : null;
}

String _finderReplaceScript({
  required String sourceApp,
  required String destinationApp,
  required String destinationFolder,
  required String volumeName,
}) {
  String quote(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return '''
set srcPath to "${quote(sourceApp)}"
set dstApp to "${quote(destinationApp)}"
set dstFolder to "${quote(destinationFolder)}"
tell application "Finder"
  if exists POSIX file dstApp then
    delete POSIX file dstApp
  end if
  duplicate (POSIX file srcPath as alias) to (POSIX file dstFolder as alias)
  try
    eject disk "${quote(volumeName)}"
  end try
end tell
''';
}

Future<bool> _replaceMacAppViaFinder(String sourceApp) async {
  final result = await Process.run('osascript', [
    '-e',
    _finderReplaceScript(
      sourceApp: sourceApp,
      destinationApp: macInstalledAppPath(),
      destinationFolder: '/Applications',
      volumeName: _macVolumeName,
    ),
  ]);
  if (result.exitCode != 0) {
    debugPrint('Finder replace failed: exit=${result.exitCode}');
    return false;
  }
  return Directory(macInstalledAppPath()).existsSync();
}

Future<UpdateInstallOutcome> _installMacOS(String dmgPath) async {
  try {
    // Sandbox blocks hdiutil attach ("Device not configured"). Finder can
    // mount the DMG and copy into /Applications.
    await Process.run('xattr', ['-cr', dmgPath]);
    final opened = await Process.run('open', [dmgPath]);
    if (opened.exitCode != 0) {
      debugPrint('Open DMG failed: exit=${opened.exitCode}');
      return const UpdateInstallOutcome(ok: false);
    }

    final mounted = await waitForMountedMacApp();
    if (mounted != null && await _replaceMacAppViaFinder(mounted)) {
      await Process.run('open', ['-n', macInstalledAppPath()]);
      exit(0);
    }
    return const UpdateInstallOutcome(ok: true, manualDesktopHint: true);
  } catch (error) {
    debugPrint('Install DMG failed: ${error.runtimeType}');
    return const UpdateInstallOutcome(ok: false);
  }
}
