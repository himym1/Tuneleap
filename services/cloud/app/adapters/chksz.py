"""ChKSz adapter: NetEase / QQ / Kugou only. Never first in MUSIC_ADAPTER_ORDER."""

from __future__ import annotations

from typing import Any

import httpx

from app.adapters.base import MusicAdapter
from app.adapters.normalize import extract_lyric_payload, normalize_songs
from app.core.sources import canonicalize_music_source

SUPPORTED_SOURCES = frozenset({"netease", "tencent", "kugou"})
_QQ_PAGE_SIZE_MAX = 50


def _netease_level(br: int) -> str:
    if br >= 999:
        return "jymaster"
    if br >= 740:
        return "hires"
    if br >= 320:
        return "exhigh"
    return "standard"


def _common_size(br: int) -> str:
    if br >= 999:
        return "master"
    if br >= 740:
        return "hires"
    if br >= 320:
        return "320k"
    return "128k"


def _search_items(payload: dict[str, Any]) -> list[dict[str, Any]]:
    data = payload.get("data")
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if isinstance(data, dict):
        for key in ("songs", "list", "records"):
            items = data.get(key)
            if isinstance(items, list):
                return [item for item in items if isinstance(item, dict)]
    items = payload.get("list")
    if isinstance(items, list):
        return [item for item in items if isinstance(item, dict)]
    return []


def _prepare_item(raw: dict[str, Any], *, source: str) -> dict[str, Any]:
    prepared = dict(raw)
    song_id = raw.get("id") or raw.get("mid") or raw.get("songid")
    if song_id not in (None, ""):
        prepared["id"] = song_id
    artist = raw.get("artist") or raw.get("artists") or raw.get("singer")
    if artist not in (None, ""):
        prepared["artist"] = artist
    cover = raw.get("picUrl") or raw.get("cover")
    if isinstance(cover, str) and cover.startswith(("http://", "https://")):
        prepared["cover_id"] = cover
    prepared["source"] = source
    return prepared


def _payload_url(payload: dict[str, Any]) -> str | None:
    data = payload.get("data")
    if isinstance(data, dict):
        url = data.get("url")
        if isinstance(url, str) and url.strip():
            return url.strip()
    url = payload.get("url")
    if isinstance(url, str) and url.strip():
        return url.strip()
    return None


def _is_http_url(value: str) -> bool:
    return value.startswith(("http://", "https://"))


class ChkszAdapter(MusicAdapter):
    name = "chksz"
    supported_sources = SUPPORTED_SOURCES

    def __init__(
        self,
        client: httpx.AsyncClient,
        base_url: str,
        api_key: str,
        *,
        timeout: float = 30.0,
    ) -> None:
        self._client = client
        self._base = base_url.rstrip("/")
        self._api_key = api_key
        self._timeout = timeout

    def _resolve_source(self, source: str | None) -> str | None:
        resolved = canonicalize_music_source(source)
        if resolved not in SUPPORTED_SOURCES:
            return None
        return resolved

    async def _get_json(self, path: str, params: dict[str, Any]) -> dict[str, Any]:
        query = {key: value for key, value in params.items() if value is not None}
        query["apikey"] = self._api_key
        response = await self._client.get(
            f"{self._base}{path}",
            params=query,
            headers={"Accept": "application/json", "User-Agent": "Mozilla/5.0"},
            timeout=self._timeout,
        )
        if response.status_code >= 400:
            response.raise_for_status()
        try:
            payload = response.json()
        except ValueError as exc:
            raise httpx.HTTPError("chksz invalid json") from exc
        if not isinstance(payload, dict):
            raise httpx.HTTPError("chksz invalid payload")
        code = payload.get("code")
        if code not in (200, "200", None):
            raise httpx.HTTPError("chksz upstream rejected the request")
        return payload

    async def search(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> list[dict[str, Any]]:
        resolved = self._resolve_source(source)
        if resolved is None or page < 1:
            return []
        if resolved == "netease":
            payload = await self._get_json(
                "/api/163_search",
                {
                    "keyword": query,
                    "limit": count,
                    "offset": (page - 1) * count,
                },
            )
        elif page > 1:
            return []
        elif resolved == "tencent":
            payload = await self._get_json(
                "/api/qq_music",
                {
                    "msg": query,
                    "num": min(max(count, 1), _QQ_PAGE_SIZE_MAX),
                    "type": "json",
                },
            )
        else:
            payload = await self._get_json(
                "/api/kugou_music",
                {"msg": query, "type": "json"},
            )
        items = [_prepare_item(item, source=resolved) for item in _search_items(payload)]
        return normalize_songs(items, provider=self.name, default_source=resolved)[:count]

    async def get_url(self, id: str, *, source: str, br: int) -> dict[str, Any]:
        resolved = self._resolve_source(source)
        if resolved is None:
            raise httpx.HTTPError("chksz unsupported source")
        if resolved == "netease":
            payload = await self._get_json(
                "/api/163_music",
                {"id": id, "level": _netease_level(br), "type": "json"},
            )
        elif resolved == "tencent":
            payload = await self._get_json(
                "/api/qq_music",
                {"mid": id, "size": _common_size(br), "type": "json"},
            )
        else:
            payload = await self._get_json(
                "/api/kugou_music",
                {"id": id, "size": _common_size(br), "type": "json"},
            )
        url = _payload_url(payload)
        if not url:
            raise httpx.HTTPError("chksz url empty")
        return {"url": url, "br": br, "provider": self.name, "source": resolved}

    async def get_cover(self, id: str, *, source: str, size: int) -> dict[str, Any]:
        resolved = self._resolve_source(source)
        if resolved is None:
            raise httpx.HTTPError("chksz unsupported source")
        if _is_http_url(id):
            return {"url": id, "provider": self.name, "source": resolved}
        raise httpx.HTTPError("chksz cover empty")

    async def get_lyric(self, id: str, *, source: str) -> dict[str, Any]:
        resolved = self._resolve_source(source)
        if resolved is None:
            raise httpx.HTTPError("chksz unsupported source")
        if resolved == "netease":
            payload = await self._get_json("/api/163_lyric", {"id": id})
            data = payload.get("data")
            lyric = extract_lyric_payload(data if isinstance(data, dict) else payload)
            return {"lyric": lyric, "provider": self.name, "source": resolved}
        if resolved == "tencent":
            payload = await self._get_json(
                "/api/qq_music",
                {"mid": id, "size": "128k", "type": "json"},
            )
        else:
            payload = await self._get_json(
                "/api/kugou_music",
                {"id": id, "size": "128k", "type": "json"},
            )
        return {
            "lyric": extract_lyric_payload(payload),
            "provider": self.name,
            "source": resolved,
        }

    async def is_playable(self, id: str, *, source: str, br: int = 999) -> bool:
        result = await self.get_url(id, source=source, br=br)
        url = result.get("url")
        if not isinstance(url, str) or not url.strip():
            return False
        async with self._client.stream(
            "GET",
            url,
            headers={"Range": "bytes=0-0", "User-Agent": "Mozilla/5.0"},
            follow_redirects=True,
            timeout=self._timeout,
        ) as response:
            if response.status_code >= 400 and response.status_code != 206:
                response.raise_for_status()
            async for chunk in response.aiter_bytes():
                return bool(chunk)
        return False
