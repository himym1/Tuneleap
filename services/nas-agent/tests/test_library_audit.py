import asyncio
import sqlite3
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app
from app.services.library_audit import (
    LibraryAuditRules,
    LibraryTrack,
    classify_track,
    duplicate_version_ids,
)
from app.services.library_audit_store import audit_state_path
from app.services.library_audit_job import LibraryAuditService


def _headers(settings) -> dict[str, str]:
    return {"X-API-Key": settings.nas_agent_key}


def _create_audit_db(path: str, rows: list[tuple]) -> None:
    db = sqlite3.connect(path)
    db.execute(
        """
        CREATE TABLE media_file(
            id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            title TEXT,
            artist TEXT,
            album TEXT,
            suffix TEXT,
            bit_rate INTEGER,
            duration INTEGER,
            sample_rate INTEGER,
            missing INTEGER DEFAULT 0
        )
        """
    )
    db.executemany(
        "INSERT INTO media_file(id, path, title, artist, album, suffix, bit_rate, duration, sample_rate, missing) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        rows,
    )
    db.commit()
    db.close()


def test_classify_track_rules():
    assert classify_track(
        LibraryTrack(song_id="1", suffix="mp3", bit_rate=128)
    ) == ["low_bitrate"]
    assert classify_track(
        LibraryTrack(song_id="2", suffix="mp3", bit_rate=320)
    ) == []
    assert classify_track(
        LibraryTrack(song_id="3", suffix="flac", bit_rate=412)
    ) == ["suspect_transcode"]
    assert classify_track(
        LibraryTrack(song_id="4", suffix="flac", bit_rate=944)
    ) == []
    assert classify_track(
        LibraryTrack(song_id="5", suffix="flac", bit_rate=999, missing_file=True)
    ) == ["missing"]
    assert classify_track(LibraryTrack(song_id="6", suffix="flac", bit_rate=0)) == []


def test_classify_track_uses_custom_thresholds():
    track = LibraryTrack(song_id="1", suffix="mp3", bit_rate=256)
    assert classify_track(track) == ["low_bitrate"]
    assert classify_track(track, LibraryAuditRules(low_bitrate_kbps=256)) == []
    assert classify_track(
        LibraryTrack(song_id="2", suffix="flac", bit_rate=480),
        LibraryAuditRules(suspect_lossless_kbps=400),
    ) == []


def test_duplicate_version_respects_duration_tolerance():
    tracks = [
        LibraryTrack(song_id="a", title="美人鱼", artist="林俊杰", duration=254),
        LibraryTrack(song_id="b", title="美人鱼", artist="林俊杰", duration=219),
    ]
    assert duplicate_version_ids(tracks) == {"a", "b"}
    assert (
        duplicate_version_ids(tracks, LibraryAuditRules(duration_tolerance_seconds=40))
        == set()
    )


def test_duplicate_version_uses_duration_gap():
    tracks = [
        LibraryTrack(song_id="a", title="美人鱼", artist="林俊杰", duration=254),
        LibraryTrack(song_id="b", title="美人鱼", artist="林俊杰", duration=219),
        LibraryTrack(song_id="c", title="江南", artist="林俊杰", duration=267),
        LibraryTrack(song_id="d", title="江南", artist="林俊杰", duration=268),
    ]
    assert duplicate_version_ids(tracks) == {"a", "b"}


def _wait_for_stage(client: TestClient, settings, *stages: str, timeout: float = 3.0):
    import time

    end = time.monotonic() + timeout
    while time.monotonic() < end:
        response = client.get("/v1/nas/library-audit", headers=_headers(settings))
        assert response.status_code == 200
        if response.json()["stage"] in stages:
            return response.json()
        time.sleep(0.02)
    raise AssertionError(f"audit did not reach {stages}")


