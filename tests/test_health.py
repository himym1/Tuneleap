from fastapi.testclient import TestClient

from app.main import create_app


def test_health_ok():
    with TestClient(create_app()) as client:
        resp = client.get("/health")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "ok"
        assert body["service"] == "navidrome-cloud"


def test_search_requires_api_key():
    with TestClient(create_app()) as client:
        resp = client.get("/v1/music/search", params={"q": "test"})
        assert resp.status_code == 401
