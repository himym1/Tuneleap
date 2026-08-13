# 私有更新发布

Android 与 macOS 使用同一套私有更新目录。发布者把安装包和元数据上传到 `navidrome-cloud`，App 通过 HTTPS 检查、下载、校验并打开安装包。

## 生产路径

| 项目 | 值 |
|---|---|
| 公网 Origin | `https://player.himym.us.ci` |
| 发布主机 | SSH alias `dmit` |
| 主机目录 | `/opt/navidrome-cloud/releases` |
| 容器目录 | `/app/releases`（只读挂载） |
| 元数据 | `/version.json` |
| 安装包 | `/releases/{filename}` |
| App 鉴权 | Cloud Bearer Access Token |

旧 NAS `navidrome-backend/releases` 已退役，不再作为发布目标。

## 发布步骤

1. 在 `scripts/versions.env` 同时提升 Android/macOS 版本与 build number。
2. 同步 `pubspec.yaml` 的版本。
3. 更新 `scripts/prepare-private-update.sh` 中的 changelog。
4. 完成验证和构建：

```bash
flutter analyze
flutter test
make android
make macos
```

5. 发布：

```bash
make publish
```

`make publish` 会：

1. 生成 `dist/version.json` 和 `dist/SHA256SUMS`。
2. 检查当前版本的 APK、DMG、校验文件和元数据是否齐全。
3. 上传到 `dmit:/opt/navidrome-cloud/releases` 的临时目录。
4. 在服务器执行 `sha256sum -c`。
5. 先发布 APK/DMG/SHA，最后原子替换 `version.json`。
6. 仅在服务器内部读取 Cloud 运维 API Key，请求公网 `/version.json` 并核对 Android 版本和 build；该 Key 不进入 App 或本机命令行。
7. 公网校验失败时原子恢复上一版 manifest；首次发布则撤下无效 manifest。

可通过环境变量覆盖非生产目标：

```bash
REMOTE_HOST=host \
REMOTE_DIR=/path/to/releases \
REMOTE_ENV_FILE=/path/to/.env \
UPDATE_ORIGIN=https://updates.example.com \
make publish
```

## App 更新流程

1. App 使用 Cloud 登录获得的 Bearer Access Token 请求 `/version.json`；401 时用安全存储中的 Refresh Token 轮换后重试一次。
2. App 按语义版本和 build number 判断是否有新版本。
3. 用户确认后，App 从同一 HTTPS Origin 的 `/releases/` 下载安装包。
4. App 校验 SHA-256；校验失败会删除下载文件。
5. Android 打开 APK 安装器；macOS 打开 DMG。

Cloud 服务端 API Key 只用于运维和服务器侧发布验证。App 不保存该 Key；更新检查和下载使用 Cloud 用户 Bearer Token。NAS Agent Key 只用于局域网导入/删除。

## 回滚

发布目录保留历史安装包和 `.version.previous.json`。需要回滚时，先检查目标安装包与 SHA-256，再将目标 manifest 通过同目录临时文件原子替换为 `version.json`。不要只替换安装包而保留不匹配的 SHA-256。
