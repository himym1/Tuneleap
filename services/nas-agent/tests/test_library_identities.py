from __future__ import annotations

import sqlite3
from pathlib import Path
from types import SimpleNamespace

import httpx
import pytest
from fastapi import FastAPI

from app.api.songs import router
from app.core.config import Settings
from app.services.library import LibraryService
from app.services.recommendation_identity import weak_identity


@pytest.mark.asyncio
async def test_library_identities_endpoint(tmp_path: Path):
    db_path = tmp_path / "navidrome.db"
    conn = sqlite3.connect(db_path)
    conn.execute(
        "CREATE TABLE media_file(title TEXT, artist TEXT, album_artist TEXT, missing INTEGER)"
    )
    conn.executemany(
        "INSERT INTO media_file VALUES (?, ?, ?, ?)",
        [
            ("Song (Live)", "Artist feat. Guest", "Album Artist", 0),
            ("Missing", "Artist", None, 1),
        ],
    )
    conn.commit()
    conn.close()

    settings = Settings(
        nas_agent_key="test-nas-agent-key-with-enough-entropy-xx",
        navidrome_db_path=str(db_path),
        music_dir=str(tmp_path / "music"),
        download_dir=str(tmp_path / "music" / "download"),
        _env_file=None,
    )

    app = FastAPI()
    app.include_router(router)
    app.state.settings = SimpleNamespace(
        nas_agent_key="test-nas-agent-key-with-enough-entropy-xx"
    )
    async with httpx.AsyncClient() as http_client:
        app.state.library = LibraryService(http_client, settings)
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            bare = await client.get("/v1/songs/library-identities")
            assert bare.status_code == 401
            resp = await client.get(
                "/v1/songs/library-identities",
                headers={"X-API-Key": "test-nas-agent-key-with-enough-entropy-xx"},
            )
            assert resp.status_code == 200, resp.text
            body = resp.json()
            expected = {
                weak_identity("Song", "Artist"),
                weak_identity("Song", "Album Artist"),
            }
            assert set(body["identities"]) == expected
            assert body["count"] == len(expected)
