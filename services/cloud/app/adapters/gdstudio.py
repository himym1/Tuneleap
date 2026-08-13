"""Gdstudio / Solara-shaped adapter with multi-base failover."""

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


class GdstudioAdapter(MusicAdapter):
    name = "gdstudio"
    supported_sources = frozenset(
        {"netease", "kugou", "migu", "joox", "kuwo"}
    )

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
        )
        self._client = client
        self._timeout = timeout

    async def search(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> list[dict[str, Any]]:
        payload = await self._pool.request_json(
            params={
                "types": "search",
                "source": source or DEFAULT_SOURCE,
                "name": query,
                "count": count,
                "pages": page,
            }
        )
        return normalize_songs(
            payload, provider=self.name, default_source=source or DEFAULT_SOURCE
        )

    async def get_url(self, id: str, *, source: str, br: int) -> dict[str, Any]:
        payload = await self._pool.request_json(
            params={
                "types": "url",
                "id": id,
                "source": source,
                "br": br,
            }
        )
        url = extract_url_payload(payload)
        if not url:
            raise httpx.HTTPError("gdstudio url empty")
        resolved_br = br
        if isinstance(payload, dict) and payload.get("br") is not None:
            try:
                resolved_br = int(payload["br"])
            except (TypeError, ValueError):
                resolved_br = br
        return {
            "url": url,
            "br": resolved_br,
            "provider": self.name,
            "source": source,
        }

    async def get_cover(self, id: str, *, source: str, size: int) -> dict[str, Any]:
        payload = await self._pool.request_json(
            params={
                "types": "pic",
                "id": id,
                "source": source,
                "size": size,
            }
        )
        url = extract_url_payload(payload)
        if not url:
            raise httpx.HTTPError("gdstudio cover empty")
        return {"url": url, "provider": self.name, "source": source}

    async def get_lyric(self, id: str, *, source: str) -> dict[str, Any]:
        payload = await self._pool.request_json(
            params={
                "types": "lyric",
                "id": id,
                "source": source,
            }
        )
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
            headers={
                "Range": "bytes=0-0",
                "User-Agent": "Mozilla/5.0",
                "Referer": "https://music.gdstudio.xyz/",
            },
            follow_redirects=True,
            timeout=self._timeout,
        ) as response:
            response.raise_for_status()
            async for chunk in response.aiter_bytes():
                return bool(chunk)
        return False
