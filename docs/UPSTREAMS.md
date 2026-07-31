# Upstream music adapters

Cloud is the product. Upstreams are **HTTP clients** only.

## 1. Gdstudio / Solara-shaped

| Item | Value |
|---|---|
| Historical default | `https://music-api.gdstudio.xyz/api.php` |
| Env | `GDSTUDIO_API_BASE_URLS` (comma-separated mirrors) |
| Shape | Query params roughly: `types`, `source`, `name`/`id`, `count`, `pages`, `br`, `size`, random `s` |
| Types | `search`, `url`, `pic`, `lyric` |
| Code stub | `app/adapters/gdstudio.py` |
| Old reference | `navidrome-backend/app/services/music_proxy.py` |

Platform `source` values used historically by the app: `netease`, `kuwo`, `joox`, `migu`, `kugou` (availability depends on upstream).

## 2. Meting / OpenMusic-shaped

| Item | Value |
|---|---|
| Runtime project | https://github.com/metowolf/Meting-API |
| Public compatibility probe | `https://meting.mikus.ink/api` |
| OpenMusic reference | https://github.com/qq01-hub/openmusic |
| Env | `METING_API_BASE_URLS`, optional `METING_API_TOKEN` |
| Code | `app/adapters/meting.py` |

Standard Meting search returns `title` / `author` plus signed resource URLs. URL and cover endpoints respond with `302 Location`; lyrics respond as text. Search has one stable result window, so page 2+ is terminal. Self-hosted NetEase playback needs a maintained cookie; do not promote an anonymous self-host until its playability probe passes.

## Multi-upstream policy

1. Configure one or more **bases** per adapter.
2. Order adapter families with `MUSIC_ADAPTER_ORDER`; the first non-empty adapter wins.
3. Fail over bases with cooldown (`UPSTREAM_COOLDOWN_SECONDS`).
4. The first search page tries the requested source first, then `MUSIC_SEARCH_SOURCES` in order; later pages stay pinned to the requested source, or the first configured source when omitted.
5. Results are never merged. Playback URL should prefer the same `provider` and `source` that produced the search hit, then fall back to the other adapter on failure.

## Legal / ops note

Third-party music APIs may break, rate-limit, or violate third-party ToS. Adapters must be swappable and kill-switchable via env without app store rebuilds when possible.
