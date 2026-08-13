from __future__ import annotations

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.music import router
from app.core.auth import verify_api_key
from app.services.music_facade import MusicSearchSelectionError


class _Facade:
    async def search_first_success(self, *args, **kwargs):
        raise MusicSearchSelectionError(
            "music adapter meting does not support source migu"
        )


async def _allow_request():
    return None


def test_search_selection_error_maps_to_bad_request():
    app = FastAPI()
    app.state.music_facade = _Facade()
    app.include_router(router)
    app.dependency_overrides[verify_api_key] = _allow_request

    with TestClient(app) as client:
        response = client.get(
            "/v1/music/search",
            params={"q": "test", "source": "migu", "provider": "meting"},
        )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "music adapter meting does not support source migu"
    )
