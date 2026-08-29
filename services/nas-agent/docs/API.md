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
    "source": "netease",
    "genre": "华语流行"
  },
  "force": false,
  "wait": true
}
```

Compatibility inputs: `picUrl` aliases `pic_url`, and `song.name` aliases `song.title`. Supported audio extensions are `.mp3`, `.flac`, `.m4a`, and `.mp4`. Lyrics are saved beside the audio as `.lrc`.

`wait` defaults to `true` and blocks until the file is on disk. The App sends `wait: false` so Cloud can return immediately; poll `GET /v1/nas/import/progress` until `stage` is `completed` or `failed`. A `wait: false` accept is HTTP 202. The same filename already in flight is idempotent. A different file while the lock is held returns 409.

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

If the media CDN stays below about 128 KB/s after 8 seconds and a large remainder is still outstanding, the agent aborts with 502 `media upstream too slow` so the App can ask Cloud for a fresh playback URL (often a different node).

Cover download/tagging is best effort: an invalid or unavailable cover does not fail the audio import.

## `GET /v1/nas/import/progress`

Live snapshot of the single in-flight import. The agent holds one import lock, so at most one transfer is active. The response never includes the media URL.

```json
{
  "active": true,
  "filename": "solara_netease_123.flac",
  "bytes_received": 12582912,
  "bytes_total": 161265397,
  "speed_bps": 49152.0,
  "stage": "downloading"
}
```

`bytes_total` is omitted when the upstream did not send `Content-Length`. `stage` is `idle`, `downloading`, `finishing`, `completed`, or `failed`. Terminal snapshots keep `filename` / `error` / `message` until the next import starts so the App can finish polling. When nothing has run yet, `active` is `false` and the counters are zero.

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

## `POST /v1/nas/library-audit`

Starts a single in-flight fast library audit. The agent reads active `media_file` rows and checks file presence, format/bitrate/duration, and metadata (empty or placeholder title/artist/album, garbled text, missing cover/year/lyrics, missing track numbers on multi-track albums, and library-vs-file tag mismatch). It does not decode audio or run a spectral analysis. It does not guess a “wrong” artist or album without one of those signals.

Optional JSON body overrides the default thresholds. Defaults stay `320` / `500` / `3`. Out-of-range values return 422.

```json
{
  "low_bitrate_kbps": 320,
  "suspect_lossless_kbps": 500,
  "duration_tolerance_seconds": 3
}
```

| Field | Default | Allowed |
|---|---|---|
| `low_bitrate_kbps` | 320 | 64–320 |
| `suspect_lossless_kbps` | 500 | 200–800 |
| `duration_tolerance_seconds` | 3 | 1–15 |

A running audit returns HTTP 409. Missing `navidrome.db` returns 503. A successful accept is HTTP 202.

The last completed or cancelled report is written next to `navidrome.db` as `library-audit.json` so a restart can restore findings. In-flight scans are not persisted. Findings never include host paths.

```json
{
  "active": true,
  "stage": "scanning",
  "scanned": 0,
  "total": 0,
  "error": null,
  "message": "started",
  "summary": {
    "scanned": 0,
    "passed": 0,
    "issues": 0,
    "missing": 0,
    "low_bitrate": 0,
    "suspect_transcode": 0,
    "duplicate_version": 0,
    "missing_title": 0,
    "missing_artist": 0,
    "missing_album": 0,
    "suspicious_text": 0,
    "missing_cover": 0,
    "missing_track": 0,
    "missing_year": 0,
    "missing_lyrics": 0,
    "tag_mismatch": 0
  }
}
```

`stage` is `idle`, `scanning`, `deep_scanning`, `completed`, `failed`, or `cancelled`. Findings never include host paths.

## `GET /v1/nas/library-audit`

Live snapshot of the current or last audit. When nothing has run yet, `active` is `false` and `stage` is `idle`. After a restart this is the last persisted report, if one exists.

## `GET /v1/nas/library-audit/findings`

Paginated findings from the last audit. `offset` defaults to 0; `limit` defaults to 50 and is capped at 200. Optional `code` filters to `missing`, `low_bitrate`, `suspect_transcode`, `duplicate_version`, `lossy_transcode`, `fake_hires`, `deep_failed`, `missing_title`, `missing_artist`, `missing_album`, `suspicious_text`, `missing_cover`, `missing_track`, `missing_year`, `missing_lyrics`, or `tag_mismatch`. `missing_track` is only raised when the same album has two or more tracks and this row has no track number. `missing_lyrics` uses the Navidrome lyrics field plus a same-name `.lrc` or embedded lyrics. `tag_mismatch` compares library title/artist/album with embedded file tags after normalization.

```json
{
  "items": [
    {
      "song_id": "id1",
      "title": "Track",
      "artist": "Artist",
      "album": "Album",
      "album_id": "al1",
      "suffix": "mp3",
      "bit_rate": 128,
      "duration": 210,
      "sample_rate": 44100,
      "codes": ["low_bitrate"],
      "severity": "warn",
      "deep_error": null
    }
  ],
  "offset": 0,
  "limit": 50,
  "total": 1
}
```

`deep_error` is set only when a finding includes `deep_failed`. Values are `unresolved_path`, `invalid_sample_rate`, `decode_failed`, `too_short`, `unsupported_format`, or `unknown`. Host paths are never returned.

## `POST /v1/nas/library-audit/deep`

Starts a spectral deep scan. The default `scope` is `findings`: only lossless files already listed by a fast audit. `scope=lossless` checks every lossless file. `song_ids` limits the run to those Navidrome ids.

Each target is decoded at a few positions and FFT-analyzed. The agent looks for a lossy high-frequency cutoff and for Hi-Res containers whose energy stops near the CD wall. Fast-scan `suspect_transcode` is dropped when the spectrum looks genuine. Host paths are never returned.

A running audit returns HTTP 409. `scope=findings` with no prior fast audit returns 400.

```json
{
  "scope": "findings",
  "song_ids": []
}
```

## `POST /v1/nas/library-audit/cancel`

Requests cancellation of the in-flight fast or deep audit. The next snapshot uses `stage=cancelled` and keeps any findings already produced.

## `POST /v1/nas/media-tags`

Updates tags, cover, and/or lyrics on an existing library file identified by Navidrome `song_id`. Does not download a new audio file. Host paths are never returned.

```json
{
  "song_id": "id1",
  "pic_url": "https://cdn.example/cover.jpg",
  "lyric": "[00:01.00]First line",
  "song": {
    "title": "Track",
    "artist": "Artist",
    "album": "Album",
    "track": 1,
    "year": 2026,
    "genre": "华语流行"
  }
}
```

Only provided song fields are written. `genre` is optional, stripped, and capped at 64 characters; it is written as MP3 `TCON`, FLAC `GENRE`, or MP4 `©gen`. Missing song, unknown id, or missing media file returns 404. Unsupported extensions return 400.

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
