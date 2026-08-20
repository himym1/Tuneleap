from typing import Any, Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"
    service: str = "navidrome-cloud"
    version: str


class SongDTO(BaseModel):
    """Normalized online song — keep compatible with Flutter BackendClient where possible."""

    id: str
    title: str
    artist: str = ""
    album: str = ""
    source: str = Field(description="Logical platform, e.g. netease")
    provider: str = Field(description="Adapter that won, e.g. gdstudio|meting")
    url_id: Optional[str] = None
    cover_id: Optional[str] = None
    lyric_id: Optional[str] = None
    duration: Optional[float] = None
    raw: Optional[dict[str, Any]] = None


class SearchResponse(BaseModel):
    query: str
    provider: str
    source: Optional[str] = None
    items: list[SongDTO]
    strategy: str = "first-success"
    page: int = 1
    has_more: bool = False


class SourceSearchWindow(BaseModel):
    max_count: int
    paginates: bool


class MusicAdapterCapability(BaseModel):
    id: str
    sources: list[str]


class MusicCapabilitiesResponse(BaseModel):
    default_provider: Optional[str] = None
    sources: dict[str, SourceSearchWindow] = Field(default_factory=dict)
    adapters: list[MusicAdapterCapability]


class UrlResponse(BaseModel):
    url: str
    br: Optional[int] = None
    provider: str
    source: str
    cover_url: Optional[str] = None
    lyric: Optional[str] = None


class CoverResponse(BaseModel):
    url: str
    provider: str
    source: str


class LyricResponse(BaseModel):
    lyric: str
    provider: str
    source: str