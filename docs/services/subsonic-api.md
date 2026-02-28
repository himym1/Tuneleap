# Subsonic API 参考

## 协议概述

Navidrome Player 通过 [Subsonic API](http://www.subsonic.org/pages/api.jsp) 协议与 Navidrome 服务端通信。

- API 版本：`1.16.1`
- 客户端标识：`NavidromePlayer`
- 响应格式：JSON (`f=json`)

## 认证机制

采用 token 认证方式（Subsonic API 1.13.0+）：

```
token = md5(password + salt)
```

每次请求携带以下参数：
- `u` — 用户名
- `t` — token (MD5 哈希)
- `s` — salt (随机字符串)
- `v` — API 版本
- `c` — 客户端名称
- `f` — 响应格式 (json)

### 认证示例

```
GET /rest/ping?u=admin&t=26719a1196d2a940705a59634eb18eab&s=c19b2d&v=1.16.1&c=NavidromePlayer&f=json
```

## API 端点

### 1. 系统

#### `ping`
测试服务器连接和认证。

- 方法：`GET /rest/ping`
- 参数：仅认证参数
- 返回：`{ "subsonic-response": { "status": "ok" } }`

### 2. 浏览

#### `getArtists`
获取所有艺术家列表（按字母索引分组）。

- 方法：`GET /rest/getArtists`
- 返回：`artistsID3.index[].artist[]` — Artist 列表

#### `getArtist`
获取艺术家详情及其专辑列表。

- 方法：`GET /rest/getArtist`
- 参数：`id` — 艺术家 ID
- 返回：`artist` + `artist.album[]` — ArtistDetail + Album 列表

#### `getAlbum`
获取专辑详情及其歌曲列表。

- 方法：`GET /rest/getAlbum`
- 参数：`id` — 专辑 ID
- 返回：`album` + `album.song[]` — Album + Song 列表

#### `getAlbumList2`
获取专辑列表（支持排序和分页）。

- 方法：`GET /rest/getAlbumList2`
- 参数：
  - `type` — 排序方式 (`newest`, `frequent`, `recent`, `random`, `alphabeticalByName`)
  - `size` — 返回数量（默认 10）
  - `offset` — 偏移量
- 返回：`albumList2.album[]` — Album 列表

### 3. 搜索

#### `search3`
全文搜索（艺术家、专辑、歌曲）。

- 方法：`GET /rest/search3`
- 参数：
  - `query` — 搜索关键词
  - `artistCount` / `albumCount` / `songCount` — 各类型返回数量
- 返回：`searchResult3` — `{ artist[], album[], song[] }`

### 4. 媒体获取

#### `stream`
获取歌曲音频流 URL。

- 方法：`GET /rest/stream`
- 参数：`id` — 歌曲 ID
- 返回：音频流（直接播放，不解析 JSON）
- 注意：返回的是完整 URL，直接传给 just_audio

#### `getCoverArt`
获取封面图 URL。

- 方法：`GET /rest/getCoverArt`
- 参数：
  - `id` — coverArt ID
  - `size` — 图片尺寸（默认 300）
- 返回：图片流（直接作为图片 URL 使用）

### 5. 播放列表

#### `getPlaylists`
获取所有播放列表。

- 方法：`GET /rest/getPlaylists`
- 返回：`playlists.playlist[]` — Playlist 列表

#### `getPlaylist`
获取播放列表详情及歌曲。

- 方法：`GET /rest/getPlaylist`
- 参数：`id` — 播放列表 ID
- 返回：`playlist` + `playlist.entry[]` — Playlist + Song 列表

### 6. 标记与统计

#### `star`
收藏歌曲/专辑/艺术家。

- 方法：`GET /rest/star`
- 参数：`id` — 目标 ID

#### `unstar`
取消收藏。

- 方法：`GET /rest/unstar`
- 参数：`id` — 目标 ID

#### `scrobble`
上报播放记录。

- 方法：`GET /rest/scrobble`
- 参数：
  - `id` — 歌曲 ID
  - `submission` — `true`（播放完成）/ `false`（开始播放）

## 错误处理

API 错误通过 `subsonic-response.error` 返回：

| code | 含义 |
|------|------|
| 0 | 通用错误 |
| 10 | 缺少必要参数 |
| 40 | 认证失败 |
| 50 | 无权限 |
| 70 | 资源不存在 |

客户端通过 `SubsonicApiException` 统一处理错误响应。
