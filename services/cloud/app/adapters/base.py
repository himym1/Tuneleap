from abc import ABC, abstractmethod
from typing import Any


class MusicAdapter(ABC):
    """Port for a single upstream music HTTP family."""

    name: str

    supported_sources: frozenset[str] = frozenset()

    def supports(self, source: str | None) -> bool:
        return source is None or source in self.supported_sources

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