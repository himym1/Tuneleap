# navidrome-nas-agent — Security notes

## Trust boundaries

| Caller | Allowed capability |
|---|---|
| Flutter on LAN/Tailscale with `NAS_AGENT_KEY` | Import, delete, scan |
| Cloud with a future short-lived ticket | Not implemented |
| Anonymous internet | Health only; no mutation |

## Authentication and secrets

- Mutation APIs accept only the `X-API-Key` header.
- `NAS_AGENT_KEY` is required, must contain at least 32 non-space characters, and rejects known placeholders.
- Comparison uses `secrets.compare_digest`.
- Navidrome credentials are used only for optional Subsonic scan calls.
- The scan request sends a random salt plus MD5 protocol token, never the plaintext password.
- Cloud credentials and Navidrome passwords are never accepted as the agent key.

Generate a key with `python -c "import secrets; print(secrets.token_urlsafe(32))"`. Do not commit `.env`.

## Import controls

- Reject absolute paths, separators, control/NUL characters, hidden names, and unsupported extensions.
- Resolve `MUSIC_DIR`, `DOWNLOAD_DIR`, and final targets before writing; reject directory escape and symlinks.
- Download into a same-filesystem temporary file, `fsync`, tag, then atomically rename.
- Allow only HTTP(S), reject URL credentials, validate every redirect, and block non-global/localhost targets by default.
- Set `ALLOW_PRIVATE_MEDIA_URLS=true` only when media intentionally comes from a trusted private host.
- Cap audio/cover bytes, timeout requests, and preserve `MIN_FREE_BYTES`.
- Accept only JPEG/PNG covers and treat cover failure as non-fatal.

URL validation is defense in depth, not an egress firewall. Production should still restrict the container's outbound network where practical.

## Delete controls

- Accept only caller-provided IDs and parameterize all SQL values.
- Resolve DB paths below `MUSIC_DIR`; reject `..`, unexpected prefixes, and symlinked media files.
- Rename audio and `.lrc` files to hidden staging names before changing SQLite.
- Restore staged files if the transaction fails; unlink them only after commit.
- Delete only fixed, known related tables when they exist.
- Back up `navidrome.db` and verify the target Navidrome schema before first production deletion.

## Audit

Import, delete, cover-skip, and scan outcomes are emitted as one-line JSON logs. URLs, API keys, and passwords are not logged.

## Network and browser access

- Compose binds to `127.0.0.1` unless `NAS_AGENT_BIND_ADDRESS` is explicitly changed.
- Prefer a LAN/Tailscale address plus host firewall rules.
- CORS is disabled by default; set a narrow comma-separated `CORS_ORIGINS` only for a browser client.
- If using a tunnel, expose only required agent paths and keep API-key authentication enabled.
