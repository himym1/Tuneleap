from abc import ABC, abstractmethod
from typing import Any

from app.adapters.search_window import DEFAULT_SEARCH_COUNT, SearchWindow


class MusicAdapter(ABC):
    """Port for a single upstream music HTTP family."""

    name: str

    supported_sources: frozenset[str] = frozenset()

    def supports(self, source: str | None) -> bool:
        return source is None or source in self.supported_sources

    def search_window(self, source: str | None) -> SearchWindow:
        """First-page size and whether later pages are a different window."""
        return SearchWindow(max_count=DEFAULT_SEARCH_COUNT, paginates=False)

    def supports_pagination(self, source: str | None) -> bool:
        return self.search_window(source).paginates

    @property
    def available(self) -> bool:
        return True

    @abstractmethod
    async def search(
        self, query: str, *, source: str | None, count: int, page: int
    ) -> list[dict[str, Any]]:
        raise NotImplementedError

    @abstractmethod
    async def get_url(
        self, id: str, *, source: str, br: int
    ) -> dict[str, Any]:
        raise NotImplementedError

    @abstractmethod
    async def get_cover(
        self, id: str, *, source: str, size: int
    ) -> dict[str, Any]:
        raise NotImplementedError

    @abstractmethod
    async def get_lyric(self, id: str, *, source: str) -> dict[str, Any]:
        raise NotImplementedError