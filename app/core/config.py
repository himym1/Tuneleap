from functools import lru_cache
from typing import Self

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_SUPPORTED_RECOMMENDATION_SOURCES = frozenset(
    {"netease", "migu", "joox", "kuwo", "kugou"}
)


def _split_csv(value: str, *, lowercase: bool = False) -> tuple[str, ...]:
    parts = (part.strip() for part in value.split(","))
    if lowercase:
        parts = (part.lower() for part in parts)
    return tuple(dict.fromkeys(part for part in parts if part))


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    api_key: str = "change-me-cloud"
    gdstudio_api_base_urls: str = "https://music-api.gdstudio.xyz/api.php"
    meting_api_base_urls: str = ""
    http_timeout_seconds: float = 30.0
    upstream_cooldown_seconds: int = 60
    upstream_strategy: str = "ordered"  # ordered | race
    release_dir: str = "./releases"

    # Optional NAS agent for recommendation library blocking (no local navidrome.db mount)
    nas_agent_url: str = ""
    nas_agent_key: str = ""

    app_name: str = "navidrome-cloud"
    app_version: str = "0.2.0"
    host: str = "0.0.0.0"
    port: int = 8600

    # Postgres is the cloud source of truth.
    database_url: str = ""
    database_pool_min_size: int = 1
    database_pool_max_size: int = 10
    database_pool_timeout_seconds: float = 10.0

    # Auth / JWT
    jwt_secret: str = "change-me-jwt-secret"
    jwt_access_ttl_minutes: int = 1440
    jwt_refresh_ttl_days: int = 90

    # Legacy SQLite sources used only by scripts/migrate_sqlite_to_postgres.py.
    auth_db_path: str = "./data/auth.db"
    recommendation_db_path: str = "./data/recommendations.db"

    # Recommendations
    recommendation_session_ttl_hours: int = 24
    recommendation_pool_target: int = 60
    recommendation_pool_low_watermark: int = 20
    recommendation_page_max: int = 20
    recommendation_upstream_concurrency: int = 5
    recommendation_discovery_seeds: str = "流行新歌,热门歌曲,经典歌曲"
    recommendation_sources: str = "netease,migu,joox"

    # Rate limit
    rate_limit_default: str = "120/minute"
    rate_limit_music: str = "60/minute"
    rate_limit_auth: str = "20/minute"

    @field_validator("recommendation_sources")
    @classmethod
    def _require_supported_recommendation_source(cls, value: str) -> str:
        if not any(
            source in _SUPPORTED_RECOMMENDATION_SOURCES
            for source in _split_csv(value, lowercase=True)
        ):
            raise ValueError(
                "recommendation_sources must contain at least one supported source"
            )
        return value

    @field_validator(
        "database_pool_min_size",
        "database_pool_max_size",
        "database_pool_timeout_seconds",
    )
    @classmethod
    def _require_positive_database_setting(cls, value: float) -> int | float:
        if value <= 0:
            raise ValueError("database pool settings must be positive")
        return value

    @model_validator(mode="after")
    def _validate_database_pool_bounds(self) -> Self:
        if self.database_pool_min_size > self.database_pool_max_size:
            raise ValueError(
                "database_pool_max_size must be greater than or equal to "
                "database_pool_min_size"
            )
        return self

    @property
    def gdstudio_bases(self) -> tuple[str, ...]:
        return _split_csv(self.gdstudio_api_base_urls)

    @property
    def meting_bases(self) -> tuple[str, ...]:
        return _split_csv(self.meting_api_base_urls)

    @property
    def recommendation_source_list(self) -> tuple[str, ...]:
        return tuple(
            source
            for source in _split_csv(self.recommendation_sources, lowercase=True)
            if source in _SUPPORTED_RECOMMENDATION_SOURCES
        )

    @property
    def recommendation_discovery_seed_list(self) -> tuple[str, ...]:
        return _split_csv(self.recommendation_discovery_seeds)


@lru_cache
def get_settings() -> Settings:
    return Settings()
