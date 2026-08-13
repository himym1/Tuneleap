# 音跃 · 播放器

音跃产品仓里的 Flutter 客户端，目录是 `apps/player`。支持 Android 与 macOS。客户端同时接入公网 Cloud 和局域网 NAS Agent，提供在线搜索、推荐、导入和私有更新。

产品总览见仓库根目录 [README](../../README.md) 和 [架构](../../docs/architecture.md)。

## 主要能力

- Navidrome/Subsonic 登录、曲库、艺术家、专辑、歌曲和播放列表。
- `just_audio` + `audio_service` 播放队列、后台播放、锁屏控制、随机/循环、倍速和音量。
- 歌词、封面缓存、动态主题、深色/浅色/AMOLED 主题。
- Cloud first-success 在线搜索、播放 URL、封面与歌词解析。
- 基于播放历史和反馈的在线推荐，过滤 NAS 曲库中已有歌曲。
- 通过 NAS Agent 导入/删除歌曲，不让公网 Cloud 直接访问音乐目录或 `navidrome.db`。
- 多 Navidrome 服务器隔离：播放历史、下载、缓存和凭据按 `serverId` 分区。
- Android/macOS 应用内检查更新、同源下载、SHA-256 校验和系统安装入口。

## 三端点配置

| 配置 | 用途 | 生产示例 |
|---|---|---|
| Navidrome URL + 用户名/密码 | 本地曲库与音频流 | 用户自己的 Subsonic 地址 |
| Cloud URL + Cloud 账号 | 搜索、推荐、歌词、更新 | `https://player.himym.us.ci` |
| NAS Agent URL + NAS Agent Key | 导入、删除 | `http://192.168.1.10:8504` |

Cloud 的服务端 API Key 只存在于 Cloud 环境。App 使用 Cloud 登录后获得的 Bearer Access Token，并在安全存储中保存轮换 Refresh Token；NAS Agent 使用独立的局域网 Key。NAS Agent URL 留空时，App 会从 Navidrome 主机推断 LAN 端口 `8504`；Cloud URL 默认使用生产 Origin。

## 技术栈

| 类别 | 技术 |
|---|---|
| 框架 | Flutter / Dart |
| 状态管理 | Riverpod 3.x |
| 路由 | go_router |
| 播放 | just_audio + audio_service |
| 网络 | dio |
| 本地存储 | shared_preferences + flutter_secure_storage |
| 图片 | cached_network_image + palette_generator |
| UI | Material 3 |

## 开发

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
# 或 flutter run -d android
```

环境要求和三端点调试说明见 [开发指南](./docs/development-guide.md)。

## 构建与发布

```bash
make android
make macos
make publish
```

构建产物写入 `dist/`。`make publish` 将 APK、DMG、SHA-256 和 `version.json` 上传至 Cloud 发布目录，App 通过 `https://player.himym.us.ci/version.json` 发现新版本。

完整流程见 [私有更新发布](./docs/release.md)。

## 项目结构

```text
lib/
├── api/                 # Subsonic 与 Cloud/NAS 双端点客户端、模型
├── player/              # AudioHandler、队列、播放历史
├── providers/           # Riverpod 状态与服务边界
├── services/            # 更新检查等应用服务
├── ui/                  # 页面、组件、主题
└── utils/               # 通用工具

scripts/
├── build.sh
├── prepare-private-update.sh
├── deploy-private-update.sh
└── versions.env
```

## 文档

- [文档中心](./docs/README.md)
- [系统架构](./docs/architecture.md)
- [私有更新发布](./docs/release.md)
- [ADR-0004 Cloud + NAS Agent](./docs/adr/0004-cloud-control-plane-and-nas-agent.md)
- [产品文档](./docs/navidrome-player-prd.md)
- [设计稿管理](./docs/designs/pencil/README.md)

## 许可证

[MIT](./LICENSE)
