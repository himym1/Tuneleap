# navidrome-nas-agent — Development guide

Implemented local import/delete agent. Keep this service small and limited to the accepted ADR boundary.

Authority: `navidrome_player/docs/adr/0004-cloud-control-plane-and-nas-agent.md`.

## Scope

1. Accept a direct media URL plus metadata and write a tagged file below `DOWNLOAD_DIR`.
2. Delete Navidrome tracks by ID from SQLite and disk.
3. Expose only agent APIs on LAN, Tailscale, or a restricted tunnel.
4. Use a dedicated `NAS_AGENT_KEY`.

Non-goals remain online search, lyrics lookup, user registration, update hosting, and embedding upstream music servers.

## Implementation status

| Phase | Status | Implementation |
|---|---|---|
| P0 import | Complete | Streamed download, path validation, tags, cover, `.lrc` |
| P0 delete | Complete | DB lookup, reversible file staging, related-row cleanup |
| P1 APIs | Complete | `/v1/nas/import`, `/v1/songs/delete`, `/v1/nas/scan` |
| P2 resilience | Complete | Idempotency, size/space limits, JSON audit events |
| P2 Flutter body | Complete | Accepts `picUrl`, `name`, and `lyric` aliases/fields |

## Import flow

```text
App -> navidrome-cloud (search + direct URL)
App -> navidrome-nas-agent POST /v1/nas/import
Agent -> validate URL/redirects -> temporary streamed file
Agent -> tags + cover + optional .lrc -> atomic rename
App/Agent -> optional POST /v1/nas/scan
```

Imports are serialized by one process-wide lock. Inside that lock, the agent first preserves filename idempotency, then rejects matching normalized title/artist identities with HTTP 409. The client may send `force: true` only after the user explicitly chooses to import the duplicate.

## Delete flow

```text
App -> Agent POST /v1/songs/delete { song_ids: [...] }
Agent -> resolve DB path below MUSIC_DIR
Agent -> atomically rename audio/.lrc to hidden staging files
Agent -> delete related SQLite rows and commit
Agent -> unlink staged files; restore them if the DB transaction fails
```

Requests accept 1–50 unique IDs. Unknown IDs increment `skipped`; unsafe paths and per-song failures increment `errors` without aborting unrelated IDs.

## Local development

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
# Generate and set NAS_AGENT_KEY before starting.
python -c "import secrets; print(secrets.token_urlsafe(32))"
mkdir -p data/music/download
uvicorn app.main:app --reload --host 127.0.0.1 --port 8503
```

## Quality gates

```bash
ruff check .
ruff format --check .
pytest -q
docker compose config --quiet
```

Tests use a temporary HTTP server, real temporary files, and a real SQLite fixture. They cover authorization, cloud-route absence, path traversal, private URL blocking, redirect handling, size/space limits, tags/cover/lyrics, idempotency, DB/file deletion, rollback, unknown IDs, and Subsonic token auth.

## Definition of done (agent MVP)

- [x] Import writes an audio file under `DOWNLOAD_DIR` with tags
- [x] Delete removes the file, sidecar, and DB rows for a fixture database
- [x] No search/auth/update routes exist
- [x] Tests cover auth, path rejection, import/delete happy paths, and rollback

## Environment-only integration gates

These cannot be proven by local fixtures and must pass before NAS cutover:

- Validate the mounted Navidrome version's actual SQLite schema against deletion queries.
- Verify container UID/GID can rename and delete files on both mounted volumes.
- Import representative real MP3, FLAC, and M4A files and confirm Navidrome playback.
- Back up `navidrome.db`, run a known-song delete, and verify Navidrome remains healthy.
- Wire Flutter's separate `cloudApiUrl` and `nasAgentUrl`; the legacy app endpoint is not exposed here.
