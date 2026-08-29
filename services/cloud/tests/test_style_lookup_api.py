from __future__ import annotations

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.music import router
from app.core.auth import verify_api_key
from app.services.style_lookup import StyleLookupHit


class _Lookup:
    async def lookup_many(self, tracks):
        return [
            StyleLookupHit(
                title=tracks[0]["title"],
                artist=tracks[0]["artist"],
                style="华语流行",
                raw_genre="国语流行",
                provider="itunes",
            )
        ]


async def _allow_request():
    return None


def _client(lookup=None) -> TestClient:
    app = FastAPI()
    app.state.style_lookup = lookup or _Lookup()
    app.include_router(router)
    app.dependency_overrides[verify_api_key] = _allow_request
    return TestClient(app)


def test_style_lookup_returns_closed_style():
    with _client() as client:
        response = client.post(
            "/v1/music/style-lookup",
            json={"tracks": [{"title": "晴天", "artist": "周杰伦", "album": "叶惠美"}]},
        )
    assert response.status_code == 200
    item = response.json()["items"][0]
    assert item["style"] == "华语流行"
    assert item["provider"] == "itunes"


def test_style_lookup_rejects_empty_and_oversized_batches():
    with _client() as client:
        empty = client.post("/v1/music/style-lookup", json={"tracks": []})
        huge = client.post(
            "/v1/music/style-lookup",
            json={"tracks": [{"title": f"t{i}", "artist": "a"} for i in range(21)]},
        )
    assert empty.status_code == 400
    assert huge.status_code == 400
