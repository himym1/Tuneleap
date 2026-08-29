from __future__ import annotations

import pytest

from app.services.style_lookup import StyleLookupService


class _Response:
    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"status {self.status_code}")

    def json(self):
        return self._payload


class _FakeClient:
    def __init__(self, responder):
        self.responder = responder
        self.calls: list[dict] = []

    async def get(self, url, params=None, headers=None):
        self.calls.append({"url": url, "params": dict(params or {})})
        return self.responder(url, dict(params or {}))


def _service(responder) -> StyleLookupService:
    return StyleLookupService(
        _FakeClient(responder),
        itunes_min_interval=0,
        mb_min_interval=0,
    )


@pytest.mark.asyncio
async def test_itunes_song_identity_maps_cn_genre():
    def responder(url, params):
        assert "itunes.apple.com" in url
        assert params["country"] == "cn"
        return _Response(
            {
                "results": [
                    {
                        "trackName": "晴天",
                        "artistName": "周杰伦",
                        "primaryGenreName": "国语流行",
                    }
                ]
            }
        )

    hit = await _service(responder).lookup_one(
        {"title": "晴天", "artist": "周杰伦", "album": "叶惠美"}
    )
    assert hit.style == "华语流行"
    assert hit.provider == "itunes"
    assert hit.raw_genre == "国语流行"


@pytest.mark.asyncio
async def test_album_group_shares_one_itunes_lookup():
    calls = {"album": 0, "song": 0}

    def responder(url, params):
        if params.get("entity") == "album":
            calls["album"] += 1
            return _Response(
                {
                    "results": [
                        {
                            "collectionName": "叶惠美",
                            "artistName": "周杰伦",
                            "primaryGenreName": "国语流行",
                        }
                    ]
                }
            )
        calls["song"] += 1
        return _Response({"results": []})

    hits = await _service(responder).lookup_many(
        [
            {"title": "晴天", "artist": "周杰伦", "album": "叶惠美"},
            {"title": "三年二班", "artist": "周杰伦", "album": "叶惠美"},
        ]
    )
    assert [hit.style for hit in hits] == ["华语流行", "华语流行"]
    assert calls["album"] == 1
    assert calls["song"] == 0


@pytest.mark.asyncio
async def test_musicbrainz_used_when_itunes_has_no_genre():
    def responder(url, params):
        if "itunes.apple.com" in url:
            return _Response({"results": []})
        if url.endswith("/recording"):
            return _Response(
                {
                    "recordings": [
                        {
                            "title": "Blank Space",
                            "artist-credit": [{"name": "Taylor Swift"}],
                            "tags": [{"name": "pop", "count": 12}],
                        }
                    ]
                }
            )
        raise AssertionError(url)

    hit = await _service(responder).lookup_one(
        {"title": "Blank Space", "artist": "Taylor Swift", "album": "1989"}
    )
    assert hit.style == "欧美流行"
    assert hit.provider == "musicbrainz"


@pytest.mark.asyncio
async def test_title_markers_apply_when_upstreams_miss():
    def responder(url, params):
        if "itunes.apple.com" in url:
            return _Response({"results": []})
        return _Response({"recordings": []})

    hit = await _service(responder).lookup_one(
        {"title": "恋爱情歌", "artist": "歌手", "album": "精选"}
    )
    assert hit.style == "抒情情歌"
    assert hit.provider == "title-markers"


@pytest.mark.asyncio
async def test_identity_cache_skips_second_http():
    client = _FakeClient(
        lambda url, params: _Response(
            {
                "results": [
                    {
                        "trackName": "晴天",
                        "artistName": "周杰伦",
                        "primaryGenreName": "Mandopop",
                    }
                ]
            }
        )
    )
    service = StyleLookupService(client, itunes_min_interval=0, mb_min_interval=0)
    first = await service.lookup_one({"title": "晴天", "artist": "周杰伦"})
    second = await service.lookup_one({"title": "晴天", "artist": "周杰伦"})
    assert first.style == second.style == "华语流行"
    assert len(client.calls) == 1
