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

### `GET /v1/music/url`

| Param | Required |
|---|---|
| `id` | yes |
| `source` | yes |
| `br` | no (default 999) |
| `provider` | no (pin winning adapter) |

Success:

```json
{
  "url": "https://cdn.example.com/song.mp3",
  "br": 320,
  "provider": "chksz",
  "source": "tencent",
  "cover_url": "https://cdn.example.com/cover.jpg",
  "lyric": "[00:01.00]First line"
}
```

`cover_url` and `lyric` are optional. An adapter may return them when resolving the playback URL already produced that metadata; clients must tolerate either field being absent.

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

### `GET /releases/{filename}`

Authenticated. Allow-list:

- `navidrome_player-<semver>+<build>-android.apk`
- `navidrome_player-<semver>+<build>-macos.dmg`
- `SHA256SUMS`

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

Same JSON body as NAS Agent `POST /v1/nas/import`.

### `POST /v1/library/delete`

Same JSON body as NAS Agent `POST /v1/songs/delete`.

| Code | Meaning |
|---|---|
| 401 | Missing/invalid Cloud token |
| 409 | Song identity already exists |
| 503 | Cloud has no NAS Agent configuration |
| 502/504 | NAS Agent unavailable or timed out |

NAS Agent still owns the files and `navidrome.db`. Cloud never mounts music volumes.
