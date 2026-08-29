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
    genre: str | None = None
    extra: dict[str, Any] | None = None

    @field_validator("genre")
    @classmethod
    def _normalize_genre(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            return None
        if len(cleaned) > 64:
            raise ValueError("genre must be at most 64 characters")
        return cleaned


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
    force: bool = False
    wait: bool = True


class ImportResult(BaseModel):
    ok: bool
    path: str | None = None
    message: str = ""


class ImportProgress(BaseModel):
    active: bool = False
    filename: str | None = None
    bytes_received: int = 0
    bytes_total: int | None = None
    speed_bps: float = 0
    stage: str = "idle"
    error: str | None = None
    message: str | None = None


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


class MediaTagsRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    song_id: str = Field(..., min_length=1, max_length=128)
    song: SongMeta | None = None
    pic_url: str | None = Field(
        default=None,
        validation_alias=AliasChoices("pic_url", "picUrl"),
        max_length=4096,
    )
    lyric: str | None = Field(default=None, max_length=2_000_000)

    @field_validator("song_id")
    @classmethod
    def _validate_song_id(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("song_id must not be blank")
        return cleaned


class MediaTagsResult(BaseModel):
    ok: bool
    song_id: str
    updated: list[str] = Field(default_factory=list)
    message: str = ""


class LibraryIdentitiesResponse(BaseModel):
    count: int
    identities: list[str] = Field(default_factory=list)


class LibraryAuditFinding(BaseModel):
    song_id: str
    title: str = ""
    artist: str = ""
    album: str = ""
    album_id: str = ""
    suffix: str = ""
    bit_rate: int | None = None
    duration: int | None = None
    sample_rate: int | None = None
    codes: list[str] = Field(default_factory=list)
    severity: str = "info"
    cutoff_hz: float | None = None
    hf_extension_db: float | None = None
    deep_error: str | None = None


class LibraryAuditSummary(BaseModel):
    scanned: int = 0
    passed: int = 0
    issues: int = 0
    missing: int = 0
    low_bitrate: int = 0
    suspect_transcode: int = 0
    duplicate_version: int = 0
    lossy_transcode: int = 0
    fake_hires: int = 0
    deep_failed: int = 0
    missing_title: int = 0
    missing_artist: int = 0
    missing_album: int = 0
    suspicious_text: int = 0
    missing_cover: int = 0
    missing_track: int = 0
    missing_year: int = 0
    missing_lyrics: int = 0
    tag_mismatch: int = 0


class LibraryAuditStartRequest(BaseModel):
    low_bitrate_kbps: int = 320
    suspect_lossless_kbps: int = 500
    duration_tolerance_seconds: int = 3

    @field_validator("low_bitrate_kbps")
    @classmethod
    def _validate_low_bitrate(cls, value: int) -> int:
        if value < 64 or value > 320:
            raise ValueError("low_bitrate_kbps must be between 64 and 320")
        return value

    @field_validator("suspect_lossless_kbps")
    @classmethod
    def _validate_suspect(cls, value: int) -> int:
        if value < 200 or value > 800:
            raise ValueError("suspect_lossless_kbps must be between 200 and 800")
        return value

    @field_validator("duration_tolerance_seconds")
    @classmethod
    def _validate_duration(cls, value: int) -> int:
        if value < 1 or value > 15:
            raise ValueError("duration_tolerance_seconds must be between 1 and 15")
        return value


class LibraryAuditDeepRequest(BaseModel):
    scope: str = "findings"
    song_ids: list[str] = Field(default_factory=list)

    @field_validator("scope")
    @classmethod
    def _validate_scope(cls, value: str) -> str:
        if value not in {"findings", "lossless"}:
            raise ValueError("scope must be findings or lossless")
        return value

    @field_validator("song_ids")
    @classmethod
    def _validate_song_ids(cls, value: list[str]) -> list[str]:
        cleaned = [song_id.strip() for song_id in value if song_id.strip()]
        if len(set(cleaned)) != len(cleaned):
            raise ValueError("song ids must be unique")
        return cleaned


class LibraryAuditSnapshot(BaseModel):
    active: bool = False
    stage: str = "idle"
    scanned: int = 0
    total: int = 0
    error: str | None = None
    message: str | None = None
    summary: LibraryAuditSummary = Field(default_factory=LibraryAuditSummary)


class LibraryAuditFindingsResponse(BaseModel):
    items: list[LibraryAuditFinding] = Field(default_factory=list)
    offset: int = 0
    limit: int = 50
    total: int = 0
