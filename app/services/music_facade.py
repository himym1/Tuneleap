"""Music facade: first-success across adapters + recommendation source bridge."""

from __future__ import annotations

import asyncio
from typing import Any

import httpx

from app.adapters.base import MusicAdapter
from app.adapters.gdstudio import GdstudioAdapter
from app.adapters.meting import MetingAdapter
from app.core.config import Settings
from app.models.schemas import (
    CoverResponse,
    LyricResponse,
    SearchResponse,
    SongDTO,
    UrlResponse,
)


class MusicFacade:
    def __init__(self, client: httpx.AsyncClient, settings: Settings):
        self._client = client
        self._settings = settings
        self._adapters: list[MusicAdapter] = []
        timeout = settings.http_timeout_seconds
        cooldown = settings.upstream_cooldown_seconds
        if settings.gdstudio_bases:
            self._adapters.append(
                GdstudioAdapter(
                    client,
                    settings.gdstudio_bases,
                    cooldown_seconds=cooldown,
                    timeout=timeout,
                )
            )
        if settings.meting_bases:
            self._adapters.append(
                MetingAdapter(
                    client,
                    settings.meting_bases,
                    cooldown_seconds=cooldown,
                    timeout=timeout,
                )
            )

    @property
    def adapters(self) -> list[MusicAdapter]:
        return list(self._adapters)

    def _adapter_by_name(self, provider: str | None) -> MusicAdapter | None:
        if not provider:
            return None
        for adapter in self._adapters:
            if adapter.name == provider:
                return adapter
        return None

    async def search_first_success(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> SearchResponse:
        if not self._adapters:
            raise httpx.HTTPError("no music adapters configured")

        strategy = (self._settings.upstream_strategy or "ordered").lower()
        if strategy == "race" and len(self._adapters) > 1:
            return await self._search_race(query, source=source, count=count, page=page)
        return await self._search_ordered(query, source=source, count=count, page=page)

    async def _search_ordered(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> SearchResponse:
        last_error: Exception | None = None
        empty_adapter: MusicAdapter | None = None
        for adapter in self._adapters:
            try:
                items = await adapter.search(
                    query, source=source, count=count, page=page
                )
            except Exception as exc:  # noqa: BLE001 - failover across adapters
                last_error = exc
                continue
            if items:
                songs = [SongDTO.model_validate(item) for item in items]
                return SearchResponse(
                    query=query,
                    provider=adapter.name,
                    source=source or (songs[0].source if songs else None),
                    items=songs,
                    strategy="first-success",
                )
            empty_adapter = adapter
        if empty_adapter is not None:
            return SearchResponse(
                query=query,
                provider=empty_adapter.name,
                source=source,
                items=[],
                strategy="first-success-empty",
            )
        if last_error is not None:
            raise last_error
        raise httpx.HTTPError("all music adapters failed")

    async def _search_race(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> SearchResponse:
        async def run(
            adapter: MusicAdapter,
        ) -> tuple[MusicAdapter, list[dict[str, Any]]]:
            items = await adapter.search(query, source=source, count=count, page=page)
            return adapter, items

        tasks = [asyncio.create_task(run(adapter)) for adapter in self._adapters]
        last_error: Exception | None = None
        empty_adapter: MusicAdapter | None = None
        try:
            for finished in asyncio.as_completed(tasks):
                try:
                    adapter, items = await finished
                except Exception as exc:  # noqa: BLE001
                    last_error = exc
                    continue
                if not items:
                    empty_adapter = adapter
                    continue
                for task in tasks:
                    if not task.done():
                        task.cancel()
                if tasks:
                    await asyncio.gather(*tasks, return_exceptions=True)
                songs = [SongDTO.model_validate(item) for item in items]
                return SearchResponse(
                    query=query,
                    provider=adapter.name,
                    source=source or (songs[0].source if songs else None),
                    items=songs,
                    strategy="first-success-race",
                )
        finally:
            for task in tasks:
                if not task.done():
                    task.cancel()
            if tasks:
                await asyncio.gather(*tasks, return_exceptions=True)
        if empty_adapter is not None:
            return SearchResponse(
                query=query,
                provider=empty_adapter.name,
                source=source,
                items=[],
                strategy="first-success-race-empty",
            )
        if last_error is not None:
            raise last_error
        raise httpx.HTTPError("all music adapters failed")

    async def get_url(
        self, id: str, *, source: str, br: int, provider: str | None = None
    ) -> UrlResponse:
        data = await self._with_adapters(
            provider,
            lambda adapter: adapter.get_url(id, source=source, br=br),
        )
        return UrlResponse.model_validate(data)

    async def get_cover(
        self, id: str, *, source: str, size: int, provider: str | None = None
    ) -> CoverResponse:
        data = await self._with_adapters(
            provider,
            lambda adapter: adapter.get_cover(id, source=source, size=size),
        )
        return CoverResponse.model_validate(data)

    async def get_lyric(
        self, id: str, *, source: str, provider: str | None = None
    ) -> LyricResponse:
        data = await self._with_adapters(
            provider,
            lambda adapter: adapter.get_lyric(id, source=source),
        )
        return LyricResponse.model_validate(data)

    async def _with_adapters(self, provider: str | None, op) -> dict[str, Any]:
        preferred = self._adapter_by_name(provider)
        order = [preferred] if preferred is not None else []
        order.extend(adapter for adapter in self._adapters if adapter is not preferred)
        if not order:
            raise httpx.HTTPError("no music adapters configured")
        last_error: Exception | None = None
        for adapter in order:
            try:
                return await op(adapter)
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                continue
        assert last_error is not None
        raise last_error

    # --- RecommendationSource protocol bridge (legacy music_proxy shape) ---

    async def search(
        self, source: str, name: str, count: int = 20, pages: int = 1
    ) -> list[dict[str, Any]]:
        """Raw multi-hit search for recommendation engine (single preferred source)."""
        if not self._adapters:
            return []
        last_error: Exception | None = None
        for adapter in self._adapters:
            try:
                items = await adapter.search(
                    name, source=source, count=count, page=pages
                )
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                continue
            if items:
                # recommendation_service expects legacy gdstudio-ish dicts
                return [self._to_legacy_search_item(item, source) for item in items]
        if last_error is not None:
            raise last_error
        return []

    async def is_playable(self, id: str, source: str, br: int = 999) -> bool:
        last_error: Exception | None = None
        for adapter in self._adapters:
            probe = getattr(adapter, "is_playable", None)
            if probe is None:
                continue
            try:
                return bool(await probe(id, source=source, br=br))
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                continue
        if last_error is not None:
            raise last_error
        return False

    @staticmethod
    def _to_legacy_search_item(item: dict[str, Any], source: str) -> dict[str, Any]:
        return {
            "id": item.get("id"),
            "title": item.get("title"),
            "name": item.get("title"),
            "artist": item.get("artist") or "",
            "album": item.get("album") or "",
            "url_id": item.get("url_id") or item.get("id"),
            "lyric_id": item.get("lyric_id") or item.get("id"),
            "pic_id": item.get("cover_id") or item.get("id"),
            "source": item.get("source") or source,
            "duration": item.get("duration"),
            "provider": item.get("provider"),
        }
