# ADR 0002: Verified Online Recommendation Pipeline

- Status: Accepted
- Date: 2026-07-21
- Worktree commits:
  - Backend: `e46725e` (API) and Task 1–4 predecessors
  - Flutter: `b63198e` … `fd162d4`

## Context

The player needed online recommendations without becoming an OpenAI client, without writing recommendation state into Navidrome's database, and without auto-importing recommended tracks.

## Decision

1. **Backend-only LLM planner** holds the OpenAI-compatible key and emits bounded search plans only.
2. **Verified real-source recall** turns plan seeds into concrete online candidates from existing music proxy sources.
3. **Dedicated recommendation SQLite** stores sessions, candidates, feedback, and leases outside Navidrome DB.
4. **Flutter is presentation + feedback client**: contract models, shared `RecommendationNotifier`/outbox, playback origin attribution, tracker observation, and UI. It never calls OpenAI and never auto-imports recommendations.

## Alternatives Rejected

- Flutter direct OpenAI calls
- Treating LLM output as playable songs without source verification
- Storing recommendation history/profile in Navidrome SQLite
- Keeping homepage local-random songs as the recommendation owner

## Consequences

- External planner latency/cost and the need for fallback mode when the planner is unavailable
- Shared `contractVersion=1` fixture between Backend and Flutter
- One Backend-owned recommendation profile per deployment identity, with reset isolation from media library state
- Playback failures must be sanitized (no URL/exception text) before recommendation feedback mapping
- Homepage random owner (`dailySongsProvider`) is retired in favor of the recommendation session owner

## Compatibility / Retirement

- Preserve existing media playback, download, and import owners
- Recommendation import remains explicit user action
- `dailySongsProvider` removed; homepage and `/recommendations` share `recommendationProvider`
