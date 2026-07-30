# 系统架构

## 运行拓扑

Navidrome Player 是三项目架构中的客户端：

```text
Navidrome Player
├── Navidrome / Subsonic
│   └── 本地曲库、专辑、歌曲、播放列表、音频流、scrobble
├── navidrome-cloud
│   └── 在线搜索、播放 URL、封面、歌词、推荐、认证、私有更新
└── navidrome-nas-agent
    └── NAS 导入、删除、扫描和曲库身份读取
```

生产部署：

| 组件 | 位置 | 对外地址 |
|---|---|---|
| `navidrome-cloud` | DMIT `/opt/navidrome-cloud` | `https://player.himym.us.ci` |
| Cloud Postgres | DMIT Docker | 仅 loopback / Docker 网络 |
| `navidrome-nas-agent` | himym `/volume1/docker/navidrome-nas-agent` | LAN `http://192.168.8.146:8504` |
| Navidrome | himym NAS | Subsonic URL 由用户配置 |

旧的单体 `navidrome-backend:8503` 已退役并删除。

## 职责边界

### Flutter Client

- UI、导航、播放队列和本地偏好。
- 调用 Subsonic、Cloud 和 NAS Agent 三个独立端点。
- Cloud 搜索采用 first-success 返回的单一结果集，不在客户端合并来源。
- 推荐只展示和回传反馈，不持有推荐算法或服务端状态。
- 下载更新前校验同源 URL 与 SHA-256。

### navidrome-cloud

- 公网控制面，FastAPI + Postgres。
- 持有账号、Refresh Token、推荐 session/candidate/feedback/profile。
- 代理在线音乐来源，执行 first-success 搜索。
- 读取 NAS Agent 提供的曲库身份，过滤本地已有歌曲。
- 从只读挂载的 `/app/releases` 提供版本元数据和安装包。
- 不挂载 NAS 音乐目录，不打开 `navidrome.db`。

### navidrome-nas-agent

- 唯一允许读取 `navidrome.db` 和写 NAS 音乐目录的配套服务。
- 执行导入、删除和扫描。
- 提供曲库身份给 Cloud 的推荐过滤流程。
- 使用独立 NAS Agent Key；不承担公网搜索、账号和更新服务。

## Flutter 分层

```text
UI Layer       ui/screens, ui/widgets, ui/theme
State Layer    providers (Riverpod)
Service Layer  player, services
Data Layer     api, models
```

关键客户端：

| 文件 | 职责 |
|---|---|
| `api/subsonic_client.dart` | Navidrome/Subsonic API |
| `api/backend_client.dart` | Cloud + NAS Agent 双端点客户端 |
| `providers/server_config_provider.dart` | 三端点配置及独立凭据 |
| `providers/recommendation_provider.dart` | 推荐 session、分页、反馈 outbox |
| `player/audio_handler.dart` | 唯一播放状态、队列和历史 owner |
| `services/update_checker.dart` | 更新检查、同源校验、SHA-256、安装入口 |

`backendUrl` 是为兼容已有偏好键保留的字段名，语义是 Cloud URL。旧 `backendApiKey` 偏好只用于迁移清理，不再参与请求；Cloud Access Token 仅驻内存，Refresh Token 存入平台安全存储。

## 数据流

### 在线搜索和播放

```text
SearchScreen
  -> BackendClient
  -> navidrome-cloud first-success adapter
  -> 单一来源 SongDTO 列表
  -> Cloud 解析播放 URL / 封面 / 歌词
  -> AudioHandler 播放
```

### 导入

```text
App 从 Cloud 获取在线歌曲元数据
  -> App 调用 NAS Agent /v1/nas/import
  -> NAS Agent 下载并写入音乐目录
  -> Navidrome 扫描后进入本地曲库
```

导入与删除必须使用显式的局域网 NAS Agent 地址和独立 Key；公网 Navidrome 地址不会自动推断为 Agent。重复导入默认按归一化标题/歌手拒绝，只有用户确认“仍然导入”后才发送 `force: true`。

### 推荐

```text
App 最近播放 + feedback
  -> Cloud 推荐 session
  -> Cloud 从 NAS Agent 获取曲库身份并过滤
  -> Cloud Bearer 认证 + Postgres 持久化候选与反馈
  -> App 分页展示并回传 played/completed/imported/disliked/unavailable
```

### 私有更新

```text
make publish
  -> dmit:/opt/navidrome-cloud/releases
  -> https://player.himym.us.ci/version.json
  -> App 下载 /releases/{filename}
  -> SHA-256 校验
  -> 系统安装器
```

完整发布步骤见 [私有更新发布](./release.md)。
