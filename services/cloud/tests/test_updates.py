from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.main import create_app


def test_private_updates_guards(tmp_path: Path, monkeypatch):
    release_dir = Path(get_settings().release_dir)
    release_dir.mkdir(parents=True, exist_ok=True)
    (release_dir / "version.json").write_text(
        json.dumps({"android": {"version": "1.0.10", "build": 10}}),
        encoding="utf-8",
    )
    apk = "navidrome_player-1.0.10+10-android.apk"
    (release_dir / apk).write_bytes(b"private-apk")
    (release_dir / "secret.txt").write_text("nope", encoding="utf-8")

    with TestClient(create_app()) as client:
        assert client.get("/version.json").status_code == 401
        headers = {"X-API-Key": "test-cloud-key"}
        meta = client.get("/version.json", headers=headers)
        assert meta.status_code == 200
        assert meta.json()["android"]["build"] == 10
        assert meta.headers["cache-control"] == "no-store"

        good = client.get(f"/releases/{apk}", headers=headers)
        assert good.status_code == 200
        assert good.content == b"private-apk"

        windows = "navidrome_player-1.0.10+10-windows.zip"
        (release_dir / windows).write_bytes(b"private-zip")
        win = client.get(f"/releases/{windows}", headers=headers)
        assert win.status_code == 200
        assert win.content == b"private-zip"

        bad = client.get("/releases/secret.txt", headers=headers)
        assert bad.status_code == 404
