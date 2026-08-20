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

Standard Meting search returns `title` / `author` plus signed resource URLs. URL and cover endpoints respond with `302 Location`; lyrics respond as text. Search has one stable result window, so page 2+ is terminal. Cloud search then fail over to an adapter that can paginate that platform (NetEase GDStudio / ChKSz). Self-hosted NetEase playback needs a maintained cookie; do not promote an anonymous self-host until its playability probe passes.

## 3. ChKSz

| Item | Value |
|---|---|
| Default base | `https://api.chksz.com` |
| Env | `CHKSZ_API_BASE_URL`, `CHKSZ_API_KEY` |
| Code | `app/adapters/chksz.py` |
| Platforms | `netease`, `tencent` (QQ), `kugou` only |
| Auth | query `apikey`; never log the key |

Search shapes differ: NetEase is `/api/163_search` with `data.songs` plus `limit`/`offset`. QQ / Kugou are “search or parse” endpoints and take `num` for the first window. QQ and Kugou have no stable page 2. Adapter is omitted when the key is empty. Keep it **after** Meting and GDStudio — it has a daily quota and 20 RPM.

Each adapter exposes a `SearchWindow` (`max_count`, `paginates`). Cloud `/v1/music/capabilities` publishes the merged product window; search `has_more` uses that policy, not `len(items) == count`. Artist-like queries pull two extra pages from the winning paginating adapter, then rank the artist’s own catalog above collabs, Live, covers, and beats.

## Multi-upstream policy

1. Configure one or more **bases** per adapter.
2. Order adapter families with `MUSIC_ADAPTER_ORDER`; the first non-empty adapter wins.
3. Fail over bases with cooldown (`UPSTREAM_COOLDOWN_SECONDS`).
4. If the client sends `source`, stay on that platform. If omitted, walk `MUSIC_SEARCH_SOURCES`. Adapter failover still applies inside the chosen platform.
5. Results are never merged. Playback URL should prefer the same `provider` and `source` that produced the search hit, then fall back to the other adapter on failure.

## Legal / ops note

Third-party music APIs may break, rate-limit, or violate third-party ToS. Adapters must be swappable and kill-switchable via env without app store rebuilds when possible.
