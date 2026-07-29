from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import create_app


def test_register_login_refresh_flow():
    with TestClient(create_app()) as client:
        reg = client.post(
            "/v1/auth/register",
            json={"username": "alice", "password": "password123", "email": "a@b.c"},
        )
        assert reg.status_code == 200, reg.text
        tokens = reg.json()
        assert tokens["access_token"]
        assert tokens["refresh_token"]
        assert tokens["token_type"] == "bearer"

        dup = client.post(
            "/v1/auth/register",
            json={"username": "alice", "password": "password123"},
        )
        assert dup.status_code == 409

        bad = client.post(
            "/v1/auth/login",
            json={"username": "alice", "password": "wrong-password"},
        )
        assert bad.status_code == 401

        login = client.post(
            "/v1/auth/login",
            json={"username": "alice", "password": "password123"},
        )
        assert login.status_code == 200
        refresh = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": login.json()["refresh_token"]},
        )
        assert refresh.status_code == 200
        assert refresh.json()["access_token"]

        # Bearer access token works on music routes (even if upstream fails later)
        authed = client.get(
            "/v1/music/search",
            params={"q": "x"},
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        # 502 because mock upstream host may fail, but must not be 401
        assert authed.status_code != 401
