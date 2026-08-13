# 状态管理 (Riverpod)

本项目使用 [Riverpod](https://riverpod.dev/) 3.x 进行状态管理。

## 架构概览

```
UI (ConsumerWidget)
  ↓ ref.watch / ref.read
Provider (Riverpod)
  ↓ 持有
Service / Client 实例
```

## 现有 Provider

所有 Provider 定义在 `lib/providers/providers.dart`。

### sharedPreferencesProvider

```dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});
```

- 类型：`Provider<SharedPreferences>`
- 初始化：`main.dart` 中通过 `ProviderScope.overrides` 注入
- 用途：KV 键值存储（服务器配置等）

### serverConfigProvider

```dart
final serverConfigProvider = Provider<ServerConfig>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ServerConfig(prefs);
});
```

- 类型：`Provider<ServerConfig>`
- 依赖：sharedPreferencesProvider
- 用途：读写服务器连接配置（url, username, password）
- ServerConfig 属性：`serverUrl`, `username`, `password`, `isConfigured`

### subsonicClientProvider

```dart
final subsonicClientProvider = Provider<SubsonicClient>((ref) {
  final config = ref.watch(serverConfigProvider);
  final client = SubsonicClient();
  if (config.isConfigured) {
    client.configure(...);
  }
  return client;
});
```

- 类型：`Provider<SubsonicClient>`
- 依赖：serverConfigProvider
- 用途：提供已配置的 Subsonic API 客户端实例

### audioPlayerServiceProvider

```dart
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final client = ref.watch(subsonicClientProvider);
  final service = AudioPlayerService(client);
  service.init();
  return service;
});
```

- 类型：`Provider<AudioPlayerService>`
- 依赖：subsonicClientProvider
- 用途：提供音频播放服务实例
