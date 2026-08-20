from app.adapters.gdstudio import GdstudioAdapter
from app.adapters.meting import MetingAdapter
from app.adapters.search_window import SearchWindow
from app.services.search_policy import (
    capabilities_payload,
    effective_search_count,
    has_more_pages,
    product_source_windows,
    rank_search_adapters,
)
import httpx


def test_product_windows_merge_pagination_and_max_count():
    meting = MetingAdapter(httpx.AsyncClient(), ("https://meting.test/api",))
    gdstudio = GdstudioAdapter(httpx.AsyncClient(), ("https://gds.test/api.php",))
    windows = product_source_windows([meting, gdstudio])

    assert windows["netease"] == SearchWindow(max_count=50, paginates=True)
    assert windows["tencent"] == SearchWindow(max_count=30, paginates=False)
    assert windows["kuwo"].max_count == 50
    assert windows["kuwo"].paginates is False


def test_has_more_uses_policy_not_full_page():
    meting = MetingAdapter(httpx.AsyncClient(), ("https://meting.test/api",))
    gdstudio = GdstudioAdapter(httpx.AsyncClient(), ("https://gds.test/api.php",))
    adapters = [meting, gdstudio]

    assert has_more_pages(
        adapters=adapters,
        source="netease",
        item_count=30,
        requested_count=50,
        winner=meting,
    )
    assert not has_more_pages(
        adapters=adapters,
        source="tencent",
        item_count=30,
        requested_count=30,
        winner=meting,
    )
    assert not has_more_pages(
        adapters=adapters,
        source="netease",
        item_count=10,
        requested_count=30,
        winner=gdstudio,
    )
    assert has_more_pages(
        adapters=adapters,
        source="netease",
        item_count=30,
        requested_count=30,
        winner=gdstudio,
    )


def test_rank_search_adapters_prefers_paginating_windows():
    meting = MetingAdapter(httpx.AsyncClient(), ("https://meting.test/api",))
    gdstudio = GdstudioAdapter(httpx.AsyncClient(), ("https://gds.test/api.php",))
    ranked = rank_search_adapters([meting, gdstudio], "netease")
    assert [adapter.name for adapter in ranked] == ["gdstudio", "meting"]


def test_default_count_uses_product_window():
    meting = MetingAdapter(httpx.AsyncClient(), ("https://meting.test/api",))
    gdstudio = GdstudioAdapter(httpx.AsyncClient(), ("https://gds.test/api.php",))
    adapters = [meting, gdstudio]
    assert (
        effective_search_count(adapters=adapters, source="netease", requested=30) == 50
    )
    assert (
        effective_search_count(adapters=adapters, source="netease", requested=5) == 5
    )
    assert (
        effective_search_count(adapters=adapters, source="tencent", requested=30) == 30
    )


def test_capabilities_payload_includes_product_sources():
    meting = MetingAdapter(httpx.AsyncClient(), ("https://meting.test/api",))
    payload = capabilities_payload([meting])
    assert payload["default_provider"] == "meting"
    assert payload["sources"]["netease"] == {"max_count": 30, "paginates": False}
    assert payload["adapters"][0]["id"] == "meting"
