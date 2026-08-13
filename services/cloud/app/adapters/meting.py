"""Standard Meting API adapter with multi-base failover."""

from __future__ import annotations

import hashlib
import hmac
from typing import Any
from urllib.parse import parse_qs, urlparse

import httpx

from app.adapters.base import MusicAdapter
from app.adapters.normalize import (
    extract_lyric_payload,
    extract_url_payload,
    normalize_songs,
)
from app.adapters.pool import BasePool

DEFAULT_SOURCE = "netease"
SUPPORTED_SOURCES = frozenset({"netease", "tencent", "kugou", "baidu", "kuwo"})
_TYPE_MAP = {"lyric": "lrc", "cover": "pic"}
_SIGNED_TYPES = frozenset({"url", "pic", "lrc"})


def _resource_id(item: dict[str, Any]) -> str | None:
    for key in ("id", "songid", "song_id"):
        value = item.get(key)
        if value not in (None, ""):
            return str(value)
    for key in ("url", "lrc", "pic"):
        value = item.get(key)
        if not isinstance(value, str):
            continue
        resource_id = parse_qs(urlparse(value).query).get("id")
        if resource_id and resource_id[0]:
            return resource_id[0]
    return None


def _search_payload(response: httpx.Response) -> Any:
    payload = response.json()
    if isinstance(payload, dict):
        for key in ("result", "data", "songs", "list"):
            if isinstance(payload.get(key), list):
                return payload[key]
    return payload


class MetingAdapter(MusicAdapter):
    name = "meting"

    def __init__(
        self,
        client: httpx.AsyncClient,
        bases: tuple[str, ...],
        *,
        token: str = "",
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
        self._token = token
        self._timeout = timeout

    def _params(self, *, kind: str, source: str, value: str) -> dict[str, str]:
        meting_type = _TYPE_MAP.get(kind, kind)
        params = {"server": source, "type": meting_type, "id": value}
        if self._token and meting_type in _SIGNED_TYPES:
            message = f"{source}{meting_type}{value}".encode()
            params["auth"] = hmac.new(
                self._token.encode(), message, hashlib.sha1
            ).hexdigest()
        return params

    async def _request(self, *, kind: str, source: str, value: str) -> httpx.Response:
        return await self._pool.request(
            params=self._params(kind=kind, source=source, value=value),
            attach_nonce=False,
            follow_redirects=False,
            allowed_redirect_statuses=(
                frozenset({302}) if kind in {"url", "pic"} else frozenset()
            ),
        )

    async def search(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> list[dict[str, Any]]:
        resolved_source = source or DEFAULT_SOURCE
        if resolved_source not in SUPPORTED_SOURCES or page > 1:
            return []
        response = await self._request(
            kind="search", source=resolved_source, value=query
        )
        payload = _search_payload(response)
        if isinstance(payload, list):
            payload = [
                {
                    **item,
                    "id": _resource_id(item),
                    "artist": item.get("artist") or item.get("author"),
                }
                for item in payload
                if isinstance(item, dict) and _resource_id(item)
            ]
        songs = normalize_songs(
            payload, provider=self.name, default_source=resolved_source
        )
        return songs[:count]

    async def get_url(self, id: str, *, source: str, br: int) -> dict[str, Any]:
        response = await self._request(kind="url", source=source, value=id)
        url = response.headers.get("location")
        if not url:
            try:
                url = extract_url_payload(response.json())
            except ValueError:
                url = extract_url_payload(response.text)
        if not url:
            raise httpx.HTTPError("meting url empty")
        return {"url": url, "br": br, "provider": self.name, "source": source}

    async def get_cover(self, id: str, *, source: str, size: int) -> dict[str, Any]:
        response = await self._request(kind="pic", source=source, value=id)
        url = response.headers.get("location")
        if not url:
            try:
                url = extract_url_payload(response.json())
            except ValueError:
                url = extract_url_payload(response.text)
        if not url:
            raise httpx.HTTPError("meting cover empty")
        return {"url": url, "provider": self.name, "source": source}

    async def get_lyric(self, id: str, *, source: str) -> dict[str, Any]:
        response = await self._request(kind="lrc", source=source, value=id)
        try:
            lyric = extract_lyric_payload(response.json())
        except ValueError:
            lyric = response.text
        return {"lyric": lyric, "provider": self.name, "source": source}

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
