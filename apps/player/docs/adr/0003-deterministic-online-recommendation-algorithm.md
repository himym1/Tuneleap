# ADR-0003: Deterministic online recommendation algorithm

- Status: Accepted and implemented
- Date: 2026-07-28
- Updated: 2026-07-30
- Supersedes: ADR-0002

## Context

The earlier LLM planner added deployment configuration, latency, cost, cache state, and background replanning without a clear user-visible improvement. Verified source recall, recent playback, feedback, deduplication, and pagination already provide enough inputs for useful recommendations.

The recommendation owner has since moved from the retired NAS backend to `navidrome-cloud`; runtime state has moved from SQLite to Postgres.

## Decision

1. `navidrome-cloud` owns a deterministic recommendation algorithm with no OpenAI or LLM dependency.
2. Recent artists and trusted `completed` / `imported` feedback produce similar-content search seeds.
3. Configured discovery seeds produce exploration candidates.
4. Candidate pages target 70% similar content and 30% exploration, fill quota shortfalls from the other bucket, and limit each primary artist to two songs per batch.
5. Every candidate resolves through a real online source and must pass availability, library, history, feedback, strong-identity, and weak-identity exclusions.
6. Cloud reads library identities from `navidrome-nas-agent`; it never opens `navidrome.db` directly.
7. Postgres stores sessions, bounded recent context, candidates, feedback, profile generation, and refill leases so any Cloud worker can continue a session.
8. API `contractVersion=1` remains compatible. The legacy `fallback` mode value continues to identify deterministic generation until a future versioned contract removes that name.
9. Feedback affects future refill and refresh queries; it does not reorder the visible queue.

## Consequences

- Recommendation startup and refill depend only on configured music-source adapters and NAS identity availability.
- Recommendation behavior is explainable from recent history, positive feedback, exploration seeds, filters, and session generation.
- Cloud Postgres is the only recommendation runtime store.
- Flutter owns presentation, pagination, playback-origin attribution, and feedback outbox; it does not own recommendation ranking.
- The App may display the server mode as status information but does not branch recommendation behavior on it.

## Verification

- Cloud service tests cover seed derivation, 70/30 mixing, artist diversity, exclusions, source verification, refill, feedback persistence, and lease cleanup.
- Postgres store tests prove transaction, concurrency, and contract behavior.
- NAS Agent tests prove library identity normalization and access boundaries.
- Flutter tests cover recommendation state, pagination, refresh, feedback retry, playback attribution, and v1 response parsing.
