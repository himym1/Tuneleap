"""Product search windows and has_more. Adapters stay HTTP clients."""

from __future__ import annotations

from app.adapters.base import MusicAdapter
from app.adapters.search_window import (
    CLOUD_SEARCH_COUNT_MAX,
    DEFAULT_SEARCH_COUNT,
    SearchWindow,
)


def adapter_available(adapter: MusicAdapter) -> bool:
    return bool(getattr(adapter, "available", True))


def available_adapters(adapters: list[MusicAdapter]) -> list[MusicAdapter]:
    return [adapter for adapter in adapters if adapter_available(adapter)]


def paginating_adapters(
    adapters: list[MusicAdapter], source: str | None
) -> list[MusicAdapter]:
    return [
        adapter
        for adapter in available_adapters(adapters)
        if adapter.supports(source) and adapter.search_window(source).paginates
    ]


def rank_search_adapters(
    adapters: list[MusicAdapter], source: str | None
) -> list[MusicAdapter]:
    supporting = [
        adapter
        for adapter in available_adapters(adapters)
        if adapter.supports(source)
    ]
    return sorted(
        supporting,
        key=lambda adapter: (
            0 if adapter.search_window(source).paginates else 1,
            supporting.index(adapter),
        ),
    )


def product_window_for(
    adapters: list[MusicAdapter], source: str | None
) -> SearchWindow:
    if source:
        window = product_source_windows(adapters).get(source)
        if window is not None:
            return window
    return SearchWindow(max_count=DEFAULT_SEARCH_COUNT, paginates=False)


def effective_search_count(
    *,
    adapters: list[MusicAdapter],
    source: str | None,
    requested: int,
) -> int:
    window = product_window_for(adapters, source)
    if requested >= DEFAULT_SEARCH_COUNT:
        return window.request_count(window.max_count)
    return window.request_count(requested)


def product_source_windows(
    adapters: list[MusicAdapter],
) -> dict[str, SearchWindow]:
    sources: dict[str, SearchWindow] = {}
    for adapter in available_adapters(adapters):
        for source in adapter.supported_sources:
            window = adapter.search_window(source)
            current = sources.get(source)
            if current is None:
                sources[source] = SearchWindow(
                    max_count=min(window.max_count, CLOUD_SEARCH_COUNT_MAX),
                    paginates=window.paginates,
                )
                continue
            sources[source] = SearchWindow(
                max_count=min(
                    CLOUD_SEARCH_COUNT_MAX,
                    max(current.max_count, window.max_count),
                ),
                paginates=current.paginates or window.paginates,
            )
    return dict(sorted(sources.items()))


def capabilities_payload(adapters: list[MusicAdapter]) -> dict[str, object]:
    live = available_adapters(adapters)
    return {
        "default_provider": live[0].name if live else None,
        "sources": {
            source: window.as_capability()
            for source, window in product_source_windows(live).items()
        },
        "adapters": [
            {
                "id": adapter.name,
                "sources": sorted(adapter.supported_sources),
            }
            for adapter in live
        ],
    }


def has_more_pages(
    *,
    adapters: list[MusicAdapter],
    source: str | None,
    item_count: int,
    requested_count: int,
    winner: MusicAdapter | None,
) -> bool:
    if item_count <= 0 or not paginating_adapters(adapters, source):
        return False
    if winner is not None and winner.search_window(source).paginates:
        return item_count >= winner.search_window(source).request_count(
            requested_count
        )
    return True