def test_library_audit_flags_issues_without_paths(settings):
    music = Path(settings.music_dir)
    (music / "good.flac").write_bytes(b"flac")
    (music / "low.mp3").write_bytes(b"mp3")
    (music / "thin.flac").write_bytes(b"flac")
    (music / "v1.flac").write_bytes(b"flac")
    (music / "v2.flac").write_bytes(b"flac")
    _create_audit_db(
        settings.navidrome_db_path,
        [
            ("good", "good.flac", "好歌", "歌手", "专辑", "flac", 944, 210, 44100, 0),
            ("low", "low.mp3", "低码率", "歌手", "专辑", "mp3", 128, 200, 44100, 0),
            ("thin", "thin.flac", "假无损", "歌手", "专辑", "flac", 320, 200, 44100, 0),
            ("gone", "gone.mp3", "丢失", "歌手", "专辑", "mp3", 320, 180, 44100, 0),
            ("v1", "v1.flac", "美人鱼", "林俊杰", "第二天堂", "flac", 944, 254, 44100, 0),
            ("v2", "v2.flac", "美人鱼", "林俊杰", "第二天堂", "flac", 944, 219, 44100, 0),
        ],
    )

    with TestClient(create_app(settings)) as client:
        started = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert started.status_code == 202, started.text
        snapshot = _wait_for_stage(client, settings, "completed")
        assert snapshot["summary"]["scanned"] == 6
        assert snapshot["summary"]["passed"] == 1
        assert snapshot["summary"]["issues"] == 5
        assert snapshot["summary"]["low_bitrate"] == 1
        assert snapshot["summary"]["suspect_transcode"] == 1
        assert snapshot["summary"]["missing"] == 1
        assert snapshot["summary"]["duplicate_version"] == 2

        findings = client.get("/v1/nas/library-audit/findings", headers=_headers(settings))
        assert findings.status_code == 200
        body = findings.json()
        assert body["total"] == 5
        ids = {item["song_id"] for item in body["items"]}
        assert ids == {"low", "thin", "gone", "v1", "v2"}
        assert all("path" not in item for item in body["items"])

        filtered = client.get(
            "/v1/nas/library-audit/findings",
            params={"code": "low_bitrate"},
            headers=_headers(settings),
        )
        assert filtered.json()["total"] == 1
        assert filtered.json()["items"][0]["song_id"] == "low"


def test_library_audit_uses_request_thresholds(settings):
    music = Path(settings.music_dir)
    (music / "ok.mp3").write_bytes(b"mp3")
    _create_audit_db(
        settings.navidrome_db_path,
        [
            ("ok", "ok.mp3", "刚好", "歌手", "专辑", "mp3", 256, 200, 44100, 0),
        ],
    )

    with TestClient(create_app(settings)) as client:
        started = client.post(
            "/v1/nas/library-audit",
            json={"low_bitrate_kbps": 256},
            headers=_headers(settings),
        )
        assert started.status_code == 202, started.text
        snapshot = _wait_for_stage(client, settings, "completed")
        assert snapshot["summary"]["issues"] == 0
        assert snapshot["summary"]["low_bitrate"] == 0

        rejected = client.post(
            "/v1/nas/library-audit",
            json={"low_bitrate_kbps": 400},
            headers=_headers(settings),
        )
        assert rejected.status_code == 422


def test_library_audit_persists_last_report(settings):
    music = Path(settings.music_dir)
    (music / "low.mp3").write_bytes(b"mp3")
    _create_audit_db(
        settings.navidrome_db_path,
        [
            ("low", "low.mp3", "低码率", "歌手", "专辑", "mp3", 128, 200, 44100, 0),
        ],
    )

    with TestClient(create_app(settings)) as client:
        started = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert started.status_code == 202, started.text
        _wait_for_stage(client, settings, "completed")

    assert audit_state_path(settings).is_file()

    with TestClient(create_app(settings)) as client:
        snapshot = client.get("/v1/nas/library-audit", headers=_headers(settings))
        assert snapshot.status_code == 200
        assert snapshot.json()["stage"] == "completed"
        assert snapshot.json()["summary"]["low_bitrate"] == 1
        findings = client.get("/v1/nas/library-audit/findings", headers=_headers(settings))
        assert findings.json()["items"][0]["song_id"] == "low"
        assert "path" not in findings.json()["items"][0]


def test_library_audit_requires_key_and_database(settings):
    with TestClient(create_app(settings)) as client:
        assert client.get("/v1/nas/library-audit").status_code == 401
        missing = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert missing.status_code == 503


def test_library_audit_second_start_conflicts(settings, monkeypatch):
    _create_audit_db(settings.navidrome_db_path, [])
    release = asyncio.Event()

    async def _blocked(self):
        await release.wait()
        return []

    monkeypatch.setattr(LibraryAuditService, "_load_tracks", _blocked)
    with TestClient(create_app(settings)) as client:
        first = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert first.status_code == 202
        second = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert second.status_code == 409
        release.set()
        _wait_for_stage(client, settings, "completed", "cancelled", "failed")


