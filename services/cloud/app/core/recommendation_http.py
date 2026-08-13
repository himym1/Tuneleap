"""Recommendation-only ASGI request limits and FastAPI error handlers."""
from __future__ import annotations

from app.core.recommendation_errors import RecommendationSessionExpired, RecommendationTemporarilyUnavailable
from fastapi import HTTPException, Request
from fastapi.exception_handlers import (
    http_exception_handler,
    request_validation_exception_handler,
)
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from starlette.types import ASGIApp, Message, Receive, Scope, Send

MAX_BODY = {
    ("POST", "/v1/recommendations/sessions"): 65536,
    ("POST", "/v1/recommendations/feedback"): 4096,
}
RECOMMENDATION_PREFIX = "/v1/recommendations"


def _is_recommendation(request: Request) -> bool:
    return request.url.path == RECOMMENDATION_PREFIX or request.url.path.startswith(RECOMMENDATION_PREFIX + "/")


def error_response(status_code: int, code: str, detail: str, retryable: bool = False) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"contractVersion": 1, "code": code, "detail": detail, "retryable": retryable})


class RecommendationBodyLimitMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope.get("type") != "http":
            await self.app(scope, receive, send)
            return
        maximum = MAX_BODY.get((scope.get("method", "").upper(), scope.get("path", "")))
        if maximum is None:
            await self.app(scope, receive, send)
            return
        content_lengths = [value for name, value in scope.get("headers", ()) if name.lower() == b"content-length"]
        if len(content_lengths) > 1:
            await error_response(400, "recommendation_invalid_request", "invalid content-length header")(scope, receive, send)
            return
        if content_lengths:
            raw_length = content_lengths[0]
            if not raw_length or not raw_length.isascii() or not raw_length.isdigit():
                await error_response(400, "recommendation_invalid_request", "invalid content-length header")(scope, receive, send)
                return
            declared_length = int(raw_length)
            if declared_length > maximum:
                await error_response(400, "recommendation_request_too_large", "request body exceeds the allowed limit")(scope, receive, send)
                return
        messages: list[Message] = []
        total = 0
        while True:
            message = await receive()
            messages.append(message)
            if message.get("type") != "http.request":
                break
            total += len(message.get("body", b""))
            if total > maximum:
                await error_response(400, "recommendation_request_too_large", "request body exceeds the allowed limit")(scope, receive, send)
                return
            if not message.get("more_body", False):
                break
        index = 0
        index = 0
        async def replay() -> Message:
            nonlocal index
            if index < len(messages):
                value = messages[index]
                index += 1
                return value
            return await receive()
        await self.app(scope, replay, send)


async def recommendation_validation_handler(request: Request, exc: RequestValidationError):
    if not _is_recommendation(request):
        return await request_validation_exception_handler(request, exc)
    return error_response(400, "recommendation_invalid_request", "request validation failed")


async def recommendation_http_handler(request: Request, exc: HTTPException):
    if not _is_recommendation(request):
        return await http_exception_handler(request, exc)
    if exc.status_code == 401:
        return error_response(401, "recommendation_unauthorized", "authentication required")
    return error_response(exc.status_code, "recommendation_http_error", "request failed")


async def recommendation_value_error_handler(request: Request, exc: ValueError):
    if not _is_recommendation(request):
        raise exc
    return error_response(400, "recommendation_invalid_request", "invalid recommendation request")


async def recommendation_runtime_error_handler(request: Request, exc: RuntimeError):
    if not _is_recommendation(request):
        raise exc
    if isinstance(exc, RecommendationSessionExpired):
        return error_response(410, "recommendation_session_expired", "recommendation session expired")
    if isinstance(exc, RecommendationTemporarilyUnavailable):
        return error_response(503, "recommendation_temporarily_unavailable", "recommendations temporarily unavailable", True)
    return error_response(500, "recommendation_internal_error", "internal server error")


async def recommendation_exception_handler(request: Request, exc: Exception):
    if not _is_recommendation(request):
        raise exc
    return error_response(500, "recommendation_internal_error", "internal server error")


async def recommendation_rate_limit_handler(request: Request, exc: RateLimitExceeded):
    if not _is_recommendation(request):
        return _rate_limit_exceeded_handler(request, exc)
    return error_response(429, "recommendation_rate_limited", "rate limit exceeded", True)
