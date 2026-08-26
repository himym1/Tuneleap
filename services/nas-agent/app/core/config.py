from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        hide_input_in_errors=True,
    )

    nas_agent_key: str
    music_dir: str = "/music"
    download_dir: str = "/music/download"
    navidrome_db_path: str = "/data/navidrome.db"
    navidrome_music_prefix: str = ""

    http_timeout_seconds: float = 60.0
    max_download_bytes: int = 2 * 1024 * 1024 * 1024
    max_cover_bytes: int = 10 * 1024 * 1024
    min_free_bytes: int = 512 * 1024 * 1024
    max_redirects: int = 5
    allow_private_media_urls: bool = False
    import_speed_probe_seconds: float = 8.0
    import_min_speed_bps: int = 128 * 1024
    import_slow_min_remaining_bytes: int = 8 * 1024 * 1024

    navidrome_url: str = ""
    navidrome_user: str = ""
    navidrome_password: str = ""

    cors_origins: str = ""
    app_name: str = "navidrome-nas-agent"
    app_version: str = "0.1.0"
    host: str = "0.0.0.0"
    port: int = 8503

    @field_validator("nas_agent_key")
    @classmethod
    def _require_secure_agent_key(cls, value: str) -> str:
        if value != value.strip() or len(value) < 32:
            raise ValueError("NAS_AGENT_KEY must contain at least 32 non-space characters")
        if value.lower() in {"change-me-nas-agent", "changeme", "secret", "password"}:
            raise ValueError("NAS_AGENT_KEY must not use a placeholder value")
        return value

    @field_validator(
        "http_timeout_seconds",
        "max_download_bytes",
        "max_cover_bytes",
        "max_redirects",
    )
    @classmethod
    def _require_positive_number(cls, value: float | int) -> float | int:
        if value <= 0:
            raise ValueError("must be greater than zero")
        return value

    @field_validator(
        "min_free_bytes",
        "import_speed_probe_seconds",
        "import_min_speed_bps",
        "import_slow_min_remaining_bytes",
    )
    @classmethod
    def _require_non_negative_number(cls, value: int | float) -> int | float:
        if value < 0:
            raise ValueError("must be zero or greater")
        return value

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
