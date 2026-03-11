import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app.dart';
import 'providers/providers.dart';
import 'player/audio_handler.dart';
import 'api/solara_client.dart';
import 'api/subsonic_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/l10n/localization_utils.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppColors();
  final prefs = await SharedPreferences.getInstance();

  // ── 密码安全迁移：明文 → flutter_secure_storage ──
  await migratePasswordsToSecureStorage(prefs);
  var serverPassword = await preloadServerPassword();
  // 降级：secure storage 不可用时从 SharedPreferences 读取
  if (serverPassword.isEmpty) {
    serverPassword = prefs.getString('server_password') ?? '';
  }

  // 创建临时 SubsonicClient 用于 AudioHandler 初始化
  final client = SubsonicClient();
  final solaraClient = SolaraClient();
  final url = prefs.getString('server_url') ?? '';
  final username = prefs.getString('server_username') ?? '';
  if (url.isNotEmpty && username.isNotEmpty) {
    client.configure(
      serverUrl: url,
      username: username,
      password: serverPassword,
    );
  }
  if (url.isNotEmpty) {
    final baseUrl = SolaraClient.inferBaseUrl(url);
    if (baseUrl.isNotEmpty) {
      solaraClient.configure(baseUrl: baseUrl);
    }
  }

  final strings = systemLocalizations();
  final packageInfo = await PackageInfo.fromPlatform();

  // 初始化 AudioService + Handler
  final handler = await AudioService.init(
    builder: () => NavidromeAudioHandler(client, solaraClient, prefs: prefs),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.navidrome.player.audio',
      androidNotificationChannelName: strings.appName,
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  // 创建 ProviderContainer 以便预设密码
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      audioHandlerProvider.overrideWithValue(handler),
      appVersionProvider.overrideWithValue(packageInfo.version),
    ],
  );

  // 预设密码到内存缓存
  container.read(cachedPasswordProvider.notifier).set(serverPassword);

  // 加载多服务器密码
  await container.read(serversListProvider.notifier).loadPasswords();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NavidromePlayerApp(),
    ),
  );
}
