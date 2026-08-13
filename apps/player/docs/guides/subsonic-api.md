# Subsonic API 使用指南

本指南介绍如何在 Navidrome Player 中使用 Subsonic API 客户端。

## 认证流程

Subsonic API 使用 token 认证（v1.13.0+），每次请求需携带认证参数。

### Token 生成

```dart
// 1. 生成随机 salt
final salt = _generateSalt(); // 6 位随机字母数字

// 2. 计算 token
final token = md5(password + salt); // MD5 哈希

// 3. 构造认证参数
final params = {
  'u': username,
  't': token,
  's': salt,
  'v': '1.16.1',
  'c': 'NavidromePlayer',
  'f': 'json',
};
```

### Salt 生成实现

```dart
String _generateSalt({int length = 6}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}
```

## 请求构造

所有 API 请求通过 `SubsonicClient` 统一发送。

### 基本用法

```dart
// 获取客户端实例（通过 Riverpod）
final client = ref.read(subsonicClientProvider);

// 配置服务器
client.configure(
  serverUrl: 'http://192.168.1.100:4533',
  username: 'admin',
  password: 'password',
);

// 测试连接
final ok = await client.ping();

// 浏览专辑
final albums = await client.getAlbumList2(type: 'newest', size: 20);

// 搜索
final results = await client.search3('关键词');

// 获取流媒体 URL（不发请求，仅构造 URL）
final streamUrl = client.streamUrl(songId);
final coverUrl = client.coverArtUrl(coverArtId, size: 300);
```

### URL 构造模式

`stream` 和 `getCoverArt` 不通过 dio 请求，而是直接构造完整 URL 供 just_audio 和 CachedNetworkImage 使用：

```dart
String streamUrl(String id) {
  final params = _authParams();
  params['id'] = id;
  final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
  return '$_baseUrl/rest/stream?$query';
}
```

## 错误处理

API 错误通过 `SubsonicApiException` 抛出：

```dart
try {
  final albums = await client.getAlbumList2(type: 'newest');
} on SubsonicApiException catch (e) {
  // e.code: 错误码 (0/10/40/50/70)
  // e.message: 错误描述
} on DioException catch (e) {
  // 网络错误
}
```

常见错误码：`40` 认证失败、`50` 无权限、`70` 资源不存在。
