# 开发环境搭建

## 环境要求

| 工具 | 最低版本 | 说明 |
|------|---------|------|
| Flutter | 3.38+ | `flutter --version` 确认 |
| Dart | 3.10+ | 随 Flutter 安装 |
| Android SDK | API 21+ | Android 开发 |
| Xcode | 15+ | macOS 开发 |
| CocoaPods | 1.14+ | macOS 依赖管理 |
| Navidrome | 0.49+ | 测试用服务端 |

## 项目搭建

```bash
# 1. 克隆项目
git clone <repo-url>
cd navidrome_player

# 2. 安装 Flutter 依赖
flutter pub get

# 3. macOS 额外步骤
cd macos && pod install && cd ..

# 4. 验证环境
flutter doctor
```

## 构建与运行

```bash
# Android 调试运行
flutter run -d android

# macOS 调试运行
flutter run -d macos

# Android Release 构建
flutter build apk --release

# macOS Release 构建
flutter build macos --release
```

### 调试 Navidrome 连接

1. 确保 Navidrome 服务端运行中
2. 确认设备与服务端在同一网络（或有公网访问）
3. 在登录页输入完整 URL（含端口，如 `http://192.168.1.100:4533`）
4. 点击连接测试，查看控制台日志排查问题

## 代码规范

- 使用 `flutter_lints` 默认规则
- 运行 `flutter analyze` 检查代码问题
- 注释语言：中文
- 变量/类名：英文，遵循 Dart 命名规范
- 文件命名：`snake_case.dart`
- 类命名：`PascalCase`

## 项目约定

- 状态管理统一使用 Riverpod Provider
- 网络请求统一通过 SubsonicClient
- 图片加载使用 CoverArt 组件（封装 CachedNetworkImage）
- 主题色通过 AppTheme 统一管理
- 平台判断使用 `utils/platform_utils.dart`

