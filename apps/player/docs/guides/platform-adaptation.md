# 平台适配

Navidrome Player 支持 Android 和 macOS 两个平台，各有特定的配置需求。

## Android

### 权限配置

`android/app/src/main/AndroidManifest.xml` 中声明的权限：

| 权限 | 用途 |
|------|------|
| `INTERNET` | 网络访问（Subsonic API + 音频流） |
| `FOREGROUND_SERVICE` | 前台服务（后台播放） |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | 媒体播放前台服务 |
| `WAKE_LOCK` | 防止播放时休眠 |

### 构建配置

- namespace: `com.example.navidrome_player`（待修改为正式包名）
- Java 版本：17
- minSdk / targetSdk：Flutter 默认值
- 签名：仅 debug 签名（release 签名待配置）

## macOS

### Entitlements 配置

**Debug/Profile** (`macos/Runner/DebugProfile.entitlements`)：

| 权限 | 用途 |
|------|------|
| `app-sandbox` | 沙盒模式 |
| `jit` | JIT 编译（仅 debug） |
| `network.server` | 本地服务器（仅 debug） |
| `network.client` | 网络客户端访问 |
| `audio-input` | 音频输入 |

**Release** (`macos/Runner/Release.entitlements`)：

| 权限 | 用途 |
|------|------|
| `app-sandbox` | 沙盒模式 |
| `network.client` | 网络客户端访问 |
| `audio-input` | 音频输入 |

### 窗口管理

通过 `window_manager` 在 `app.dart` 中配置：

```dart
if (Platform.isMacOS) {
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(400, 600));
  await windowManager.setSize(const Size(1000, 700));
  await windowManager.setTitle('Navidrome Player');
  await windowManager.show();
}
```

### CocoaPods

macOS 依赖通过 CocoaPods 管理，`Podfile` 和 `Podfile.lock` 已配置。新增原生依赖后需运行：

```bash
cd macos && pod install && cd ..
```

## 平台判断

`lib/utils/platform_utils.dart` 提供平台判断工具：

```dart
import 'dart:io';
bool get isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;
```

用于 UI 层根据平台选择不同布局（如 NavigationRail vs BottomNavigationBar）。

