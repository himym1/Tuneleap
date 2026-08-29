# 开发环境搭建

## 环境要求

| 工具 | 最低版本 | 说明 |
|---|---:|---|
| Flutter | 3.38+ | `flutter --version` |
| Dart | 3.10+ | 随 Flutter 安装 |
| Android SDK | API 24+ | Android 构建 |
| Xcode | 15+ | macOS 构建 |
| CocoaPods | 1.14+ | macOS 插件依赖 |
| Navidrome | 0.49+ | 本地曲库与 Subsonic API |

## 初始化

```bash
git clone <repo-url>
cd Tuneleap/apps/player
flutter pub get
flutter doctor
```

Flutter 构建会处理 macOS Pods；只有排查 CocoaPods 时才需要进入 `macos/` 手工运行 `pod install`。

## 运行

```bash
flutter run -d android
flutter run -d macos
```

App 需要三组独立配置：

| 配置 | 用途 | 生产示例 |
|---|---|---|
| Navidrome URL / 用户名 / 密码 | 曲库和播放 | 用户自己的 Subsonic 地址 |
| Cloud URL / Cloud 账号 | 搜索、推荐、歌词、更新 | `https://player.himym.us.ci` |
| NAS Agent URL / NAS Agent Key | 导入、删除 | `http://<nas-lan-ip>:8504` |

Cloud 的服务端 API Key 只保存在 Cloud `.env`，不得写入 App、仓库、命令输出或测试 fixture。App 通过 Cloud 注册/登录获取 Bearer Token；Refresh Token 存入平台安全存储。NAS Agent Key 只用于局域网导入/删除。

## 验证

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

针对推荐 API 的本地 smoke：

```bash
export RECOMMENDATION_SMOKE_BASE_URL=http://127.0.0.1:8600
export RECOMMENDATION_SMOKE_API_KEY=...
./scripts/recommendation-smoke.sh
```

该脚本会修改推荐 session/profile，不要误指向生产环境。

## 构建

```bash
make android
make macos
make windows   # Windows 主机；macOS 上见 release.md 的 Actions 步骤
```

产物写入 `dist/`。各平台版本由 `scripts/versions.env` 分别管理，`pubspec.yaml` 跟本轮主发平台对齐即可。

## 发布

```bash
make publish
```

发布目标默认为 Cloud 服务器，不再上传 NAS 旧 Backend。详见 [私有更新发布](./release.md)。

## 项目约定

- Riverpod 管理应用状态；Widget `build()` 不触发网络或持久化副作用。
- `NavidromeAudioHandler` 是播放队列、当前歌曲和播放历史的唯一 owner。
- Subsonic、Cloud、NAS Agent 使用各自客户端和凭据边界。
- 在线搜索结果由 Cloud first-success 决定，客户端不合并多个来源。
- 图片 URL 统一通过 `CoverArt` / `ResolvedSongCoverArt` 处理。
- 平台差异统一通过既有平台工具与插件封装处理。
