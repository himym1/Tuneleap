import sqlite3
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app


def _headers(settings) -> dict[str, str]:
    return {"X-API-Key": settings.nas_agent_key}


def _create_library_db(path: str, rows: list[tuple[str, str]]) -> None:
    db = sqlite3.connect(path)
    db.executescript(
        """
        CREATE TABLE media_file(id TEXT PRIMARY KEY, path TEXT NOT NULL);
        CREATE TABLE playlist(id TEXT PRIMARY KEY, song_count INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE playlist_tracks(playlist_id TEXT, media_file_id TEXT);
        CREATE TABLE annotation(item_id TEXT);
        CREATE TABLE bookmark(item_id TEXT);
        CREATE TABLE media_file_artists(media_file_id TEXT, artist_id TEXT);
        CREATE TABLE scrobbles(media_file_id TEXT, user_id TEXT);
        CREATE TABLE scrobble_buffer(media_file_id TEXT, user_id TEXT);
        INSERT INTO playlist(id, song_count) VALUES ('playlist-1', 0);
        """
    )
    db.executemany("INSERT INTO media_file(id, path) VALUES (?, ?)", rows)
    for song_id, _ in rows:
        db.execute(
            "INSERT INTO playlist_tracks(playlist_id, media_file_id) VALUES ('playlist-1', ?)",
            (song_id,),
        )
        db.execute("INSERT INTO annotation(item_id) VALUES (?)", (song_id,))
        db.execute("INSERT INTO bookmark(item_id) VALUES (?)", (song_id,))
        db.execute(
            "INSERT INTO media_file_artists(media_file_id, artist_id) VALUES (?, 'artist-1')",
            (song_id,),
        )
        db.execute(
            "INSERT INTO scrobbles(media_file_id, user_id) VALUES (?, 'user-1')",
            (song_id,),
        )
    db.execute("UPDATE playlist SET song_count = ?", (len(rows),))
    db.commit()
    db.close()


def test_delete_removes_file_sidecar_and_database_rows(settings):
    target = Path(settings.download_dir) / "song.mp3"
    target.write_bytes(b"audio")
    target.with_suffix(".lrc").write_text("lyrics")
    _create_library_db(settings.navidrome_db_path, [("song-1", "download/song.mp3")])

    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/songs/delete",
            json={"song_ids": ["song-1", "missing"]},
            headers=_headers(settings),
        )

    assert response.status_code == 200, response.text
    assert response.json()["deleted"] == 1
    assert response.json()["skipped"] == 1
    assert response.json()["errors"] == 0
    assert not target.exists()
    assert not target.with_suffix(".lrc").exists()

    db = sqlite3.connect(settings.navidrome_db_path)
    assert db.execute("SELECT COUNT(*) FROM media_file").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM playlist_tracks").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM annotation").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM bookmark").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM media_file_artists").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM scrobbles").fetchone()[0] == 0
    assert db.execute("SELECT song_count FROM playlist").fetchone()[0] == 0
    db.close()


def test_delete_rejects_database_path_outside_music_root(settings):
    outside = Path(settings.music_dir).parent / "outside.mp3"
    outside.write_bytes(b"keep")
    _create_library_db(settings.navidrome_db_path, [("unsafe", "../outside.mp3")])

    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/songs/delete",
            json={"song_ids": ["unsafe"]},
            headers=_headers(settings),
        )

    assert response.status_code == 200
    assert response.json()["errors"] == 1
    assert outside.exists()
    db = sqlite3.connect(settings.navidrome_db_path)
    assert db.execute("SELECT COUNT(*) FROM media_file WHERE id = 'unsafe'").fetchone()[0] == 1
    db.close()


def test_delete_rejects_duplicate_ids(settings):
    _create_library_db(settings.navidrome_db_path, [])
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/songs/delete",
            json={"song_ids": ["same", "same"]},
            headers=_headers(settings),
        )

    assert response.status_code == 422


def test_delete_reports_missing_database(settings):
    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/songs/delete",
            json={"song_ids": ["song-1"]},
            headers=_headers(settings),
        )

    assert response.status_code == 503


def test_delete_restores_audio_when_sidecar_staging_fails(settings):
    target = Path(settings.download_dir) / "song.mp3"
    target.write_bytes(b"audio")
    target.with_suffix(".lrc").mkdir()
    _create_library_db(settings.navidrome_db_path, [("song-1", "download/song.mp3")])

    with TestClient(create_app(settings)) as client:
        response = client.post(
            "/v1/songs/delete",
            json={"song_ids": ["song-1"]},
            headers=_headers(settings),
        )

    assert response.status_code == 200
    assert response.json()["errors"] == 1
    assert target.read_bytes() == b"audio"
    assert target.with_suffix(".lrc").is_dir()
    db = sqlite3.connect(settings.navidrome_db_path)
    assert db.execute("SELECT COUNT(*) FROM media_file WHERE id = 'song-1'").fetchone()[0] == 1
    db.close()
