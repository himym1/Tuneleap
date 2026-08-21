from __future__ import annotations

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.library import router
from app.core.auth import verify_api_key
from app.services.nas_library_client import NasAgentError


class _Library:
    def __init__(self, *, enabled: bool = True) -> None:
        self.enabled = enabled
        self.imported: dict | None = None
        self.deleted: list[str] | None = None
        self.error: Exception | None = None

    async def import_song(self, payload: dict):
        if self.error is not None:
            raise self.error
        self.imported = payload
        return {"ok": True, "message": "imported"}

    async def delete_songs(self, song_ids: list[str]):
        if self.error is not None:
            raise self.error
        self.deleted = song_ids
        return {"deleted": len(song_ids), "skipped": 0, "errors": 0, "msg": "ok"}


async def _allow_request():
    return None


def _client(library: _Library) -> TestClient:
    app = FastAPI()
    app.state.nas_library = library
    app.include_router(router)
    app.dependency_overrides[verify_api_key] = _allow_request
    return TestClient(app)


def test_library_import_forwards_payload():
    library = _Library()
    with _client(library) as client:
        response = client.post(
            "/v1/library/import",
            json={
                "url": "https://cdn.example/a.mp3",
                "filename": "a.mp3",
                "song": {"title": "A"},
                "force": False,
            },
        )
    assert response.status_code == 200
    assert response.json()["ok"] is True
    assert library.imported["filename"] == "a.mp3"


def test_library_import_maps_duplicate():
    library = _Library()
    library.error = NasAgentError(409, "Song already exists in the Navidrome library")
    with _client(library) as client:
        response = client.post(
            "/v1/library/import",
            json={
                "url": "https://cdn.example/a.mp3",
                "filename": "a.mp3",
                "song": {"title": "A"},
            },
        )
    assert response.status_code == 409
    assert "already exists" in response.json()["detail"]


def test_library_import_unavailable_without_nas_config():
    with _client(_Library(enabled=False)) as client:
        response = client.post(
            "/v1/library/import",
            json={
                "url": "https://cdn.example/a.mp3",
                "filename": "a.mp3",
                "song": {"title": "A"},
            },
        )
    assert response.status_code == 503


def test_library_delete_forwards_ids():
    library = _Library()
    with _client(library) as client:
        response = client.post(
            "/v1/library/delete",
            json={"song_ids": ["one", "two"]},
        )
    assert response.status_code == 200
    assert library.deleted == ["one", "two"]
