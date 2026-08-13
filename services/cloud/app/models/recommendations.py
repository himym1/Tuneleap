from enum import Enum
from typing import Literal
from uuid import RFC_4122, UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel




class _CamelCaseModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        extra="forbid",
        strict=True,
    )


class RecentSongSummary(_CamelCaseModel):
    title: str = Field(min_length=1, max_length=200)
    artist: str = Field(max_length=200)
    album: str = Field(max_length=200)
    source: str = Field(min_length=1, max_length=32, pattern=r"^[A-Za-z0-9_-]+$")
    source_id: str = Field(min_length=1, max_length=256)


class RecommendationSessionCreateRequest(_CamelCaseModel):
    refresh: bool = False
    page_size: int = Field(default=20, ge=1, le=20)
    recent: list[RecentSongSummary] = Field(default_factory=list, max_length=30)


class RecommendationSong(_CamelCaseModel):
    id: str = Field(min_length=1, max_length=256)
    title: str = Field(min_length=1, max_length=200)
    album: str = Field(max_length=200)
    album_id: str = Field(max_length=256)
    artist: str = Field(max_length=200)
    artist_id: str = Field(max_length=256)
    track: int | None = Field(default=None, ge=0)
    year: int | None = Field(default=None, ge=0)
    duration: int | None = Field(default=None, ge=0)
    bit_rate: int | None = Field(default=None, ge=0)
    cover_art: str | None = None
    suffix: str | None = None
    path: str | None = None
    comment: str | None = None
    backend: Literal["solara"] = "solara"
    online_source: str = Field(
        min_length=1,
        max_length=32,
        pattern=r"^[A-Za-z0-9_-]+$",
    )
    url_id: str = Field(min_length=1, max_length=256)
    lyric_id: str | None = None


class RecommendationItem(_CamelCaseModel):
    candidate_id: str = Field(min_length=1, max_length=128)
    recommendation_type: Literal["similar", "explore"]
    song: RecommendationSong


class RecommendationPageV1(_CamelCaseModel):
    contract_version: Literal[1] = 1
    session_id: str = Field(min_length=1, max_length=128)
    mode: Literal["ai", "fallback"]
    items: list[RecommendationItem] = Field(max_length=20)
    next_cursor: str | None = Field(default=None, max_length=512)
    has_more: bool


class RecommendationFeedbackEvent(str, Enum):
    PLAYED = "played"
    COMPLETED = "completed"
    IMPORTED = "imported"
    DISLIKED = "disliked"
    UNAVAILABLE = "unavailable"


class RecommendationFeedbackRequest(_CamelCaseModel):
    idempotency_key: UUID
    session_id: str = Field(min_length=1, max_length=128)
    candidate_id: str = Field(min_length=1, max_length=128)
    event: RecommendationFeedbackEvent

    @field_validator("idempotency_key", mode="before")
    @classmethod
    def _parse_idempotency_key(cls, value: object) -> UUID:
        if isinstance(value, UUID):
            return value
        if not isinstance(value, str):
            raise ValueError("idempotencyKey must be an RFC 4122 UUID string")
        try:
            return UUID(value)
        except ValueError as error:
            raise ValueError("idempotencyKey must be an RFC 4122 UUID string") from error

    @field_validator("idempotency_key")
    @classmethod
    def _require_rfc4122_uuid(cls, value: UUID) -> UUID:
        if value.variant != RFC_4122:
            raise ValueError("idempotencyKey must be an RFC 4122 UUID")
        return value

    @field_validator("event", mode="before")
    @classmethod
    def _parse_event(cls, value: object) -> RecommendationFeedbackEvent:
        if isinstance(value, RecommendationFeedbackEvent):
            return value
        if not isinstance(value, str):
            raise ValueError("event must be a recommendation feedback event string")
        return RecommendationFeedbackEvent(value)


class RecommendationFeedbackResponse(_CamelCaseModel):
    contract_version: Literal[1] = 1
    accepted: bool
    duplicate: bool


class RecommendationErrorV1(_CamelCaseModel):
    contract_version: Literal[1] = 1
    code: str = Field(min_length=1)
    detail: str = Field(min_length=1)
    retryable: bool
