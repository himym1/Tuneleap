import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

const _versionUrl = 'https://player.himym.lat/version.json';

class AppUpdateInfo {
  final String version;
  final int build;
  final String? androidUrl;
  final String? macosUrl;
  final String? changelog;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    this.androidUrl,
    this.macosUrl,
    this.changelog,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    // 按平台读取版本，fallback 到顶层 version
    final platformKey = Platform.isAndroid ? 'android' : Platform.isMacOS ? 'macos' : null;
    final platformInfo = platformKey != null ? json[platformKey] : null;

    String version;
    int build;
    String? url;
    if (platformInfo is Map<String, dynamic>) {
      version = platformInfo['version'] as String? ?? json['version'] as String;
      build = platformInfo['build'] as int? ?? json['build'] as int? ?? 1;
      url = platformInfo['url'] as String?;
    } else {
      // 兼容旧格式：platform 值直接是 URL 字符串
      version = json['version'] as String;
      build = json['build'] as int? ?? 1;
      url = platformInfo as String?;
    }

    return AppUpdateInfo(
      version: version,
      build: build,
      androidUrl: Platform.isAndroid ? url : (json['android'] is String ? json['android'] as String : null),
      macosUrl: Platform.isMacOS ? url : (json['macos'] is String ? json['macos'] as String : null),
      changelog: json['changelog'] as String?,
    );
  }

  String? get downloadUrl {
    if (Platform.isAndroid) return androidUrl;
    if (Platform.isMacOS) return macosUrl;
    return null;
  }
}

/// 比较语义化版本号，返回 true 表示 remote 比 local 新
bool isNewerVersion(String remote, String local) {
  final r = remote.split('.').map(int.tryParse).toList();
  final l = local.split('.').map(int.tryParse).toList();
  for (int i = 0; i < 3; i++) {
    final rv = (i < r.length ? r[i] : 0) ?? 0;
    final lv = (i < l.length ? l[i] : 0) ?? 0;
    if (rv > lv) return true;
    if (rv < lv) return false;
  }
  return false;
}

/// 从服务器获取最新版本信息
Future<AppUpdateInfo?> checkForUpdate() async {
  try {
    final dio = Dio()..options.connectTimeout = const Duration(seconds: 10);
    final response = await dio.get(_versionUrl);
    if (response.statusCode == 200) {
      return AppUpdateInfo.fromJson(response.data as Map<String, dynamic>);
    }
  } catch (e) {
    debugPrint('Update check failed: $e');
  }
  return null;
}

/// 下载更新文件，返回本地文件路径
///
/// [onProgress] 回调：0.0 ~ 1.0
Future<String?> downloadUpdate(
  String url, {
  void Function(double progress)? onProgress,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final ext = Platform.isAndroid ? 'apk' : 'dmg';
    final savePath = '${dir.path}/app_update.$ext';

    // 删除旧文件
    final oldFile = File(savePath);
    if (oldFile.existsSync()) oldFile.deleteSync();

    final dio = Dio();
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    final savedFile = File(savePath);
    debugPrint('[Update] Downloaded: $savePath (${savedFile.lengthSync()} bytes)');

    return savePath;
  } catch (e) {
    debugPrint('Download update failed: $e');
    return null;
  }
}

/// 安装更新
///
/// Android: 打开 APK 触发系统安装器
/// macOS: 挂载 DMG → 替换 .app → 重启
Future<bool> installUpdate(String filePath) async {
  if (Platform.isAndroid) {
    return _installAndroid(filePath);
  } else if (Platform.isMacOS) {
    return _installMacOS(filePath);
  }
  return false;
}

Future<bool> _installAndroid(String apkPath) async {
  try {
    final result = await OpenFilex.open(apkPath);
    return result.type == ResultType.done;
  } catch (e) {
    debugPrint('Install APK failed: $e');
    return false;
  }
}

Future<bool> _installMacOS(String dmgPath) async {
  try {
    // 直接打开 DMG，Finder 会自动挂载并显示拖拽安装界面
    final result = await Process.run('open', [dmgPath]);
    return result.exitCode == 0;
  } catch (e) {
    debugPrint('[Update] macOS open DMG failed: $e');
    return false;
  }
}
