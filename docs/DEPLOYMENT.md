# navidrome-nas-agent — Deployment notes

## Target host

Run beside Navidrome on the NAS so the service can access both `navidrome.db` and the music volume.

| Container path | Example host path | Mode |
|---|---|---|
| `/data` | `/volume1/docker/navidrome_mo/data` | rw |
| `/music` | `/volume4/media3/music` | rw |

The default port is `8503`. Compose binds it to `127.0.0.1` until `NAS_AGENT_BIND_ADDRESS` is set to a specific LAN or Tailscale address.

## Prepare configuration

```bash
cp .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(32))"
# Paste the generated key into NAS_AGENT_KEY.
# Replace the development volume mappings in docker-compose.yml.
docker compose config --quiet
```

Required before startup:

- `NAS_AGENT_KEY` with at least 32 non-space characters
- Correct `MUSIC_DIR`, `DOWNLOAD_DIR`, and `NAVIDROME_DB_PATH` container paths
- Writable mounts for `/data` and `/music`

Optional scan variables: `NAVIDROME_URL`, `NAVIDROME_USER`, `NAVIDROME_PASSWORD`.

## Start and inspect

```bash
docker compose up -d --build
docker compose ps
curl -s http://127.0.0.1:8503/health
docker compose logs --tail=100 navidrome-nas-agent
```

Do not expose the port to the public internet. If remote access is required, prefer Tailscale or a restricted tunnel plus firewall rules.

## Pre-cutover verification

1. Back up the real `navidrome.db`.
2. Confirm `/health` reports all three configuration booleans as `true`.
3. Import representative MP3, FLAC, and M4A tracks; verify tags, cover, lyrics, scan, and playback.
4. Delete one known test track; confirm its file, sidecar, DB row, annotations, bookmarks, and playlist count.
5. Verify container permissions against the actual NAS UID/GID and volume ACLs.
6. Point Flutter `nasAgentUrl` here while keeping `cloudApiUrl` on the VPS.
7. Keep the old backend available until parity checks pass; then retire only its import/delete paths.

Navidrome `:4533` remains the Subsonic playback endpoint and is not replaced by this service.

## Rollback

Stop the agent, restore the backed-up database if a delete validation fails, restore any affected media files from the NAS snapshot, and point Flutter back to the legacy import/delete endpoint.
