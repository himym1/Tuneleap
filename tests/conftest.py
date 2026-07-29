from __future__ import annotations

import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

import pytest

from app.core.config import Settings


class _FixtureServer(ThreadingHTTPServer):
    routes: dict[str, tuple[int, dict[str, str], bytes]]
    requests: list[str]


class _FixtureHandler(BaseHTTPRequestHandler):
    server: _FixtureServer

    def do_GET(self) -> None:
        self.server.requests.append(self.path)
        path = urlsplit(self.path).path
        status, headers, body = self.server.routes.get(
            path,
            (404, {"Content-Type": "text/plain"}, b"not found"),
        )
        self.send_response(status)
        for name, value in headers.items():
            self.send_header(name, value)
        if "Content-Length" not in headers:
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        return


@pytest.fixture
def media_server():
    mp3 = b"\xff\xfb\x90\x64" + (b"\x00" * 4096)
    png = b"\x89PNG\r\n\x1a\n" + (b"\x00" * 64)
    server = _FixtureServer(("127.0.0.1", 0), _FixtureHandler)
    server.routes = {
        "/audio.mp3": (200, {"Content-Type": "audio/mpeg"}, mp3),
        "/cover.png": (200, {"Content-Type": "image/png"}, png),
        "/large.mp3": (200, {"Content-Type": "audio/mpeg"}, b"x" * 128),
        "/redirect.mp3": (302, {"Location": "/audio.mp3"}, b""),
        "/rest/startScan": (
            200,
            {"Content-Type": "application/json"},
            b'{"subsonic-response":{"status":"ok","scanStatus":{"scanning":true,"count":7}}}',
        ),
    }
    server.requests = []
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}", server
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    music_dir = tmp_path / "music"
    download_dir = music_dir / "download"
    data_dir = tmp_path / "data"
    download_dir.mkdir(parents=True)
    data_dir.mkdir()
    return Settings(
        _env_file=None,
        nas_agent_key="test-nas-agent-key-with-enough-entropy",
        music_dir=str(music_dir),
        download_dir=str(download_dir),
        navidrome_db_path=str(data_dir / "navidrome.db"),
        http_timeout_seconds=2.0,
        max_download_bytes=1024 * 1024,
        max_cover_bytes=1024 * 1024,
        min_free_bytes=0,
        max_redirects=3,
        allow_private_media_urls=True,
    )
