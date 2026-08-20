"""Per-adapter first-page window. Cloud search treats count as a max, not a page-full signal."""

from __future__ import annotations

from dataclasses import dataclass

CLOUD_SEARCH_COUNT_MAX = 50
DEFAULT_SEARCH_COUNT = 30


@dataclass(frozen=True)
class SearchWindow:
    max_count: int
    paginates: bool

    def request_count(self, requested: int) -> int:
        return max(1, min(int(requested), self.max_count, CLOUD_SEARCH_COUNT_MAX))

    def as_capability(self) -> dict[str, int | bool]:
        return {
            "max_count": min(self.max_count, CLOUD_SEARCH_COUNT_MAX),
            "paginates": self.paginates,
        }
