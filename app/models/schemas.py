from typing import Any

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator


class HealthResponse(BaseModel):
    status: str = "ok"
    service: str = "navidrome-nas-agent"
    version: str
    music_dir_configured: bool
    download_dir_configured: bool
    database_configured: bool


class SongMeta(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    title: str | None = Field(
        default=None,
        validation_alias=AliasChoices("title", "name"),
    )
    artist: str | None = None
    album: str | None = None
    track: int | None = None
    year: int | None = None
    source: str | None = None
    extra: dict[str, Any] | None = None


class ImportRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    url: str = Field(..., min_length=1, max_length=4096)
    filename: str = Field(..., min_length=1, max_length=255)
    song: SongMeta | None = None
    pic_url: str | None = Field(
        default=None,
        validation_alias=AliasChoices("pic_url", "picUrl"),
        max_length=4096,
    )
    lyric: str | None = Field(default=None, max_length=2_000_000)


class ImportResult(BaseModel):
    ok: bool
    path: str | None = None
    message: str = ""


class DeleteRequest(BaseModel):
    song_ids: list[str] = Field(..., min_length=1, max_length=50)

    @field_validator("song_ids")
    @classmethod
    def _validate_song_ids(cls, value: list[str]) -> list[str]:
        if any(not song_id.strip() for song_id in value):
            raise ValueError("song ids must not be blank")
        if len(set(value)) != len(value):
            raise ValueError("song ids must be unique")
        return value


class DeleteResult(BaseModel):
    deleted: int = 0
    skipped: int = 0
    errors: int = 0
    msg: str = ""
    details: list[dict[str, Any]] = Field(default_factory=list)


class ScanResult(BaseModel):
    ok: bool
    message: str = ""
