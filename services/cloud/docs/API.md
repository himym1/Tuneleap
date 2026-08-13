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

### `GET /v1/music/search`

| Param | Required | Notes |
|---|---|---|
| `q` | yes | User search string |
| `source` | no | Platform id: `netease`, `tencent` (`qq` accepted), `kugou`, `migu`, `joox`, `kuwo`. When set, search stays on that platform. When omitted, Cloud walks `MUSIC_SEARCH_SOURCES`. |
| `count` | no | default 20, max 50 |
| `page` | no | default 1 |

An explicit `source` is pinned. Do not send a source if you want first-success across configured platforms. For `page > 1` without `source`, Cloud stays on the first configured search source.

Success:

```json
{
  "query": "hello",
  "provider": "gdstudio",
  "source": "netease",
  "strategy": "first-success",
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
| 502/504 | All upstreams failed / timeout |

### `GET /v1/music/url`

| Param | Required |
|---|---|
| `id` | yes |
| `source` | yes |
| `br` | no (default 999) |
| `provider` | no (pin winning adapter) |

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

## Out of scope on this host

- `POST /v1/nas/import`
- `POST /v1/songs/delete`

Those live on **navidrome-nas-agent**.
