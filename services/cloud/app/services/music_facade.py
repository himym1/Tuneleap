"""Music facade: first-success across adapters + recommendation source bridge."""

from __future__ import annotations

import asyncio
from typing import Any

import httpx

from app.adapters.base import MusicAdapter
from app.adapters.chksz import ChkszAdapter
from app.adapters.gdstudio import GdstudioAdapter
from app.adapters.meting import MetingAdapter
from app.core.config import Settings
from app.core.sources import canonicalize_music_source
from app.models.schemas import (
    CoverResponse,
    LyricResponse,
    SearchResponse,
    SongDTO,
    UrlResponse,
)
from app.services.search_policy import (
    adapter_available,
    capabilities_payload,
    effective_search_count,
    has_more_pages,
    paginating_adapters,
    rank_search_adapters,
)
from app.services.search_rank import looks_like_artist_query, rank_search_hits


class MusicSearchSelectionError(ValueError):
    """Requested adapter/platform selection cannot be served."""

def _is_available(adapter: MusicAdapter) -> bool:
    return adapter_available(adapter)


class MusicFacade:
    def __init__(self, client: httpx.AsyncClient, settings: Settings):
        self._client = client
        self._settings = settings
        available: dict[str, MusicAdapter] = {}
        timeout = settings.http_timeout_seconds
        cooldown = settings.upstream_cooldown_seconds
        if settings.gdstudio_bases:
            available["gdstudio"] = GdstudioAdapter(
                client,
                settings.gdstudio_bases,
                cooldown_seconds=cooldown,
                timeout=timeout,
            )
        if settings.meting_bases:
            available["meting"] = MetingAdapter(
                client,
                settings.meting_bases,
                token=settings.meting_api_token,
                cooldown_seconds=cooldown,
                timeout=timeout,
            )
        if settings.chksz_api_key.strip() and settings.chksz_base:
            available["chksz"] = ChkszAdapter(
                client,
                settings.chksz_base,
                settings.chksz_api_key.strip(),
                timeout=timeout,
            )
        self._adapters = [
            available.pop(name)
            for name in settings.music_adapter_order_list
            if name in available
        ]
        self._adapters.extend(available.values())

    @property
    def adapters(self) -> list[MusicAdapter]:
        return list(self._adapters)

    def capabilities(self) -> dict[str, Any]:
        return capabilities_payload(self._adapters)


    def _adapter_by_name(self, provider: str | None) -> MusicAdapter | None:
        if not provider:
            return None
        for adapter in self._adapters:
            if adapter.name == provider and _is_available(adapter):
                return adapter
        return None

    def _search_sources(self, preferred: str | None) -> tuple[str | None, ...]:
        pinned = canonicalize_music_source(preferred)
        if pinned:
            return (pinned,)
        return self._settings.music_search_source_list or (None,)

    def _paginating_adapters(self, source: str | None) -> list[MusicAdapter]:
        return paginating_adapters(self._adapters, source)

    def _with_has_more(
        self,
        response: SearchResponse,
        *,
        source: str | None,
        count: int,
        page: int,
    ) -> SearchResponse:
        winner = self._adapter_by_name(response.provider)
        return response.model_copy(
            update={
                "page": page,
                "has_more": has_more_pages(
                    adapters=self._adapters,
                    source=response.source or source,
                    item_count=len(response.items),
                    requested_count=count,
                    winner=winner,
                ),
            }
        )

    def _search_adapters(
        self,
        *,
        source: str | None,
        pinned_adapter: MusicAdapter | None,
        page: int,
    ) -> list[MusicAdapter]:
        if page > 1:
            paginating = self._paginating_adapters(source)
            if (
                pinned_adapter is not None
                and pinned_adapter.supports_pagination(source)
            ):
                return [
                    pinned_adapter,
                    *[adapter for adapter in paginating if adapter is not pinned_adapter],
                ]
            return paginating
        if pinned_adapter is not None:
            return [pinned_adapter]
        return rank_search_adapters(self._adapters, source)

    def _empty_search(
        self, query: str, *, provider: str, source: str | None, page: int
    ) -> SearchResponse:
        return SearchResponse(
            query=query,
            provider=provider,
            source=source,
            items=[],
            strategy="first-success-empty",
            page=page,
            has_more=False,
        )

    async def search_first_success(
        self,
        query: str,
        *,
        source: str | None,
        count: int,
        page: int,
        provider: str | None = None,
    ) -> SearchResponse:
        if not self._adapters:
            raise httpx.HTTPError("no music adapters configured")

        pinned_adapter = self._adapter_by_name(provider)
        if provider and pinned_adapter is None:
            raise MusicSearchSelectionError(f"music adapter unavailable: {provider}")

        last_error: Exception | None = None
        empty_response: SearchResponse | None = None
        candidates = self._search_sources(source)
        if page > 1:
            candidates = candidates[:1]
        for candidate in candidates:
            if pinned_adapter is not None and not pinned_adapter.supports(candidate):
                raise MusicSearchSelectionError(
                    f"music adapter {provider} does not support source {candidate}"
                )
            page_count = effective_search_count(
                adapters=self._adapters,
                source=candidate,
                requested=count,
            )
            adapters = self._search_adapters(
                source=candidate,
                pinned_adapter=pinned_adapter,
                page=page,
            )
            if not adapters:
                if page > 1:
                    empty_response = self._empty_search(
                        query,
                        provider=(
                            pinned_adapter.name
                            if pinned_adapter is not None
                            else self._adapters[0].name
                        ),
                        source=candidate,
                        page=page,
                    )
                    continue
                if provider:
                    raise MusicSearchSelectionError(
                        f"music adapter {provider} does not support source {candidate}"
                    )
                continue
            strategy = (self._settings.upstream_strategy or "ordered").lower()
            search = (
                self._search_race
                if strategy == "race" and len(adapters) > 1
                else self._search_ordered
            )
            try:
                response = await search(
                    query,
                    adapters=adapters,
                    source=candidate,
                    count=page_count,
                    page=page,
                )
            except Exception as exc:  # noqa: BLE001 - fail over across sources
                last_error = exc
                continue
            if response.items:
                refined = await self._refine_search(
                    response,
                    query=query,
                    source=candidate,
                    count=page_count,
                    page=page,
                )
                return self._with_has_more(
                    refined, source=candidate, count=page_count, page=page
                )
            empty_response = response

        if empty_response is not None:
            return empty_response
        if last_error is not None:
            raise last_error
        raise MusicSearchSelectionError(
            "no music adapter supports the requested source"
        )

    async def _refine_search(
        self,
        response: SearchResponse,
        *,
        query: str,
        source: str | None,
        count: int,
        page: int,
    ) -> SearchResponse:
        winner = self._adapter_by_name(response.provider)
        items = list(response.items)
        if (
            page == 1
            and winner is not None
            and winner.search_window(source).paginates
            and looks_like_artist_query(query, items)
        ):
            seen = {item.id for item in items}
            extra_count = winner.search_window(source).request_count(count)
            for extra_page in (2, 3):
                try:
                    extra = await winner.search(
                        query,
                        source=source,
                        count=extra_count,
                        page=extra_page,
                    )
                except Exception:  # noqa: BLE001 - keep the first window
                    break
                if not extra:
                    break
                for raw in extra:
                    song = SongDTO.model_validate(raw)
                    if song.id in seen:
                        continue
                    seen.add(song.id)
                    items.append(song)
        ranked = rank_search_hits(query, items)[:count]
        return response.model_copy(update={"items": ranked})

    async def _search_ordered(
        self,
        query: str,
        *,
        adapters: list[MusicAdapter],
        source: str | None,
        count: int,
        page: int,
    ) -> SearchResponse:
        last_error: Exception | None = None
        empty_adapter: MusicAdapter | None = None
        for adapter in adapters:
            try:
                items = await adapter.search(
                    query,
                    source=source,
                    count=adapter.search_window(source).request_count(count),
                    page=page,
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
                    page=page,
                )
            empty_adapter = adapter
        if empty_adapter is not None:
            return SearchResponse(
                query=query,
                provider=empty_adapter.name,
                source=source,
                items=[],
                strategy="first-success-empty",
                page=page,
            )
        if last_error is not None:
            raise last_error
        raise httpx.HTTPError("all music adapters failed")

    async def _search_race(
        self,
        query: str,
        *,
        adapters: list[MusicAdapter],
        source: str | None,
        count: int,
        page: int,
    ) -> SearchResponse:
        async def run(
            adapter: MusicAdapter,
        ) -> tuple[MusicAdapter, list[dict[str, Any]]]:
            items = await adapter.search(
                query,
                source=source,
                count=adapter.search_window(source).request_count(count),
                page=page,
            )
            return adapter, items

        tasks = [asyncio.create_task(run(adapter)) for adapter in adapters]
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
                    page=page,
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
                page=page,
            )
        if last_error is not None:
            raise last_error
        raise httpx.HTTPError("all music adapters failed")

    async def get_url(
        self,
        id: str,
        *,
        source: str,
        br: int,
        provider: str | None = None,
        fresh: bool = False,
    ) -> UrlResponse:
        resolved = canonicalize_music_source(source) or source

        async def _resolve(adapter):
            if fresh:
                invalidate = getattr(adapter, "invalidate_url_cache", None)
                if callable(invalidate):
                    invalidate(id, source=resolved, br=br)
            return await adapter.get_url(id, source=resolved, br=br)

        data = await self._with_adapters(provider, _resolve)
        return UrlResponse.model_validate(data)

    async def get_cover(
        self, id: str, *, source: str, size: int, provider: str | None = None
    ) -> CoverResponse:
        resolved = canonicalize_music_source(source) or source
        data = await self._with_adapters(
            provider,
            lambda adapter: adapter.get_cover(id, source=resolved, size=size),
        )
        return CoverResponse.model_validate(data)

    async def get_lyric(
        self, id: str, *, source: str, provider: str | None = None
    ) -> LyricResponse:
        resolved = canonicalize_music_source(source) or source
        preferred = self._adapter_by_name(provider)
        if provider and preferred is None:
            raise MusicSearchSelectionError(f"music adapter unavailable: {provider}")

        order: list[MusicAdapter] = []
        if preferred is not None:
            order.append(preferred)
        for adapter in self._adapters:
            if not _is_available(adapter) or adapter in order:
                continue
            if not adapter.supports(resolved):
                continue
            order.append(adapter)
        if not order:
            raise httpx.HTTPError("no music adapters configured")

        last_error: Exception | None = None
        empty: dict[str, Any] | None = None
        for adapter in order:
            try:
                data = await adapter.get_lyric(id, source=resolved)
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                continue
            lyric = data.get("lyric") if isinstance(data, dict) else None
            if isinstance(lyric, str) and lyric.strip():
                return LyricResponse.model_validate(data)
            if isinstance(data, dict):
                empty = data
        if empty is not None:
            return LyricResponse.model_validate(empty)
        if last_error is not None:
            raise last_error
        raise httpx.HTTPError("lyric empty")

    async def _with_adapters(self, provider: str | None, op) -> dict[str, Any]:
        preferred = self._adapter_by_name(provider)
        if provider and preferred is None:
            raise MusicSearchSelectionError(f"music adapter unavailable: {provider}")
        order = (
            [preferred]
            if preferred is not None
            else [adapter for adapter in self._adapters if _is_available(adapter)]
        )
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
            if not _is_available(adapter):
                continue
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

    async def is_playable(
        self,
        id: str,
        source: str,
        br: int = 999,
        provider: str | None = None,
    ) -> bool:
        preferred = self._adapter_by_name(provider)
        order = [preferred] if preferred is not None else []
        order.extend(
            adapter
            for adapter in self._adapters
            if adapter is not preferred and _is_available(adapter)
        )
        last_error: Exception | None = None
        saw_result = False
        for adapter in order:
            probe = getattr(adapter, "is_playable", None)
            if probe is None:
                continue
            try:
                playable = bool(await probe(id, source=source, br=br))
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                continue
            saw_result = True
            if playable:
                return True
            if adapter is preferred:
                return False
        if saw_result:
            return False
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
            "pic_id": item.get("cover_id"),
            "source": item.get("source") or source,
            "duration": item.get("duration"),
            "provider": item.get("provider"),
        }
