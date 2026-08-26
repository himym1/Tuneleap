# 私有更新发布

Android 与 macOS 使用同一套私有更新目录。发布者把安装包和元数据上传到 `navidrome-cloud`，App 通过 HTTPS 检查、下载、校验并打开安装包。

## 生产路径

| 项目 | 值 |
|---|---|
| 公网 Origin | `https://player.himym.us.ci` |
| 发布主机 | SSH alias `dmit` |
| 主机目录 | `/opt/navidrome-cloud/releases` |
| 容器目录 | `/app/releases`（只读挂载） |
| 元数据 | `/version.json`、`/appcast.xml` |
| 安装包 | `/releases/{filename}` |
| App 鉴权 | Cloud Bearer Access Token |

旧 NAS `navidrome-backend/releases` 已退役，不再作为发布目标。

## 发布步骤

1. 在 `scripts/versions.env` **只提升本轮要发的平台**。Android、macOS、Windows 各自比对自己的 version/build，锁步加号会让没改过的端也弹出更新。
2. `pubspec.yaml` 的 `version` 跟本轮主发平台对齐即可（本地 `flutter run` 用）。
3. 更新 `scripts/prepare-private-update.sh` 中的 changelog。
4. 完成验证，并只构建本轮平台：

```bash
flutter analyze
flutter test
make android   # 仅 Android 发版时
make macos     # 仅 macOS 发版时
```

5. 发布：

```bash
make publish
```

`make publish` 会：

1. 生成 `dist/version.json`、`dist/appcast.xml` 和 `dist/SHA256SUMS`。
2. 用本机钥匙串里的 Sparkle EdDSA 私钥签名 macOS DMG（`scripts/ensure-sparkle-tools.sh`）。私钥不要进仓库。
3. 检查当前版本的 APK、DMG、校验文件和元数据是否齐全。
4. 上传到 `cloud-host:/opt/navidrome-cloud/releases` 的临时目录。
5. 在服务器执行 `sha256sum -c`。
6. 先发布 APK/DMG/SHA，再原子替换 `version.json` 和 `appcast.xml`。
7. 仅在服务器内部读取 Cloud 运维 API Key，请求公网 `/version.json` 和 `/appcast.xml`；该 Key 不进入 App 或本机命令行。
8. 公网校验失败时原子恢复上一版 manifest；首次发布则撤下无效 manifest。

可通过环境变量覆盖非生产目标：

```bash
REMOTE_HOST=host \
REMOTE_DIR=/path/to/releases \
REMOTE_ENV_FILE=/path/to/.env \
UPDATE_ORIGIN=https://updates.example.com \
make publish
```

## App 更新流程

1. App 使用 Cloud 登录获得的 Bearer Access Token。401 时用安全存储中的 Refresh Token 轮换后重试一次。
2. Android 请求 `/version.json`，按语义版本和 build number 判断是否有新版本，下载 APK 后打开系统安装器。
3. macOS 1.0.48 起走 Sparkle：设置页仍读 `/version.json` 显示是否有新版本；安装走 `/appcast.xml`，用同一 Bearer 下载 DMG，由 Installer XPC 替换 `/Applications/音跃.app` 并重启。更旧的 macOS 客户端仍走 `/version.json` + 访达替换。
4. 校验失败会删除下载文件。

Cloud 服务端 API Key 只用于运维和服务器侧发布验证。App 不保存该 Key；更新检查和下载使用 Cloud 用户 Bearer Token。NAS Agent Key 只用于局域网导入/删除。

## 回滚

发布目录保留历史安装包和 `.version.previous.json`。需要回滚时，先检查目标安装包与 SHA-256，再将目标 manifest 通过同目录临时文件原子替换为 `version.json`。不要只替换安装包而保留不匹配的 SHA-256。
