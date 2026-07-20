# ADR-0001: Multi-server session isolation

- Status: Accepted
- Date: 2026-07-17

## Context

Navidrome song IDs are only unique inside one server. The application previously
switched API clients without changing the namespace used by downloads, playback
history, lyrics, or library caches. Different servers could therefore reuse the
same song ID and leak stale state across a server switch. The companion online
backend was also inferred from the Navidrome host and reused the Navidrome
password as its API key.

## Decision

`serverId` is the namespace owner for server-specific client state.

- The active ID is stored as `active_server_id`; legacy installs resolve it from
  the active `servers_list` entry and otherwise use `default`.
- Preferences use `<base-key>::<serverId>` for download tasks and playback
  history.
- New download files live under `navidrome_downloads/<serverId>/`.
- Lyrics and library caches include or validate the active `serverId`.
- Switching server stops playback, clears the active queue, resets playback
  modes, reloads that server's history, and invalidates stale async work.
- The companion backend has independent `backendUrl` and `backendApiKey`
  configuration. Its API key is stored separately from the Navidrome password.

## Compatibility and migration

- Existing `download_tasks` and `play_history` are copied to the resolved active
  server namespace once, without overwriting an existing scoped value. The
  legacy keys are then removed.
- Existing downloaded files are not moved or deleted; migrated task metadata
  continues to reference their original paths.
- For an old server entry with no backend fields, the backend URL is inferred
  once from the Navidrome host on port `8503`, and the existing password is
  copied once into the independent backend API-key store. A migration marker
  prevents future Navidrome password changes from changing the backend key.
- If secure storage is unavailable, secrets remain in the existing preferences
  fallback instead of being discarded.

## Consequences

- Per-server state can coexist without ID collisions.
- Server switches intentionally stop and clear the current queue rather than
  silently carrying songs into another server session.
- Deployment topologies can configure a companion backend independently.
- Legacy fallback storage remains supported on platforms where secure storage
  is unavailable; removing that fallback requires a separate migration.
