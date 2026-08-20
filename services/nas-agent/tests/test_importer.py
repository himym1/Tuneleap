import sqlite3
from pathlib import Path

from fastapi.testclient import TestClient
from mutagen.id3 import ID3

from app.main import create_app


def _headers(settings) -> dict[str, str]:
    return {"X-API-Key": settings.nas_agent_key}


def test_import_downloads_tags_cover_lyrics_and_is_idempotent(settings, media_server):
    base_url, server = media_server
    body = {
        "url": f"{base_url}/redirect.mp3",
        "filename": "solara_netease_1.mp3",
        "picUrl": f"{base_url}/cover.png",
        "lyric": "[00:01.00]First line\n",
        "song": {
            "name": "Track title",
            "artist": "Artist",
            "album": "Album",
            "track": 3,
            "year": 2026,
            "source": "netease",
        },
    }

    with TestClient(create_app(settings)) as client:
        first = client.post("/v1/nas/import", json=body, headers=_headers(settings))
        second = client.post("/v1/nas/import", json=body, headers=_headers(settings))

    assert first.status_code == 200, first.text
    assert first.json()["ok"] is True
    assert second.status_code == 200
    assert second.json()["message"] == "already imported"

    target = Path(settings.download_dir) / body["filename"]
    assert target.exists()
    assert target.with_suffix(".lrc").read_text() == body["lyric"]
    tags = ID3(target)
    assert str(tags["TIT2"]) == "Track title"
    assert str(tags["TPE1"]) == "Artist"
    assert str(tags["TALB"]) == "Album"
    assert str(tags["TRCK"]) == "3"
    assert str(tags["TDRC"]) == "2026"
    assert tags.getall("APIC")[0].mime == "image/png"
    uslt = tags.getall("USLT")
    assert uslt
    assert uslt[0].text == body["lyric"]
    assert sum(urlsplit.startswith("/redirect.mp3") for urlsplit in server.requests) == 1
    assert sum(urlsplit.startswith("/audio.mp3") for urlsplit in server.requests) == 1
    assert sum(urlsplit.startswith("/cover.png") for urlsplit in server.requests) == 1


def test_import_rejects_path_traversal_before_download(settings, media_server):
    base_url, server = media_server
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/nas/import",
            json={"url": f"{base_url}/audio.mp3", "filename": "../escape.mp3"},
            headers=_headers(settings),
        )

    assert response.status_code == 400
    assert server.requests == []


def test_import_rejects_unsupported_extension(settings, media_server):
    base_url, server = media_server
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/nas/import",
            json={"url": f"{base_url}/audio.mp3", "filename": "payload.exe"},
            headers=_headers(settings),
        )

    assert response.status_code == 400
    assert server.requests == []


def test_import_enforces_download_limit(settings, media_server):
    base_url, _ = media_server
    limited = settings.model_copy(update={"max_download_bytes": 64})
    with TestClient(create_app(limited)) as client:
        response = client.post(
            "/v1/nas/import",
            json={"url": f"{base_url}/large.mp3", "filename": "large.mp3"},
            headers=_headers(limited),
        )

    assert response.status_code == 413
    assert not (Path(limited.download_dir) / "large.mp3").exists()


def test_import_preserves_reserved_disk_space(settings, media_server):
    base_url, _ = media_server
    limited = settings.model_copy(update={"min_free_bytes": 10**30})
    with TestClient(create_app(limited)) as client:
        response = client.post(
            "/v1/nas/import",
            json={"url": f"{base_url}/audio.mp3", "filename": "no-space.mp3"},
            headers=_headers(limited),
        )

    assert response.status_code == 507
    assert not (Path(limited.download_dir) / "no-space.mp3").exists()


def test_import_blocks_private_media_urls_by_default(settings, media_server):
    base_url, server = media_server
    hardened = settings.model_copy(update={"allow_private_media_urls": False})
    with TestClient(create_app(hardened)) as client:
        response = client.post(
            "/v1/nas/import",
            json={"url": f"{base_url}/audio.mp3", "filename": "blocked.mp3"},
            headers=_headers(hardened),
        )

    assert response.status_code == 400
    assert server.requests == []


def test_import_rejects_download_directory_outside_music_root(settings, media_server):
    base_url, server = media_server
    outside_root = Path(settings.music_dir).parent / "outside-download"
    invalid = settings.model_copy(update={"download_dir": str(outside_root)})
    with TestClient(create_app(invalid)) as client:
        response = client.post(
            "/v1/nas/import",
            json={"url": f"{base_url}/audio.mp3", "filename": "outside.mp3"},
            headers=_headers(invalid),
        )

    assert response.status_code == 400
    assert not outside_root.exists()
    assert server.requests == []


def test_import_rejects_duplicate_identity_unless_forced(settings, media_server):
    db = sqlite3.connect(settings.navidrome_db_path)
    db.execute("CREATE TABLE media_file(title TEXT, artist TEXT, missing INTEGER DEFAULT 0)")
    db.execute(
        "INSERT INTO media_file(title, artist, missing) VALUES (?, ?, 0)",
        ("花好月圆夜", "杨千嬅 & 任贤齐"),
    )
    db.commit()
    db.close()

    base_url, server = media_server
    body = {
        "url": f"{base_url}/audio.mp3",
        "filename": "another-copy.mp3",
        "song": {"title": "花好月圆夜(国)", "artist": "任贤齐 / 杨千嬅"},
    }
    with TestClient(create_app(settings)) as client:
        rejected = client.post("/v1/nas/import", json=body, headers=_headers(settings))
        forced = client.post(
            "/v1/nas/import",
            json={**body, "force": True},
            headers=_headers(settings),
        )

    assert rejected.status_code == 409
    assert forced.status_code == 200, forced.text
    assert sum(path.startswith("/audio.mp3") for path in server.requests) == 1


def test_import_backfills_lyrics_on_existing_file(settings, media_server):
    base_url, _ = media_server
    body = {
        "url": f"{base_url}/audio.mp3",
        "filename": "solara_netease_via-chksz_93188.mp3",
        "song": {"title": "蝴蝶", "artist": "胡彦斌", "source": "netease"},
    }
    with TestClient(create_app(settings)) as client:
        first = client.post("/v1/nas/import", json=body, headers=_headers(settings))
        second = client.post(
            "/v1/nas/import",
            json={**body, "lyric": "[00:01.00]蝴蝶\n"},
            headers=_headers(settings),
        )

    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text
    assert second.json()["message"] == "already imported"

    target = Path(settings.download_dir) / body["filename"]
    assert target.with_suffix(".lrc").read_text() == "[00:01.00]蝴蝶\n"
    uslt = ID3(target).getall("USLT")
    assert uslt
    assert uslt[0].text == "[00:01.00]蝴蝶\n"
