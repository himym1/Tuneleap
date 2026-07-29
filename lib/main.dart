import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app.dart';
import 'providers/providers.dart';
import 'player/audio_handler.dart';
import 'api/backend_client.dart';
import 'api/subsonic_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/l10n/localization_utils.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/providers/server_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppColors();
  final prefs = await SharedPreferences.getInstance();

  // ── 安全存储与服务器命名空间兼容迁移 ──
  await migratePasswordsToSecureStorage(prefs);
  final serverId = await migrateLegacyServerScopedData(prefs);
  var serverPassword = await preloadServerPassword();
  // 降级：secure storage 不可用时从 SharedPreferences 读取
  if (serverPassword.isEmpty) {
    serverPassword = prefs.getString('server_password') ?? '';
  }

  // 创建临时 SubsonicClient 用于 AudioHandler 初始化
  final client = SubsonicClient();
  final backendClient = BackendClient();
  final url = prefs.getString('server_url') ?? '';
  final username = prefs.getString('server_username') ?? '';
  await migrateActiveBackendConfiguration(
    prefs,
    serverId: serverId,
    serverUrl: url,
    serverPassword: serverPassword,
  );
  final backendUrl = prefs.getString(backendUrlPreferenceKey(serverId)) ?? '';
  final backendApiKey = await preloadServerBackendApiKey(prefs, serverId);
  final nasAgentUrl =
      prefs.getString(nasAgentUrlPreferenceKey(serverId)) ??
      (url.isNotEmpty ? BackendClient.inferBaseUrl(url) : '');
  final nasAgentKey = await preloadServerNasAgentKey(prefs, serverId);
  if (url.isNotEmpty && username.isNotEmpty) {
    client.configure(
      serverUrl: url,
      username: username,
      password: serverPassword,
    );
  }
  backendClient.configure(
    cloudBaseUrl: backendUrl,
    cloudApiKey: backendApiKey,
    nasAgentUrl: nasAgentUrl,
    nasAgentKey: nasAgentKey.isNotEmpty ? nasAgentKey : backendApiKey,
  );

  final strings = systemLocalizations();
  final packageInfo = await PackageInfo.fromPlatform();

  // 初始化 AudioService + Handler
  final handler = await AudioService.init(
    builder: () => NavidromeAudioHandler(
      client,
      backendClient,
      prefs: prefs,
      serverId: serverId,
    ),
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
      appBuildProvider.overrideWithValue(
        int.tryParse(packageInfo.buildNumber) ?? 0,
      ),
    ],
  );

  // 预设密码到内存缓存
  container.read(cachedPasswordProvider.notifier).set(serverPassword);
  container.read(cachedBackendApiKeyProvider.notifier).set(backendApiKey);
  container
      .read(cachedNasAgentKeyProvider.notifier)
      .set(nasAgentKey.isNotEmpty ? nasAgentKey : backendApiKey);

  // 加载多服务器密码
  await container.read(serversListProvider.notifier).loadPasswords();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NavidromePlayerApp(),
    ),
  );
}
