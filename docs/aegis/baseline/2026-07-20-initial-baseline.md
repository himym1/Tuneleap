# Navidrome Player Initial Baseline

Date: 2026-07-20
Status: initial dual-baseline snapshot

## Purpose

Capture the current product and architecture boundary needed to design cross-App/Backend features without re-auditing unrelated surfaces.

## Product / Requirement baseline

- Flutter client supports Android, macOS, and Windows.
- Current homepage recommendation is `dailySongsProvider`, which returns nine random songs from the active Navidrome library.
- Online songs can already be searched, played, downloaded, and imported through the companion Backend.
- Multi-server state, downloads, history, caches, and playback sessions are scoped by `serverId`.
- Existing downloads, history, and server entries must not be destructively migrated.

## Architecture / Runtime boundary baseline

- Flutter uses Riverpod; UI consumes providers and existing media/import services.
- `NavidromeAudioHandler` is the canonical owner of actual playback state and serialized player operations.
- `navidrome-backend` is a separate FastAPI project at `~/MyProject/navidrome-backend`.
- Backend already owns music-source proxying, Backend API-key authentication, NAS import, and direct Navidrome file/DB maintenance.
- Navidrome credentials and Backend credentials are independent.
- Recommendation persistence must not be stored in Navidrome's internal database.

## Compatibility boundary

- Existing online playback and import contracts remain usable.
- Recommendation songs are never imported automatically.
- Local-library random recommendations may be retired only when the approved online recommendation provider replaces their product role.
- Global cleartext-network compatibility is outside this feature and remains unchanged.

## Current risks

- Flutter and Backend are separate repositories and need contract tests on both sides.
- OpenAI and upstream music sources are external dependencies; fallback and bounded cost are required.
- The client workspace contains prior uncommitted fixes, so feature commits must not mix unrelated files.
