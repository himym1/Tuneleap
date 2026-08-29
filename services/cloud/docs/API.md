# navidrome-cloud — API

Base URL example: `https://cloud.example.com` or local `http://127.0.0.1:8600`.

Auth:

- `X-API-Key: <API_KEY>` (or `?api_key=`)
- or `Authorization: Bearer <access_token>` from `/v1/auth/*`

## System

### `GET /health`

No auth.

```json
{ "status": "ok", "service": "navidrome-cloud", "version": "0.1.0" }
```

## Music

### `GET /v1/music/capabilities`

Returns currently available configured adapters in failover order and the platforms each adapter supports. An adapter may be omitted temporarily after a runtime quota failure. The Player uses this response to limit source tabs for a selected search API.

```json
{
  "default_provider": "meting",
  "sources": {
    "netease": { "max_count": 50, "paginates": true },
    "tencent": { "max_count": 30, "paginates": false },
    "kugou": { "max_count": 30, "paginates": false }
  },
  "adapters": [
    { "id": "meting", "sources": ["netease", "tencent", "kugou"] },
    { "id": "gdstudio", "sources": ["netease", "kugou", "migu", "joox"] }
  ]
}
```

`sources` is the product window: `max_count` is the largest first page Cloud will ask for; `paginates` is true when any configured adapter can return a later window. Adapter `sources` lists stay as ids so older clients keep working.


### `GET /v1/music/search`

| Param | Required | Notes |
|---|---|---|
| `q` | yes | User search string |
| `source` | no | Platform id: `netease`, `tencent` (`qq` accepted), `kugou`, `migu`, `joox`, `kuwo`. When set, search stays on that platform. When omitted, Cloud walks `MUSIC_SEARCH_SOURCES`. |
| `provider` | no | Adapter id from `/v1/music/capabilities`. When set, page 1 stays on that adapter. Page 2+ skips adapters that cannot paginate that platform and may fail over to one that can. Unsupported platform combinations are still rejected. |
| `count` | no | Page-size hint, default 30, max 50. `count >= 30` uses that platform’s product window (网易 50). Smaller values stay exact for tests and tools. A short page is not “no more results”. Unpinned page 1 prefers an adapter that can paginate and return the larger window. |
| `page` | no | default 1 |

An explicit `source` is pinned. Do not send a source if you want first-success across configured platforms. For `page > 1` without `source`, Cloud stays on the first configured search source. `has_more` is true when a later window exists for that platform. QQ and Kugou currently have one stable window.

Success:

```json
{
  "query": "hello",
  "provider": "gdstudio",
  "source": "netease",
  "strategy": "first-success",
  "page": 1,
  "has_more": true,
  "items": [
    {
      "id": "…",
      "title": "…",
      "artist": "…",
      "album": "…",
      "source": "netease",
      "provider": "gdstudio",
      "url_id": "…",
      "cover_id": "…",
      "lyric_id": "…",
      "duration": 240.0
    }
  ]
}
```

| Code | When |
|---|---|
| 401 | Missing/invalid key/token |
| 400 | Requested adapter is unavailable or does not support the requested platform |
| 502/504 | All upstreams failed / timeout |

### `POST /v1/music/style-lookup`

Resolve closed 音跃 styles for library tracks. Cloud looks up iTunes `primaryGenreName` first (CN/HK storefronts for CJK titles), then MusicBrainz genres/tags. Mandopop / Pop are treated as coarse language buckets and may be refined with title/album/year markers (e.g. 情歌 → 抒情情歌). Title/artist matching uses the same weak identity as recommendations. Playback-search adapters are not used: they do not return genre. NAS Agent is not involved. Optional `year` on each track improves 经典老歌.

```json
{ "tracks": [{ "title": "晴天", "artist": "周杰伦", "album": "叶惠美" }] }
```

At most 20 tracks per call. Each item may include `style` (one of the 14 closed names), `raw_genre`, and `provider` (`itunes`, `musicbrainz`). `style` is omitted when nothing mappable was found.

