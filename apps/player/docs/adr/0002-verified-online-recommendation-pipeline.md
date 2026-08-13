# ADR 0002: Verified Online Recommendation Pipeline

- Status: Superseded by ADR 0003
- Date: 2026-07-21
- Amended: 2026-07-21 (staged first-page fill)
- Worktree commits:
  - Backend API: `e46725e` and predecessors
  - Backend staged fill: `f3451bc`, `f1b88f8`, `56e83fd`
  - Flutter: `b63198e` … `fd162d4`, `889d2c3`

## Context

The player needed online recommendations without becoming an OpenAI client, without writing recommendation state into Navidrome's database, and without auto-importing recommended tracks.

## Decision

1. **Backend-only LLM planner** holds the OpenAI-compatible key and emits bounded search plans only.
2. **Verified real-source recall** turns plan seeds into concrete online candidates from existing music proxy sources.
3. **Dedicated recommendation SQLite** stores sessions, candidates, feedback, and leases outside Navidrome DB.
4. **Flutter is presentation + feedback client**: contract models, shared `RecommendationNotifier`/outbox, playback origin attribution, tracker observation, and UI. It never calls OpenAI and never auto-imports recommendations.
5. **Staged first-page fill** keeps LLM latency out of the request path: existing candidates, cached AI plan recall, or rules produce the first page; new planning runs in the background.
6. **Stable candidate ordering** means background AI appends to future pages and caches the plan for explicit refresh. It never reorders visible items, current cursors, or playback queues.
7. **Batched feedback replanning** runs after five completed events or one imported/disliked event. Played/unavailable and duplicate feedback do not become planner triggers.
8. **Configurable reasoning budget** uses Terra `xhigh`/45 seconds as the recommended deployment profile while retaining rule candidates on any planner failure.

## Alternatives Rejected

- Flutter direct OpenAI calls
- Treating LLM output as playable songs without source verification
- Storing recommendation history/profile in Navidrome SQLite
- Keeping homepage local-random songs as the recommendation owner

## Consequences

- First-page availability no longer depends on planner latency or availability
- Background planner latency/cost, persisted plan/watermark state, and a process-local debounce task
- Shared `contractVersion=1` fixture between Backend and Flutter; no staged-fill contract expansion
- One Backend-owned recommendation profile per deployment identity, with reset isolation from media library state
- Playback failures must be sanitized (no URL/exception text) before recommendation feedback mapping
- Homepage random owner (`dailySongsProvider`) is retired in favor of the recommendation session owner

## Compatibility / Retirement

- Preserve existing media playback, download, and import owners
- Recommendation import remains explicit user action
- `dailySongsProvider` removed; homepage and `/recommendations` share `recommendationProvider`
- The synchronous planner-first branch is retired; rule recall remains the immediate availability owner.
- Existing visible candidates are not retired when a newer plan becomes ready; they age out with their session or explicit refresh.
