---
name: "navidrome-player-release"
description: "安全完成 navidrome_player 的同步、版本递增、提交推送、Android/macOS 构建和私有更新部署，并验证客户端可检测到新版本"
version: 1
created: "2026-08-06"
updated: "2026-08-06"
---

# Navidrome Player Release

## When to Use

用户要求对本播放器项目（`apps/player`）执行以下任一完整发布意图时使用：

- `commit/push - 打包构建 - 部署`
- 发布 Flutter 安装包或私有更新
- 同步远端后发布 Android APK 与 macOS DMG
- 修复“检查更新找不到新版本”并重新发布

普通开发、只运行本地调试、只提交代码或只诊断更新问题时不要执行完整发布流程。

## Source of Truth

- 项目：仓库内 `apps/player`
- 分支：`main`
- 远端：`origin/main`
- 版本配置：`pubspec.yaml`、`scripts/versions.env`
- 更新说明：`scripts/prepare-private-update.sh`
- 构建：`scripts/build.sh` 或 `make android` / `make macos` / `make windows`
- 发布：`scripts/deploy-private-update.sh` 或 `make publish`
- 发布规范：`docs/release.md`
- 公网 Origin：`https://player.himym.us.ci`
- 发布主机：环境变量 `REMOTE_HOST`（本机 SSH alias）
- 发布目录：`REMOTE_DIR`，默认 `/opt/navidrome-cloud/releases`

现有脚本是构建、校验和上传的唯一实现。Skill 只编排、检查和报告，不复制发布逻辑。

## Authorization Boundary

- 用户明确说“部署、发布、上传服务器、commit/push - 打包构建 - 部署”时，视为授权本轮提交、推送、构建和生产更新发布。
- 未明确授权 push 或部署时，完成只读预检和 diff 摘要后停止，等待确认。
- 不读取、打印、复制或落盘 `.env`、API Key、Bearer Token、证书或密码。
- 服务器侧认证验证只能调用现有发布脚本；该脚本在远端内部读取运维 Key，不能把 Key带回本机或输出到日志。

## Procedure

### 1. Read-only preflight

1. 进入项目根目录，确认 `git rev-parse --show-toplevel` 等于项目路径。
2. 运行 `git fetch origin`，记录本地 HEAD、`origin/main`、当前分支和分叉数量。
3. 读取 `docs/release.md`、`scripts/versions.env`、`pubspec.yaml` 和发布脚本；不读取任何 `.env`。
4. 运行 SSH 只读连通性检查：`ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_HOST" 'printf ready'`（`REMOTE_HOST` 默认见 `deploy-private-update.sh`）。
5. 只读获取服务器当前 `version.json` 中 Android/macOS 的 version/build；只能输出版本号与 build，不输出任何凭据。
6. 检查 Git 状态并分类：任务文件、用户已有改动、生成物、未跟踪文件。

构建敏感路径包括：`lib/`、`assets/`、`android/`、`ios/`、`macos/`、`windows/`、`linux/`、`web/`、`test/`、`scripts/`、`pubspec.yaml`、`pubspec.lock`、`Makefile`。这些路径中的未提交或未跟踪内容必须纳入明确任务范围，否则停止。

不要自动删除、还原、stash 或提交用户已有改动。不要使用 `git add .`、强推、`git reset --hard` 或 `git checkout --`。

### 2. Synchronize before editing

1. 如果本地落后且没有本地提交，执行 fast-forward pull。
2. 如果本地与远端分叉，先展示提交图和冲突风险；明确获得本轮合并授权后合并 `origin/main`，禁止强推覆盖。
3. 冲突解决以远端最新架构为基础，逐项重新应用本轮需求；不能用整文件 `ours/theirs` 覆盖仍需保留的功能。
4. 合并后运行最小相关分析/测试，确认需求入口没有在冲突解决中消失。

### 3. Determine the next release version

1. 比较服务器 manifest、`origin/main`、`pubspec.yaml` 和 `scripts/versions.env` 的版本。
2. 新 Android/macOS version 必须严格高于服务器当前 version，或在相同语义版本下 build 严格增加；默认补丁版本和 build 各加 1。
3. 同步修改：
   - `pubspec.yaml` 的 `version`
   - `scripts/versions.env` 的 `ANDROID_VERSION` / `ANDROID_BUILD`
   - `scripts/versions.env` 的 `MACOS_VERSION` / `MACOS_BUILD`
   - `scripts/prepare-private-update.sh` 的 changelog
4. Android 与 macOS 必须使用相同 version/build。
5. 禁止用服务器已有 version/build 重新发布。版本未递增时立即停止。

