import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Settings
from app.main import create_app


def test_health_reports_local_dependencies(settings):
    with TestClient(create_app(settings)) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "navidrome-nas-agent",
        "version": "0.1.0",
        "music_dir_configured": True,
        "download_dir_configured": True,
        "database_configured": False,
    }


def test_protected_routes_require_header(settings):
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/nas/import",
            json={"url": "https://example.com/a.mp3", "filename": "a.mp3"},
        )

    assert response.status_code == 401


def test_query_parameter_does_not_authenticate(settings):
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/nas/import",
            params={"api_key": settings.nas_agent_key},
            json={"url": "https://example.com/a.mp3", "filename": "a.mp3"},
        )

    assert response.status_code == 401


def test_cloud_routes_are_not_exposed(settings):
    with TestClient(create_app(settings)) as client:
        assert client.get("/v1/music/search", params={"query": "track"}).status_code == 404
        assert client.post("/v1/auth/login", json={}).status_code == 404
        assert client.get("/version.json").status_code == 404


def test_settings_reject_placeholder_agent_key():
    with pytest.raises(ValidationError):
        Settings(_env_file=None, nas_agent_key="change-me-nas-agent")
