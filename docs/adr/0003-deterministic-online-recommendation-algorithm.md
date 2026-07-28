# ADR 0003: Deterministic Online Recommendation Algorithm

- Status: Accepted
- Date: 2026-07-28
- Supersedes: ADR 0002

## Context

The LLM planner added deployment configuration, latency, cost, cache state, and background replanning without creating a clear user-visible improvement. The existing verified source recall, feedback history, deduplication, and pagination already provide the inputs needed for useful recommendations.

## Decision

1. `navidrome-backend` owns a deterministic recommendation algorithm with no OpenAI or LLM dependency.
2. Recent artists and trusted `completed`/`imported` feedback produce similar-content search seeds.
3. Configured discovery seeds always produce exploration candidates.
4. Candidate pages target 70% similar content and 30% exploration, fill quota shortfalls from the other bucket, and limit each primary artist to two songs per batch.
5. Every candidate must still resolve through a real online source and pass availability, library, history, feedback exclusion, strong-identity, and weak-identity filters.
6. The existing recommendation SQLite keeps sessions, bounded recent context, candidates, feedback, profile generation, and refill leases so any worker can continue a session. Planner cache and feedback watermark fields are retired; legacy columns are ignored, and legacy active `ai` sessions migrate to `fallback`.
7. API `contractVersion=1` remains compatible. New Backend responses use the existing `fallback` mode value as the algorithm mode; Flutter does not display or store that implementation detail.
8. Feedback changes future refill and refresh queries through the derived positive profile. It does not reorder the visible queue.

## Consequences

- No model key, endpoint, timeout, prompt, planner task, or model-specific test remains.
- Recommendation startup and refill depend only on the configured music sources.
- Recommendation quality is explainable and reproducible from recent history, positive feedback, exploration seeds, and filters.
- The protocol's `fallback` name is retained until a future versioned API removes the legacy mode field.

## Verification

- Backend service tests cover seed derivation, 70/30 mixing, artist diversity, exclusions, source verification, refill, feedback persistence, and lease cleanup.
- Backend API and store tests prove the v1 contract and legacy-database compatibility.
- Flutter tests prove recommendation state no longer exposes the Backend mode while old v1 responses remain parseable.
