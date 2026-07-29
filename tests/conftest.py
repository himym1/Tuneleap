from __future__ import annotations

import os
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def _isolate_settings(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("API_KEY", "test-cloud-key")
    monkeypatch.setenv("JWT_SECRET", "test-jwt-secret")
    monkeypatch.setenv("AUTH_DB_PATH", str(tmp_path / "auth.db"))
    monkeypatch.setenv("RECOMMENDATION_DB_PATH", str(tmp_path / "recommendations.db"))
    monkeypatch.setenv("RELEASE_DIR", str(tmp_path / "releases"))
    monkeypatch.setenv(
        "GDSTUDIO_API_BASE_URLS", "https://gdstudio.test/api.php"
    )
    monkeypatch.setenv("METING_API_BASE_URLS", "")
    monkeypatch.setenv("UPSTREAM_STRATEGY", "ordered")
    (tmp_path / "releases").mkdir(parents=True, exist_ok=True)

    from app.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()