| Code | When |
|---|---|
| 401 | Missing/invalid key/token |
| 400 | Empty `tracks` or more than 20 tracks |
| 503 | Style lookup not initialized |

### `GET /v1/music/url`

| Param | Required |
|---|---|
| `id` | yes |
| `source` | yes |
| `br` | no (default 999) |
| `provider` | no (pin winning adapter) |
| `fresh` | no (skip adapter URL cache and ask upstream again) |

Success:

```json
{
  "url": "https://cdn.example.com/song.mp3",
  "br": 320,
  "type": "mp3",
  "size": 9843201,
  "provider": "chksz",
  "source": "tencent",
  "cover_url": "https://cdn.example.com/cover.jpg",
  "lyric": "[00:01.00]First line"
}
```

`cover_url`, `lyric`, `type`, and `size` are optional. `br` is kbps when the adapter could read it; NetEase often reports lossless as `999`. `size` is bytes. Clients must tolerate any of these fields being absent.

### `GET /v1/music/cover`

| Param | Required |
|---|---|
| `id` | yes |
| `source` | yes |
| `size` | no |
| `provider` | no |

### `GET /v1/music/lyric`

| Param | Required |
|---|---|
| `id` | yes |
| `source` | yes |
| `provider` | no |

## Updates (private)

### `GET /version.json`

Authenticated. Serves `RELEASE_DIR/version.json`.

### `GET /appcast.xml`

Authenticated. Serves `RELEASE_DIR/appcast.xml` for Sparkle on macOS.

### `GET /releases/{filename}`

Authenticated. Allow-list:

- `navidrome_player-<semver>+<build>-android.apk`
- `navidrome_player-<semver>+<build>-macos.dmg`
- `navidrome_player-<semver>+<build>-windows.zip`
- `SHA256SUMS`
- `appcast.xml`

No symlink escape from `RELEASE_DIR`.

## Auth (product surface, not Subsonic)

| Method | Path | Notes |
|---|---|---|
| POST | `/v1/auth/register` | `{username,password,email?}` → tokens |
| POST | `/v1/auth/login` | `{username,password}` → tokens |
| POST | `/v1/auth/refresh` | `{refresh_token}` → rotated tokens |

Token response:

```json
{
  "access_token": "…",
  "refresh_token": "…",
  "token_type": "bearer",
  "expires_in": 3600
}
```

## Recommendations

Contract version 1 (ported from legacy backend). Requires API key / bearer.

| Method | Path |
|---|---|
| POST | `/v1/recommendations/sessions` |
| GET | `/v1/recommendations/sessions/{session_id}/items` |
| POST | `/v1/recommendations/feedback` |
| DELETE | `/v1/recommendations/profile` |

Cloud runs **without** Navidrome library blocking (`library=None`).

## Library

Cloud forwards these to the NAS Agent using server-side `NAS_AGENT_URL` and `NAS_AGENT_KEY`. The App only needs a Cloud Bearer token.

### `POST /v1/library/import`

Same JSON body as NAS Agent `POST /v1/nas/import`. The App sends `wait: false`; Cloud forwards it and returns HTTP 202 with the NAS progress snapshot instead of waiting for the download. `wait: true` (default) stays synchronous for older clients.

Cloud does not retry a timed-out import POST. Retrying piled a second wait onto the NAS import lock and made every following song fail.

### `GET /v1/library/import/progress`

Same JSON body as NAS Agent `GET /v1/nas/import/progress`. The App polls this after a `wait: false` accept until `stage` is `completed` or `failed`.

### `POST /v1/library/delete`

Same JSON body as NAS Agent `POST /v1/songs/delete`.

| Code | Meaning |
|---|---|
| 401 | Missing/invalid Cloud token |
| 409 | Song identity already exists |
| 503 | Cloud has no NAS Agent configuration |
| 502/504 | NAS Agent unavailable or timed out |

NAS Agent still owns the files and `navidrome.db`. Cloud never mounts music volumes.
