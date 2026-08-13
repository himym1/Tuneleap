# navidrome-nas-agent — HTTP API

Base URL example: `http://192.168.x.x:8503` or a Tailscale address.

All endpoints except `/health` require `X-API-Key: <NAS_AGENT_KEY>`. Query-string credentials are rejected.

## `GET /health`

Unauthenticated liveness/configuration response:

```json
{
  "status": "ok",
  "service": "navidrome-nas-agent",
  "version": "0.1.0",
  "music_dir_configured": true,
  "download_dir_configured": true,
  "database_configured": true
}
```

The endpoint remains HTTP 200 for liveness; inspect the booleans before enabling imports or deletes.

## `POST /v1/nas/import`

```json
{
  "url": "https://cdn.example/audio.flac",
  "filename": "solara_netease_123.flac",
  "pic_url": "https://cdn.example/cover.jpg",
  "lyric": "[00:01.00]First line",
  "song": {
    "title": "Track",
    "artist": "Artist",
    "album": "Album",
    "track": 1,
    "year": 2026,
    "source": "netease"
  },
  "force": false
}
```

Compatibility inputs: `picUrl` aliases `pic_url`, and `song.name` aliases `song.title`. Supported audio extensions are `.mp3`, `.flac`, `.m4a`, and `.mp4`. Lyrics are saved beside the audio as `.lrc`.

Success:

```json
{
  "ok": true,
  "path": "/music/download/solara_netease_123.flac",
  "message": "imported"
}
```

The agent applies two duplicate rules while holding the import lock:

- The same target filename is idempotent and returns `message: "already imported"`.
- A different filename with the same normalized title/artist identity returns HTTP 409 and is not downloaded.
- Set `force: true` only after explicit user confirmation to bypass the identity check.

| Code | Meaning |
|---|---|
| 400 | Invalid URL, filename, extension, or path configuration |
| 401 | Missing/invalid agent key |
| 409 | Song identity already exists; retry with `force: true` only after confirmation |
| 413 | Audio exceeds `MAX_DOWNLOAD_BYTES` |
| 502 | Upstream status, redirect, or content failure |
| 504 | Upstream timeout |
| 507 | Reserved free-space threshold would be crossed |

Cover download/tagging is best effort: an invalid or unavailable cover does not fail the audio import.

## `GET /v1/songs/library-identities`

Returns normalized title/artist identities for active Navidrome library songs. `navidrome-cloud` uses this read-only endpoint to suppress songs already stored on the NAS from recommendations.

```json
{
  "count": 2,
  "identities": ["song\u001fartist", "another song\u001fanother artist"]
}
```

Missing database/table configuration returns 503. The endpoint never returns file paths or opens write transactions.

## `POST /v1/songs/delete`

```json
{ "song_ids": ["id1", "id2"] }
```

IDs must be unique; 1–50 are accepted. The service stages regular audio and `.lrc` files, deletes known related rows, commits, then removes the staged files.

```json
{
  "deleted": 1,
  "skipped": 1,
  "errors": 0,
  "msg": "deleted 1, skipped 1, errors 0",
  "details": []
}
```

Missing database/table configuration returns 503. Unknown IDs are skipped. Unsafe DB paths or per-song file/DB failures appear in `details` and increment `errors`.

## `POST /v1/nas/scan`

Triggers Subsonic `startScan` when `NAVIDROME_URL`, `NAVIDROME_USER`, and `NAVIDROME_PASSWORD` are configured. Passwords are converted to the Subsonic salt/token form and are not sent as plaintext.

| Code | Meaning |
|---|---|
| 200 | Scan accepted |
| 503 | Scan credentials not configured |
| 502/504 | Navidrome rejected, failed, or timed out |

## Not exposed

| Path | Owner |
|---|---|
| `/v1/music/*` | `navidrome-cloud` |
| `/v1/auth/*` | `navidrome-cloud` |
| `/version.json` | `navidrome-cloud` |
| `/api/nas-download` | Legacy backend only; migrate the Flutter client |
