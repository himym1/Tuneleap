from fastapi.responses import JSONResponse
from unittest.mock import patch
from fastapi import Request
from limits import RateLimitItemPerMinute
from slowapi.errors import RateLimitExceeded
from slowapi.wrappers import Limit

from app.core.recommendation_http import recommendation_rate_limit_handler


def _request(path: str) -> Request:
    return Request(
        {
            "type": "http",
            "method": "GET",
            "path": path,
            "headers": [],
            "query_string": b"",
            "server": ("test", 80),
            "client": ("test", 1234),
            "scheme": "http",
        }
    )


def _rate_limit_error() -> RateLimitExceeded:
    return RateLimitExceeded(
        Limit(
            RateLimitItemPerMinute(60),
            key_func=lambda: "test",
            scope=None,
            per_method=False,
            methods=None,
            error_message=None,
            exempt_when=None,
            cost=1,
            override_defaults=False,
        )
    )


async def test_non_recommendation_rate_limit_returns_response():
    expected = JSONResponse({"error": "rate limited"}, status_code=429)
    with patch(
        "app.core.recommendation_http._rate_limit_exceeded_handler",
        return_value=expected,
    ):
        response = await recommendation_rate_limit_handler(
            _request("/v1/music/cover"),
            _rate_limit_error(),
        )

    assert response is expected


async def test_recommendation_rate_limit_keeps_contract():
    response = await recommendation_rate_limit_handler(
        _request("/v1/recommendations/sessions"),
        _rate_limit_error(),
    )

    assert response.status_code == 429
    assert b'"code":"recommendation_rate_limited"' in response.body

def test_url_response_accepts_optional_media_metadata():
    from app.models.schemas import UrlResponse

    response = UrlResponse.model_validate(
        {
            "url": "https://cdn.example.com/song.mp3",
            "br": 320,
            "provider": "chksz",
            "source": "tencent",
            "cover_url": "https://cdn.example.com/cover.jpg",
            "lyric": "[00:01.00]First line",
        }
    )

    assert response.cover_url == "https://cdn.example.com/cover.jpg"
    assert response.lyric == "[00:01.00]First line"
