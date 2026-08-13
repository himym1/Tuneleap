# ADR-0001: Multi-server session isolation

- Status: Accepted
- Date: 2026-07-17
- Updated: 2026-07-30

## Context

Navidrome song IDs are unique only inside one server. The application previously switched API clients without changing the namespace used by downloads, playback history, lyrics, or library caches. Different servers could therefore reuse the same song ID and leak stale state across a server switch.

The original companion URL and key were also coupled to the Navidrome host/password. ADR-0004 later split that companion into a public Cloud control plane and a local NAS Agent.

## Decision

`serverId` is the namespace owner for server-specific client state.

- The active ID is stored as `active_server_id`; legacy installs resolve it from the active `servers_list` entry and otherwise use `default`.
- Preferences use `<base-key>::<serverId>` for download tasks and playback history.
- Download files live under `navidrome_downloads/<serverId>/`.
- Lyrics and library caches include or validate the active `serverId`.
- Switching server stops playback, clears the queue, resets playback modes, reloads that server's history, and invalidates stale async work.
- Navidrome, Cloud, and NAS Agent endpoints and credentials are stored independently per server entry.

## Compatibility and migration

- Existing `download_tasks` and `play_history` are copied once to the resolved active server namespace without overwriting scoped values. Legacy keys are then removed.
- Existing downloaded files are not moved; migrated task metadata keeps the original path.
- Empty or retired Cloud URLs resolve to the production HTTPS Origin; Cloud is never inferred from the Navidrome host.
- If NAS Agent URL is empty, the current LAN default is inferred from the Navidrome host on port `8504`.
- The Bearer-auth migration removes legacy companion/Cloud shared API-key values from preferences and platform secure storage. Navidrome credentials are never copied into Cloud authentication; Cloud Refresh Tokens use a dedicated secure-storage key.
- Existing Navidrome/NAS legacy fallback storage remains supported. Cloud Refresh Tokens do not fall back to plain preferences.

## Consequences

- Per-server state can coexist without ID collisions.
- Server switches intentionally clear playback state rather than carrying songs into another server session.
- Cloud and NAS Agent topology can vary per server without changing Navidrome credentials.
- Legacy fallback storage remains supported; removing it requires a separate credential migration.

## Related decision

See [ADR-0004](./0004-cloud-control-plane-and-nas-agent.md) for the Cloud/NAS Agent split and production topology.
