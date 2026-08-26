import asyncio
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.services.import_progress import ImportProgressTracker
from app.services.importer import ImporterService


def _headers(settings) -> dict[str, str]:
    return {"X-API-Key": settings.nas_agent_key}


def test_progress_tracker_computes_speed():
    now = 10.0
    tracker = ImportProgressTracker(clock=lambda: now)
    tracker.start("song.flac", bytes_total=1_000_000)
    snap = tracker.snapshot()
    assert snap.active is True
    assert snap.filename == "song.flac"
    assert snap.bytes_total == 1_000_000
    assert snap.stage == "downloading"

    now = 10.5
    tracker.update(100_000)
    snap = tracker.snapshot()
    assert snap.bytes_received == 100_000
    assert snap.speed_bps == 200_000

    tracker.finishing()
    snap = tracker.snapshot()
    assert snap.stage == "finishing"
    assert snap.bytes_received == 1_000_000
    assert snap.speed_bps == 0

    tracker.complete("imported")
    snap = tracker.snapshot()
    assert snap.active is False
    assert snap.stage == "completed"
    assert snap.message == "imported"
    assert snap.error is None

    tracker.fail("media download timed out")
    snap = tracker.snapshot()
    assert snap.stage == "failed"
    assert snap.error == "media download timed out"

    tracker.clear()
    assert tracker.snapshot().active is False
    assert tracker.snapshot().stage == "idle"


def test_import_progress_idle_when_nothing_running(settings):
    with TestClient(create_app(settings)) as client:
        response = client.get("/v1/nas/import/progress", headers=_headers(settings))
    assert response.status_code == 200
    body = response.json()
    assert body["active"] is False
    assert body["stage"] == "idle"
    assert body["bytes_received"] == 0


@pytest.mark.asyncio
async def test_importer_exposes_live_progress_during_download(settings):
    body = b"\xff\xfb\x90\x64" + (b"\x00" * (256 * 1024))

    class _Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            chunk = 32 * 1024
            for offset in range(0, len(body), chunk):
                self.wfile.write(body[offset : offset + chunk])
                self.wfile.flush()
                time.sleep(0.04)

        def log_message(self, format: str, *args: object) -> None:
            return

    server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    samples = []
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            importer = ImporterService(client, settings)
            task = asyncio.create_task(
                importer.import_track(
                    url=f"http://127.0.0.1:{server.server_port}/slow.mp3",
                    filename="slow.mp3",
                )
            )
            for _ in range(20):
                await asyncio.sleep(0.05)
                samples.append(importer.current_progress())
                if task.done():
                    break
            result = await task
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)

    assert result.ok is True
    assert importer.current_progress().stage == "completed"
    active = [sample for sample in samples if sample.active]
    assert active
    assert any(sample.bytes_received > 0 for sample in active)
    assert any(sample.bytes_total == len(body) for sample in active)
    assert any(sample.filename == "slow.mp3" for sample in active)


@pytest.mark.asyncio
async def test_enqueue_import_returns_before_download_finishes(settings):
    from app.services.importer import ImportBusyError

    body = b"\xff\xfb\x90\x64" + (b"\x00" * (64 * 1024))

    class _Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body[: 16 * 1024])
            self.wfile.flush()
            time.sleep(0.3)
            self.wfile.write(body[16 * 1024 :])

        def log_message(self, format: str, *args: object) -> None:
            return

    server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            importer = ImporterService(client, settings)
            accepted = await importer.enqueue_import(
                url=f"http://127.0.0.1:{server.server_port}/async.mp3",
                filename="async.mp3",
            )
            assert accepted.active is True
            assert accepted.stage == "downloading"
            assert accepted.filename == "async.mp3"
            with pytest.raises(ImportBusyError):
                await importer.enqueue_import(
                    url=f"http://127.0.0.1:{server.server_port}/other.mp3",
                    filename="other.mp3",
                )
            same = await importer.enqueue_import(
                url=f"http://127.0.0.1:{server.server_port}/async.mp3",
                filename="async.mp3",
            )
            assert same.filename == "async.mp3"
            if importer._background_task is not None:
                await importer._background_task
            assert importer.current_progress().stage == "completed"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def test_abort_if_upstream_too_slow_uses_average_rate(settings):
    from app.services.importer import UpstreamTooSlowError

    limited = settings.model_copy(
        update={
            "import_speed_probe_seconds": 0.5,
            "import_min_speed_bps": 50_000,
            "import_slow_min_remaining_bytes": 1024,
        }
    )
    importer = ImporterService(httpx.AsyncClient(), limited)
    started = time.monotonic() - 1.0
    importer._abort_if_upstream_too_slow(started, 2_000, 2_500)
    with pytest.raises(UpstreamTooSlowError):
        importer._abort_if_upstream_too_slow(started, 1_000, 10_000_000)


def test_import_wait_false_returns_202(settings, media_server):
    base_url, _ = media_server
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/nas/import",
            json={
                "url": f"{base_url}/audio.mp3",
                "filename": "queued.mp3",
                "wait": False,
            },
            headers=_headers(settings),
        )
        assert response.status_code == 202, response.text
        assert response.json()["filename"] == "queued.mp3"
        assert response.json()["stage"] in {"downloading", "finishing", "completed"}
        deadline = time.time() + 3
        while time.time() < deadline:
            progress = client.get("/v1/nas/import/progress", headers=_headers(settings))
            if progress.json()["stage"] == "completed":
                break
            time.sleep(0.05)
        assert progress.json()["stage"] == "completed"
