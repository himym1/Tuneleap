# Staged Recommendation Fill Implementation Plan

Date: 2026-07-21
Status: approved for inline execution

## Goal

Return cached or rule-driven recommendation pages without waiting for the LLM, generate Terra plans in the background, persist the latest valid plan and feedback watermark, and apply AI candidates only to later pages or an explicit refresh.

## Architecture

Reuse the existing owners: `RecommendationStore` persists profile/plan/watermark, `RecommendationService` owns synchronous rule fill and background single-flight planning, `OpenAIPlanner` owns the bounded model request, and Flutter remains a passive paginated client. No new API route, response field, queue service, or client polling owner is introduced.

## Tech Stack

FastAPI, Pydantic v2, httpx, aiosqlite, Python `unittest`; existing Flutter/Riverpod contract tests only.

## Baseline / Authority Refs

- `docs/aegis/specs/2026-07-20-llm-online-recommendations-design.md` amended and user-approved 2026-07-21
- `docs/adr/0002-verified-online-recommendation-pipeline.md`
- Existing `contractVersion: 1` Backend and Flutter fixtures

## Compatibility Boundary

Keep all `/v1/recommendations/*` request/response shapes and `ai|fallback` mode values. Do not reorder existing candidate ranks, invalidate current cursors, alter playback/import ownership, read Navidrome internals, expose secrets, or require Flutter polling.

## TDD Route

- Mode: off
- Decision: skipped
- Strict authority: not applicable
- Test posture: post-change focused regression plus full Backend suite
- Reason: user requested implementation, not strict TDD; existing suites cover owners and contracts
- Verification: targeted planner/store/service/API tests, then full Backend tests and Flutter contract comparison

## Readiness

- Requirement Ready Check: ready; approved staged-fill behavior and acceptance criteria are in the amended design.
- Change Necessity: code-change; configuration alone cannot remove the synchronous planner call or persist cached plans/watermarks.
- Existence Check: reuse-existing; store/service/planner already own every required responsibility.
- Architecture Integrity: no caller-side fallback or duplicate owner; Backend remains canonical.
- Complexity: `recommendation_service.py` is already dense, so extract plan/query helpers where needed instead of adding another service.
- Retirement: retire the synchronous planner-first branch; retain rule recall as the first-page path and planner fallback safety net.

## Task 1: Planner configuration

Files:
- Backend `app/core/config.py`
- Backend `app/main.py`
- Backend `app/services/openai_planner.py`
- Backend `.env.example`
- Backend `tests/test_openai_planner.py`

Changes:
1. Add bounded `OPENAI_REASONING_EFFORT` and `RECOMMENDATION_PLANNER_TIMEOUT` settings.
2. Send `reasoning_effort` only when configured; keep structured JSON and sanitized failures.
3. Pass the dedicated planner timeout from lifespan instead of the existing 15-second cap.

Verification:
```bash
python -m unittest tests.test_openai_planner tests.test_recommendation_config
```

## Task 2: Persist plan cache, profile summary, and trigger watermark

Files:
- Backend `app/services/recommendation_store.py`
- Backend `tests/test_recommendation_store.py`
- Backend `tests/fakes.py`

Changes:
1. Add restart-safe profile columns for latest plan JSON and planned feedback ID using idempotent schema migration.
2. Expose generation-guarded read/write methods for cached plan and watermark.
3. Derive bounded positive seeds and feedback counts from trusted feedback rows; never pass cache metadata to the planner.
4. Return accepted/duplicate feedback results with enough data for service trigger decisions.
5. Reset clears plan cache and watermark with the existing generation advance.

Verification:
```bash
python -m unittest tests.test_recommendation_store
```

## Task 3: Staged synchronous fill and background planning

Files:
- Backend `app/services/recommendation_service.py`
- Backend `tests/test_recommendation_service.py`
- Backend `tests/fakes.py`

Changes:
1. Split rule queries, plan queries, and candidate recall into focused helpers.
2. For an empty session, synchronously fill one page from cached plan or rules without calling the planner.
3. Schedule one background planner task for cold/dirty profiles; cache a valid plan, switch session mode to `ai`, and append verified candidates after existing ranks.
4. Trigger a debounced plan after five new `completed` events or one accepted `imported`/`disliked`; `played`, `unavailable`, and duplicates do not trigger.
5. Persist the feedback watermark only after a valid plan is cached; reset/session-generation guards reject stale completion.
6. Keep low-watermark refill single-flight and use cached plan before rules.

Verification:
```bash
python -m unittest tests.test_recommendation_service
```

## Task 4: Contract and Flutter compatibility

Files:
- Backend `tests/test_recommendation_api.py`
- Flutter contract fixture/tests only if behavior assertions need adjustment

Changes:
1. Prove session creation returns before a blocked fake planner is released.
2. Prove later pages may transition from `fallback` to `ai` without response-schema changes.
3. Preserve current Flutter item list when mode changes; no new client state or polling.

Verification:
```bash
python -m unittest tests.test_recommendation_api
cmp /Users/wangjianguo/MyProject/navidrome_player/.worktrees/online-recommendations/test/fixtures/recommendation_page.v1.json tests/contracts/recommendation_page.v1.json
```

## Task 5: Full verification and deployment handoff

Verification:
```bash
python -m unittest discover -s tests -v
```

Then run the existing Flutter suite only after Backend passes. Do not perform production deployment or real-key smoke without separate authorization. Record the Backend commit and update ADR/checkpoint evidence separately from product code.

## Risks

- Source search itself may exceed the two-second target; measure separately from planner latency.
- In-process debounce can be lost on restart, but persisted feedback watermark makes the next request reschedule safely.
- Cached plan exact-song searches may exhaust; rules remain the fallback without changing the API.
- Existing active first-page items remain rule-derived until pagination or explicit refresh by design.