def test_library_audit_cancel(settings, monkeypatch):
    _create_audit_db(settings.navidrome_db_path, [])
    release = asyncio.Event()

    async def _blocked(self):
        await release.wait()
        return []

    monkeypatch.setattr(LibraryAuditService, "_load_tracks", _blocked)
    with TestClient(create_app(settings)) as client:
        started = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert started.status_code == 202
        cancelled = client.post("/v1/nas/library-audit/cancel", headers=_headers(settings))
        assert cancelled.status_code == 200
        release.set()
        snapshot = _wait_for_stage(client, settings, "cancelled")
        assert snapshot["stage"] == "cancelled"


def test_library_audit_deep_requires_fast_scan_first(settings):
    _create_audit_db(settings.navidrome_db_path, [])
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/nas/library-audit/deep",
            json={"scope": "findings"},
            headers=_headers(settings),
        )
    assert response.status_code == 400


def test_library_audit_deep_scan_updates_findings(settings):
    from test_library_audit_spectrum import _harmonics, _write_wav

    music = Path(settings.music_dir)
    lossy = music / "lossy.wav"
    genuine = music / "genuine.wav"
    _write_wav(lossy, 44100, _harmonics(44100, 3, 15000))
    _write_wav(genuine, 44100, _harmonics(44100, 3, 21000))
    _create_audit_db(
        settings.navidrome_db_path,
        [
            ("lossy", "lossy.wav", "假无损", "歌手", "专辑", "wav", 320, 3, 44100, 0),
            ("genuine", "genuine.wav", "真无损", "歌手", "专辑", "wav", 320, 3, 44100, 0),
        ],
    )

    with TestClient(create_app(settings)) as client:
        started = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert started.status_code == 202
        _wait_for_stage(client, settings, "completed")
        fast = client.get("/v1/nas/library-audit/findings", headers=_headers(settings))
        assert {item["song_id"] for item in fast.json()["items"]} == {"lossy", "genuine"}

        deep = client.post(
            "/v1/nas/library-audit/deep",
            json={"scope": "findings"},
            headers=_headers(settings),
        )
        assert deep.status_code == 202
        snapshot = _wait_for_stage(client, settings, "completed")
        assert snapshot["message"] == "deep scan completed"
        assert snapshot["summary"]["lossy_transcode"] == 1
        assert snapshot["summary"]["suspect_transcode"] == 0

        findings = client.get("/v1/nas/library-audit/findings", headers=_headers(settings))
        items = {item["song_id"]: item for item in findings.json()["items"]}
        assert "genuine" not in items
        assert "lossy_transcode" in items["lossy"]["codes"]
        assert "suspect_transcode" not in items["lossy"]["codes"]
        assert items["lossy"]["cutoff_hz"] < 18500
        assert all("path" not in item for item in items.values())


def test_library_audit_deep_after_restart_uses_persisted_findings(settings):
    from test_library_audit_spectrum import _harmonics, _write_wav

    music = Path(settings.music_dir)
    lossy = music / "lossy.wav"
    _write_wav(lossy, 44100, _harmonics(44100, 3, 15000))
    _create_audit_db(
        settings.navidrome_db_path,
        [
            ("lossy", "lossy.wav", "假无损", "歌手", "专辑", "wav", 320, 3, 44100, 0),
        ],
    )

    with TestClient(create_app(settings)) as client:
        started = client.post("/v1/nas/library-audit", headers=_headers(settings))
        assert started.status_code == 202, started.text
        _wait_for_stage(client, settings, "completed")

    with TestClient(create_app(settings)) as client:
        restored = client.get("/v1/nas/library-audit", headers=_headers(settings))
        assert restored.json()["stage"] == "completed"
        deep = client.post(
            "/v1/nas/library-audit/deep",
            json={"scope": "findings"},
            headers=_headers(settings),
        )
        assert deep.status_code == 202, deep.text
        snapshot = _wait_for_stage(client, settings, "completed")
        assert snapshot["summary"]["lossy_transcode"] == 1
        findings = client.get("/v1/nas/library-audit/findings", headers=_headers(settings))
        assert "lossy_transcode" in findings.json()["items"][0]["codes"]