### 4. Verify before commit

1. 只格式化本轮修改的 Dart 文件，禁止对整个旧仓库机械格式化。
2. 运行 `dart analyze` 或 `flutter analyze`。
3. 运行与改动相关的测试；共享播放、搜索、歌单、更新或认证逻辑应运行对应测试。发布前优先运行完整 `flutter test`，时间或环境受限时必须报告未覆盖范围。
4. 运行 `git diff --check`。
5. 检查关键 UI/行为入口仍存在；例如通过稳定 Key、测试或源码定位验证本轮按钮和路由没有被合并覆盖。
6. 展示精确待提交文件列表，排除 `dist/`、`build/`、设计稿、缓存、工具目录、密钥和无关改动。

### 5. Commit and push exactly scoped files

1. 仅 `git add` 本轮任务文件和版本文件。
2. 再次运行 `git diff --cached --check` 并审查 staged stat。
3. 创建一个完整、可发布的提交；版本变更可以和对应功能同提交，或作为紧随功能提交的 release 提交。
4. 推送 `origin main`。
5. 推送后确认 `HEAD` 与 `origin/main` 相同；非 fast-forward 时回到同步步骤，禁止强推。

### 6. Build only committed source

推送后、构建前必须再次检查：

- `git diff --quiet`
- `git diff --cached --quiet`
- 构建敏感路径没有未跟踪文件
- `HEAD == origin/main`
- 当前 `pubspec.yaml` 和 `scripts/versions.env` 版本一致

任一条件不满足时停止，不得从脏源码构建。非构建敏感的未跟踪设计资料可保留，但必须在报告中说明未纳入发布。

按顺序构建，避免同一 Flutter 工程并发构建：

```bash
bash scripts/build.sh android
bash scripts/build.sh macos
```

确认生成：

```text
dist/navidrome_player-<version>+<build>-android.apk
dist/navidrome_player-<version>+<build>-macos.dmg
```

检查 macOS 构建已完成 Developer ID 签名和 `codesign --verify`。构建失败时停止，不发布旧 artifact。

### 7. Prepare and publish

1. 运行 `scripts/prepare-private-update.sh`，检查 `version.json` 中 Android/macOS version/build、URL 和 SHA-256。
2. 再次确认生成的 version/build 严格高于发布前读取的服务器版本。
3. 执行：

```bash
bash scripts/deploy-private-update.sh
```

4. 只接受以下全部成功：
   - APK/DMG `sha256sum -c` 通过
   - artifact 先上传，`version.json` 最后原子替换
   - 认证公网 `/version.json` 返回预期 Android/macOS version/build
   - 发布脚本没有触发 manifest 回滚

不要用匿名 `curl` 的 `401` 判断发布失败；该端点是私有更新接口。验证必须走发布脚本的服务器内部认证流程。

### 8. Final verification and report

最终报告必须包含：

- 根因或发布目标
- 最终 Git commit 与 `origin/main` 同步状态
- Android/macOS version/build
- APK/DMG 文件名
- analyze/test 结果与未覆盖风险
- SHA-256/服务器校验是否通过
- 认证公网 manifest 的最终 version/build
- 保留但未提交的用户改动或未跟踪文件

不要声称“已发布”除非推送、两端构建、服务器哈希校验和认证 manifest 校验全部成功。

## Stop Conditions

出现任一情况立即停止并说明：

- 工作区有范围不明的构建敏感改动
- 本地与远端分叉且未授权合并
- 冲突解决无法确认需求是否保留
- 新版本不高于服务器当前版本
- Android/macOS/pubspec 版本不一致
- analyze、相关测试或 `git diff --check` 失败
- push 被拒绝
- APK/DMG 不是从当前已推送 HEAD 构建
- 签名、SHA-256、上传或认证 manifest 校验失败
- 需要读取、复制或暴露凭据才能继续

## Common Mistakes

- 在拉取远端前基于旧分支修改和发布。
- 合并冲突时整文件选择远端，覆盖刚实现的按钮或行为。
- 用同一个 version/build 重发，导致客户端正确判断“没有更新”。
- 在提交后恢复 stash，再从含未提交源码的工作区构建。
- 只检查 APK，不构建或签名 macOS DMG。
- 上传成功后不检查认证 `/version.json`。
- 把匿名 `401` 误判为发布失败，或反过来忽略 App 没有 Cloud Token 的真实认证问题。
- 把 `dist/`、`build/`、设计稿、工具缓存或 `.env` 提交进 Git。
