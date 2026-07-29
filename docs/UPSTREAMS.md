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
| Reference project | https://github.com/qq01-hub/openmusic |
| Useful pieces | Meting HTTP, custom music API templates, playable URL probe ideas |
| Not used | Room manager, Socket.IO, Redis, chat, TV, admin portal as product core |
| Env | `METING_API_BASE_URLS` |
| Code stub | `app/adapters/meting.py` |

When implementing, treat OpenMusic server files as **protocol documentation**, not something to vendor wholesale.

## Multi-upstream policy

1. Configure one or more **bases** per adapter.
2. Failover with cooldown (`UPSTREAM_COOLDOWN_SECONDS`).
3. Cross-adapter policy: still **first non-empty wins** for search (unless you later add explicit user source picker that still returns one list).
4. Playback URL should prefer the same `provider` that produced the search hit.

## Legal / ops note

Third-party music APIs may break, rate-limit, or violate third-party ToS. Adapters must be swappable and kill-switchable via env without app store rebuilds when possible.
