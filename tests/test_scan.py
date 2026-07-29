import hashlib
from urllib.parse import parse_qs, urlsplit

from fastapi.testclient import TestClient

from app.main import create_app


def _headers(settings) -> dict[str, str]:
    return {"X-API-Key": settings.nas_agent_key}


def test_scan_uses_subsonic_token_auth(settings, media_server):
    base_url, server = media_server
    configured = settings.model_copy(
        update={
            "navidrome_url": base_url,
            "navidrome_user": "scanner",
            "navidrome_password": "scan-password",
        }
    )

    with TestClient(create_app(configured)) as client:
        response = client.post("/v1/nas/scan", headers=_headers(configured))

    assert response.status_code == 200, response.text
    assert response.json()["ok"] is True
    request = urlsplit(server.requests[-1])
    params = parse_qs(request.query)
    assert request.path == "/rest/startScan"
    assert params["u"] == ["scanner"]
    assert "p" not in params
    salt = params["s"][0]
    assert params["t"] == [hashlib.md5(f"scan-password{salt}".encode()).hexdigest()]


def test_scan_reports_missing_configuration(settings):
    with TestClient(create_app(settings)) as client:
        response = client.post("/v1/nas/scan", headers=_headers(settings))

    assert response.status_code == 503
