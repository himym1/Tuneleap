"""Meting / OpenMusic-shaped adapter.

Supports common public Meting PHP endpoints:
  ?server=<source>&type=search|url|pic|lrc&id=<q|id>
and gdstudio-compatible mirrors if someone points METING bases at them.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.adapters.base import MusicAdapter
from app.adapters.normalize import (
    extract_lyric_payload,
    extract_url_payload,
    normalize_songs,
)
from app.adapters.pool import BasePool

DEFAULT_SOURCE = "netease"
_TYPE_MAP = {
    "search": "search",
    "url": "url",
    "pic": "pic",
    "cover": "pic",
    "lyric": "lrc",
    "lrc": "lrc",
}


class MetingAdapter(MusicAdapter):
    name = "meting"

    def __init__(
        self,
        client: httpx.AsyncClient,
        bases: tuple[str, ...],
        *,
        cooldown_seconds: int = 60,
        timeout: float = 30.0,
    ):
        self._pool = BasePool(
            client,
            bases,
            cooldown_seconds=cooldown_seconds,
            timeout=timeout,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        self._client = client
        self._timeout = timeout

    async def _meting(
        self, *, kind: str, source: str, value: str, extra: dict[str, Any] | None = None
    ) -> Any:
        params: dict[str, Any] = {
            "server": source,
            "type": _TYPE_MAP.get(kind, kind),
            "id": value,
        }
        if extra:
            params.update(extra)
        # Also send gdstudio-shaped aliases so dual-compatible hosts work.
        if kind == "search":
            params.setdefault("types", "search")
            params.setdefault("source", source)
            params.setdefault("name", value)
        elif kind == "url":
            params.setdefault("types", "url")
            params.setdefault("source", source)
        elif kind in {"pic", "cover"}:
            params.setdefault("types", "pic")
            params.setdefault("source", source)
        elif kind in {"lyric", "lrc"}:
            params.setdefault("types", "lyric")
            params.setdefault("source", source)
        return await self._pool.request_json(params=params, attach_nonce=True)

    async def search(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> list[dict[str, Any]]:
        payload = await self._meting(
            kind="search",
            source=source or DEFAULT_SOURCE,
            value=query,
            extra={"count": count, "pages": page, "page": page},
        )
        # Meting often returns {"result":[...]} or bare list.
        if isinstance(payload, dict):
            for key in ("result", "data", "songs", "list"):
                if isinstance(payload.get(key), list):
                    payload = payload[key]
                    break
        songs = normalize_songs(
            payload, provider=self.name, default_source=source or DEFAULT_SOURCE
        )
        return songs[:count]

    async def get_url(self, id: str, *, source: str, br: int) -> dict[str, Any]:
        payload = await self._meting(
            kind="url", source=source, value=id, extra={"br": br}
        )
        url = extract_url_payload(payload)
        if not url:
            raise httpx.HTTPError("meting url empty")
        return {"url": url, "br": br, "provider": self.name, "source": source}

    async def get_cover(self, id: str, *, source: str, size: int) -> dict[str, Any]:
        payload = await self._meting(
            kind="pic", source=source, value=id, extra={"size": size}
        )
        url = extract_url_payload(payload)
        if not url:
            raise httpx.HTTPError("meting cover empty")
        return {"url": url, "provider": self.name, "source": source}

    async def get_lyric(self, id: str, *, source: str) -> dict[str, Any]:
        payload = await self._meting(kind="lrc", source=source, value=id)
        return {
            "lyric": extract_lyric_payload(payload),
            "provider": self.name,
            "source": source,
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
            response.raise_for_status()
            async for chunk in response.aiter_bytes():
                return bool(chunk)
        return False
