# LLM Online Recommendations Implementation Plan

Date: 2026-07-20
Status: ready for execution after workspace choice

## Goal

Implement the approved online recommendation design across the sibling repositories:

- Flutter: `/Users/wangjianguo/MyProject/navidrome_player`
- FastAPI Backend: `/Users/wangjianguo/MyProject/navidrome-backend`

The completed feature replaces homepage local random recommendations with a shared online recommendation feed, persists one Backend-owned taste profile, supports explicit import/dislike and playback feedback, and remains usable through rule-driven online fallback when OpenAI is unavailable.

## Architecture

```text
Flutter RecommendationNotifier
  ├─ BackendClient versioned recommendation API
  ├─ RecommendationPlaybackTracker (observer only)
  ├─ existing AudioPlayerService / NavidromeAudioHandler
  └─ existing NavidromeImportService
                    │ X-API-Key
                    ▼
FastAPI RecommendationRouter
  └─ RecommendationService
       ├─ RecommendationStore (dedicated SQLite)
       ├─ OpenAIPlanner (httpx + structured output)
       └─ existing MusicProxyService (real-source recall)
```

Canonical owner boundaries from the approved spec are mandatory. The Flutter provider does not rank music, the tracker does not control playback, the LLM does not produce playable objects, and recommendation storage does not access Navidrome's database.

## Tech Stack

- Flutter / Dart, Riverpod, Dio, GoRouter, SharedPreferences, existing audio_service/just_audio stack
- FastAPI, Pydantic v2, httpx, aiosqlite, slowapi
- Python standard-library `unittest` and `unittest.IsolatedAsyncioTestCase`; no new test/runtime dependency
- OpenAI Chat Completions structured output at `${OPENAI_BASE_URL}/chat/completions`

## Baseline / Authority Refs

- `docs/aegis/specs/2026-07-20-llm-online-recommendations-design.md` (`Status: approved`)
- `docs/aegis/baseline/2026-07-20-initial-baseline.md`
- `docs/aegis/BASELINE-GOVERNANCE.md`
- `docs/adr/0001-multi-server-session-isolation.md`
- Existing media/import owners in `lib/player/`, `lib/api/`, and `lib/providers/navidrome_import_provider.dart`

BaselineUsageDraft:

- Required baseline refs: approved recommendation spec, initial baseline, server-isolation ADR
- Delivered context refs: all three inspected before task decomposition
- Acknowledged before plan refs: all required refs
- Cited in plan refs: all required refs
- Missing refs: none
- Decision: continue

## Compatibility Boundary

- Preserve current playback, queue, history, downloads, scrobble, server switching, and explicit import behavior.
- Keep current `Song` JSON compatible; recommendation session metadata stays in separate models.
- Keep `NavidromeAudioHandler` the sole `AudioPlayer` owner.
- Keep existing `/proxy`, `/v1/music/*`, NAS, and song-delete Backend endpoints unchanged.
- Do not touch Navidrome's internal schema for recommendation data.
- Do not migrate or delete current SharedPreferences/history/download/server data.
- Do not alter Android/iOS cleartext policy.
- Do not expose OpenAI key, prompt, source history, raw response, credentials, playback URLs, or local paths in logs/contracts.

## TDD Route

- Mode: off
- Decision: skipped
- Strict authority: not applicable
- Test posture: proportional post-change contract and regression tests
- Reason: the user approved a detailed design but did not request strict test-first TDD; each bounded slice gets focused regression verification.
- Verification: Backend `unittest` + compile check; Flutter targeted tests, full tests, analyze, l10n generation, fixture comparison, and `git diff --check`.

## Scope Checks

### Requirement Ready Check

- Requirement source refs: approved design spec sections 1–18
- Goals and scope refs: spec sections 1–3
- User/scenario refs: homepage preview, infinite feed, explicit feedback/import, settings reset
- Requirement item refs: spec sections 2, 7, 9–12
- Acceptance/verification refs: spec sections 14–15
- Open blocker questions: none in product/API design
- Decision: ready

### Change Necessity

- User-visible need: personalized online recommendations and durable feedback do not exist.
- No-change/non-code option: Backend configuration alone cannot create APIs, persistence, Flutter state, or UI.
- Why code is necessary: both repositories require a new versioned contract and canonical owners.
- Minimum boundary: one Backend recommendation vertical plus one Flutter recommendation vertical; existing playback/import owners receive only typed extension points.
- Decision: code-change

### Existence Check

- Proposed new surfaces: Backend store/planner/service/router and Flutter models/provider/tracker/page.
- Existing reuse candidates: `MusicProxyService`, `BackendClient`, `AudioPlayerService`, `NavidromeAudioHandler`, `NavidromeImportService`, existing UI song widgets.
- Why reuse alone is insufficient: no recommendation contract, persistent profile/session, pagination, or feedback mapping exists.
- Creation proof: every new owner maps one approved responsibility; all media/source/import work remains delegated.
- Entropy/retirement: retire only the homepage `dailySongsProvider` consumer/owner; generic `getRandomSongs` remains.
- Decision: add-with-proof

### Architecture Integrity Lens

- Invariant: only verified real-source songs reach Flutter.
- Canonical contracts: versioned recommendation envelopes and strong `source + sourceId` identity.
- Responsibility overlap: none planned; planner plans, proxy searches, service orchestrates, store persists.
- Higher-level simplification: homepage and full page share one provider rather than parallel requests.
- Retirement/falsifier: remove the homepage random recommendation path after replacement tests pass; abort/revise if recommendation state starts controlling playback or Backend reads Navidrome history.
- Verdict: proceed

### Complexity Budget

- Artifact class: cross-repository feature with persistence and external-service boundary
- Existing pressure: `backend_client.dart` 324 lines, `audio_handler.dart` 534, `home_screen.dart` 366, `settings_screen.dart` 407, `song_context_menu.dart` 400
- Projected pressure: at-risk if recommendation logic is added in-place
- Budget result: within-budget only with separate owner files
- Planned governance: Backend schemas/store/planner/service/router separated; Flutter models/provider/tracker/page separated; existing large files receive small adapters only.

Plan-Time Complexity Check:

- Add-in-place targets: Backend `main.py`/config and Flutter app/home/settings/audio/client
- Owner fit: extension points only
- Add-in-place risk: high for orchestration/state/UI logic
- Better boundary: new feature-specific files listed below
- Recommendation: add owner files and keep edits to existing files narrow

### Plan Pressure Test

- Owner/contract/retirement: explicit
- Architecture integrity: one owner per approved responsibility
- Verification scope: unit, API, widget, full regression, contract fixture, smoke test
- Task executability: paths, order, checks, and stop conditions specified
- Pressure result: proceed

## Files

### Backend: create

- `app/models/recommendations.py` — Pydantic v1 contract models and validation
- `app/core/recommendation_http.py` — recommendation-only body limit and versioned error envelopes
- `app/services/recommendation_store.py` — SQLite schema, transactions, generation guards, refill leases, cursor queries
- `app/services/openai_planner.py` — bounded OpenAI-compatible structured plan call
- `app/services/recommendation_service.py` — profile/session orchestration, recall, filtering, mixing, fallback/refill
- `app/routers/recommendations.py` — authenticated/rate-limited API
- `tests/fakes.py` — deterministic planner/source doubles
- `tests/contracts/recommendation_page.v1.json` — canonical contract fixture
- `tests/test_recommendation_store.py`
- `tests/test_openai_planner.py`
- `tests/test_recommendation_service.py`
- `tests/test_recommendation_api.py`

### Backend: modify

- `app/core/config.py` — OpenAI/recommendation bounded configuration
- `app/main.py` — initialize/close store and recommendation service; register router/middleware/errors
- `docker-compose.yml` — dedicated named volume mounted at `/app/data`
- deployment env template — add variable names/defaults only; never add a key value

### Flutter: create

- `lib/api/models/recommendation.dart` — contract models/error types
- `lib/providers/recommendation_provider.dart` — canonical state/notifier and feedback outbox
- `lib/services/recommendation_playback_tracker.dart` — impression/threshold/failure observer
- `lib/ui/screens/recommendations/recommendations_screen.dart` — infinite feed
- `test/fixtures/recommendation_page.v1.json` — exact copy of Backend fixture
- `test/recommendation_models_test.dart`
- `test/recommendation_provider_test.dart`
- `test/recommendation_playback_tracker_test.dart`
- `test/recommendations_screen_test.dart`

### Flutter: modify

- `lib/api/backend_client.dart` — four recommendation API methods and versioned error mapping
- `lib/player/audio_handler.dart` — sanitized typed failure publication at the actual failure owner
- `lib/player/audio_player_service.dart` — expose failure stream unchanged
- `lib/player/playback_origin.dart` — recommendation origin metadata kept separate from `Song`
- `lib/providers/audio_providers.dart` — tracker/provider wiring where needed
- `lib/providers/library_cache_provider.dart` — retire `dailySongsProvider` only after homepage replacement
- `lib/ui/screens/home/home_screen.dart` — shared recommendation preview and scoped states
- `lib/ui/screens/shell/app_shell.dart` — replace global refresh invalidation of retired random provider
- `lib/ui/widgets/song_context_menu.dart` — optional recommendation scheduling/import callbacks without importing provider state
- `lib/ui/screens/settings/settings_screen.dart` — recommendation mode/reset section
- `lib/app.dart` — `/recommendations` route
- `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` — user-visible recommendation strings
- generated `lib/l10n/app_localizations*.dart` — regenerate, never hand-edit
- `test/backend_client_test.dart`
- `test/audio_handler_server_scope_test.dart`
- `test/navidrome_import_provider_test.dart` only if callback success semantics require coverage

## Execution Order and Tasks

## Batch A — Backend Contract and Persistence

### Task 1: Define bounded configuration and v1 contract models

Files:

- Modify `app/core/config.py`
- Create `app/models/recommendations.py`
- Create `tests/contracts/recommendation_page.v1.json`

Why: all later Backend/Flutter work must consume one explicit, bounded contract.

Change necessity: existing `schemas.py` contains unrelated NAS/system models; a separate recommendation model file prevents a new contract domain from inflating it.

Implementation:

1. Add settings with defaults: `openai_api_key=''`, `openai_model='gpt-4.1-mini'`, `openai_base_url='https://api.openai.com/v1'`, `recommendation_db_path='/app/data/recommendations.db'`, `recommendation_session_ttl_hours=24`, pool target 60, low watermark 20, page maximum 20, upstream concurrency 5, comma-separated neutral seeds, and `recommendation_sources='netease,migu,joox'`. Parse sources by trim/dedup and validate each against the existing supported set `netease,migu,joox,kuwo,kugou`; fail service startup with a sanitized configuration error when the resulting list is empty.
2. Define Pydantic aliases exactly as the spec's camelCase fields. Enforce request/body-adjacent field bounds in model fields and validators.
3. Define `RecommendationSong`, `RecommendationItem`, `RecommendationPageV1`, `RecommendationFeedbackRequest/Response`, `RecommendationErrorV1`, and planner-only models.
4. Make contract fixture include one AI page, one fallback page variant, and representative online `Song` fields; do not include credentials/history.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome-backend
.venv/bin/python -m compileall app
.venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
git diff --check
```

Expected: compile succeeds; test discovery may report zero tests only at this first slice; fixture parses with `json.tool`. Add focused configuration tests before closing Task 1 for default source order, trim/dedup, unsupported entries, and empty-valid-source rejection.

### Task 2: Implement generation-safe SQLite store

Files:

- Create `app/services/recommendation_store.py`
- Create `tests/test_recommendation_store.py`

Why: feedback, sessions, candidates, and reset must survive Backend restarts without touching Navidrome.

Implementation:

1. Initialize parent directory and tables inside one startup transaction: singleton profile generation, feedback, sessions (including `refill_owner` and `refill_lease_until`), candidates, indexes, and both feedback uniqueness constraints.
2. Use UTC epoch milliseconds consistently; do not mix SQLite local-time strings and Python datetimes.
3. Implement: initialize/close, current generation, create/resume/expire session, append candidates, stable page query, feedback insert/idempotent duplicate result, exclusions/profile summary, atomic reset generation advance, atomic refill lease claim/renew/release, and expired-lease recovery.
4. Encode cursor as bounded base64url JSON containing contract version, session ID, generation, and next rank; validate all fields and session match before querying.
5. Every mutating SQL statement includes the captured generation or session-generation predicate. Candidate refill writes additionally require the matching lease owner. Return typed stale-session/lease-lost results when predicates fail.
6. Keep SQL transactions short; no OpenAI or upstream request occurs while a transaction is open.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome-backend
.venv/bin/python -m unittest tests.test_recommendation_store -v
.venv/bin/python -m compileall app tests
git diff --check
```

Tests: restart persistence, stable repeated cursor, both idempotency barriers, reset versus delayed write, old cursor 410 classification, two connections contending for one refill lease, lease-owner write guard, expired-lease recovery, expiry cleanup, and proof that reset leaves unrelated paths untouched.

## Batch B — Backend Planning, Recall, and API

### Task 3: Implement bounded OpenAI planner

Files:

- Create `app/services/openai_planner.py`
- Create `tests/test_openai_planner.py`

Why: the LLM boundary needs strict input/output controls and a single failure type that enables fallback.

Implementation:

1. Accept the lifespan-owned `httpx.AsyncClient`; do not instantiate a client per request.
2. Return `None` when `OPENAI_API_KEY` is empty so fallback is deterministic.
3. POST `${openai_base_url.rstrip('/')}/chat/completions` with bearer auth, configured model, low temperature, finite output tokens, and `response_format.type=json_schema` matching planner models.
4. Build a bounded JSON prompt from sanitized recent/positive/deny summaries; never interpolate it into logs or exceptions.
5. Validate 40 candidates per category, 20 total seeds, and 200-character generated fields. Convert timeout, non-2xx, missing content, invalid JSON, and schema failure to a sanitized `PlannerUnavailable` without raw body/key/prompt.
6. Do not retry inside the planner; the recommendation service owns fallback.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome-backend
.venv/bin/python -m unittest tests.test_openai_planner -v
.venv/bin/python -m compileall app tests
git diff --check
```

Tests use `httpx.MockTransport` for success, timeout, non-2xx, invalid JSON, oversized output, empty key, and log/error redaction.

### Task 4: Implement recommendation orchestration and source recall

Files:

- Create `app/services/recommendation_service.py`
- Create `tests/fakes.py`
- Create `tests/test_recommendation_service.py`
- Modify `app/services/music_proxy.py` only if a narrower typed adapter is required; preserve the existing `search(source, name, count, pages)` contract.

Why: one service must transform a plan or fallback seed into verified, normalized, deduplicated online candidates.

Implementation:

1. Define a narrow source-search protocol returning `list[dict]`; the production adapter calls the existing `await MusicProxyService.search(source, name, count, pages)` method and consumes its direct list return. Treat a non-list or non-dictionary element as a sanitized upstream-source failure without changing current proxy routes.
2. Normalize each result through one Backend serializer into the Flutter `Song` camelCase contract. Require non-empty source/source ID/title and preserve source-specific `url_id`, `lyric_id`, album, artist, cover, and suffix when available.
3. Use strong identity for deny/served/feedback. Use conservative Unicode NFKC, case-fold, whitespace, and punctuation normalization for weak same-batch dedup only.
4. Create/resume sessions. For a new session, capture generation and request one plan if configured. When the plan succeeds, search exact title/artist before its seeds. When planning fails but recent/high-positive signals exist, build rule fallback searches from those artists/tracks. Use neutral seeds only when no usable recent or positive signal exists. Rotate every strategy through the validated configured source list; never hard-code a source inside orchestration.
5. Apply recent/import/dislike/unavailable/session exclusions and max two songs per artist per page.
6. Assign ranks with a deterministic 14 similar/6 explore target where enough candidates exist; fill missing category capacity from the other category rather than returning an avoidable short page.
7. Bound search concurrency with `asyncio.Semaphore(5)`. Do not resolve playback URLs during recommendation generation.
8. Make SQLite the authoritative cross-worker single-flight owner: atomically claim a session refill lease with owner UUID and expiry only when no unexpired lease exists; all candidate writes require matching generation and lease owner. Release on completion, and allow recovery after lease expiry if a worker dies. An in-process `asyncio.Lock` may be used only as an optimization, never for correctness.
9. Cold session creation synchronously searches and commits only until the accepted `pageSize` is satisfied or one bounded search attempt is exhausted; it must not wait to fill the 60-item target. After the first response is ready, the API schedules a background refill that claims the SQLite lease and fills toward 60. Later page requests trigger at most one bounded refill attempt when available count is below 20; if another worker owns the lease they return existing candidates without duplicate upstream work.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome-backend
.venv/bin/python -m unittest tests.test_recommendation_service -v
.venv/bin/python -m compileall app tests
git diff --check
```

Tests: direct-list and malformed source responses, deterministic 100+ fake songs/five pages, 70/30 mix, source rotation, artist cap, exact/weak dedup, neutral cold seeds only with no signal, planner-failure fallback from recent/high-positive signals, synchronous cold-start stopping at `pageSize`, background refill toward 60, recent/feedback filtering, two service instances contending for one SQLite refill lease, expired-lease recovery, reset race, temporary exhaustion, and no playback-URL lookup.

### Task 5: Expose versioned authenticated API and lifecycle

Files:

- Create `app/core/recommendation_http.py`
- Create `app/routers/recommendations.py`
- Modify `app/main.py`
- Modify `docker-compose.yml` with a Docker-managed named volume; do not choose a NAS host path in source control.
- Modify deployment env template using variable names/defaults only
- Create `tests/test_recommendation_api.py`

Why: the client requires stable envelopes, body limits, auth/rate limits, and lifespan-managed resources.

Implementation:

1. Add recommendation-path middleware that rejects session bodies over 64 KiB and feedback bodies over 4 KiB before JSON parsing, including chunked bodies by counting received bytes.
2. Add recommendation-aware handlers that preserve existing behavior for every non-recommendation route and wrap recommendation `400/401/410/429/5xx` errors as `RecommendationErrorV1`.
3. Router endpoints use existing `verify_api_key` and limiter: create 5/minute, page 60/minute, feedback 120/minute, reset 2/minute.
4. Map stale generation/session to 410, invalid cursor/input to 400, temporary exhaustion/upstream outage to a retryable 503, and unexpected failures to a generic 500 without raw exception data.
5. Initialize `RecommendationStore`, planner, adapter, and service in FastAPI lifespan; close store and shared HTTP client on shutdown. Store service on `app.state` for request access and test substitution.
6. Mount a dedicated Docker-managed named volume at `/app/data:rw`; do not reuse `/data` because it owns Navidrome files. A production bind-mount path remains a deployment-time override requiring separate approval.
7. Add env names/defaults only. Never write `OPENAI_API_KEY` value.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome-backend
.venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
.venv/bin/python -m compileall app tests
python3 -m json.tool tests/contracts/recommendation_page.v1.json >/dev/null
git diff --check
git status --short
```

API tests run the ASGI app with its lifespan and a temporary SQLite DB. Cover 200 page envelopes, duplicate feedback, reset, 400 bounds, 401, 410, 429 handler shape, fallback mode, and rejected requests making zero fake external calls.

Stop Batch B if the Backend full suite fails or a response diverges from the fixture. Do not begin Flutter contract work against an unstable API.

## Batch C — Flutter Contract and State

### Task 6: Add recommendation models and BackendClient methods

Files:

- Create `lib/api/models/recommendation.dart`
- Copy canonical fixture to `test/fixtures/recommendation_page.v1.json`
- Modify `lib/api/backend_client.dart`
- Create `test/recommendation_models_test.dart`
- Modify `test/backend_client_test.dart`

Why: Flutter must reject incompatible contracts and map Backend failures without leaking Dio details into UI state.

Implementation:

1. Define immutable `RecommendationItem`, `RecommendationPage`, `RecommendationMode`, `RecommendationType`, `RecommendationFeedbackEvent`, and `RecommendationApiException`.
2. Parse only `contractVersion == 1`; parse song via `Song.fromJson` because Backend emits the canonical Flutter camelCase song shape.
3. Add `createRecommendationSession`, `getRecommendationItems`, `sendRecommendationFeedback`, and `resetRecommendationProfile` to `BackendClient`.
4. Reuse configured base URL, `X-API-Key`, timeout, cancellation, and existing log-redaction conventions. Never log request recent-song payload or feedback IDs.
5. Map versioned 400/401/410/429/5xx envelopes into typed code/retryable fields. Preserve network cancellation separately so stale requests do not become UI errors.
6. Serialize recent summaries with only title, artist, album, source, and sourceId; cap at 30 before sending.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
cmp test/fixtures/recommendation_page.v1.json ../navidrome-backend/tests/contracts/recommendation_page.v1.json
flutter test --no-pub test/recommendation_models_test.dart test/backend_client_test.dart
dart format --output=none --set-exit-if-changed lib/api/models/recommendation.dart lib/api/backend_client.dart test/recommendation_models_test.dart test/backend_client_test.dart
git diff --check
```

### Task 7: Implement shared RecommendationNotifier and retry outbox

Files:

- Create `lib/providers/recommendation_provider.dart`
- Create `test/recommendation_provider_test.dart`

Why: homepage and full feed need one state owner with stable pagination, feedback identity, and stale-session handling.

Implementation:

1. Define immutable `RecommendationState`: items, session/cursor/mode, initial/loading-more/refresh/reset flags, hasMore, scoped errors, hidden/pending/importing candidate sets, and fallback-notice state.
2. Build provider dependencies around existing `backendClientProvider`, `audioPlayerServiceProvider`, `serverConfigProvider`, SharedPreferences, import service, and request generation.
3. `ensureLoaded()` sends active server's 30 most recent history summaries with `refresh=false`; Backend performs actual cross-device resume.
4. `refresh()` uses `refresh=true`; `loadMore()` is single-flight and ignores duplicate/stale cursor responses.
5. Deduplicate defensively by `Song.storageKey`, and reject all responses captured before server ID, Backend URL, Backend API key presence, or request generation changes.
6. Generate one UUID when feedback first becomes eligible. Persist a small outbox containing only endpoint identity/event/session/candidate/UUID, keyed by normalized Backend URL (never API key). Retry retryable network/5xx events with the same UUID on provider activation and successful API calls.
7. For dislike: hide immediately; keep hidden while a retryable event is pending; restore only on definitive non-retryable rejection. For import: call existing import service first, then emit `imported`; never emit on import failure.
8. On 410, clear local session/cursor and create/resume once; prevent loops. Reset clears provider state and its outbox only after Backend reset succeeds.
9. Expose methods for tracker feedback and recommendation UI actions; do not expose mutable lists.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
flutter test --no-pub test/recommendation_provider_test.dart
dart format --output=none --set-exit-if-changed lib/providers/recommendation_provider.dart test/recommendation_provider_test.dart
git diff --check
```

Tests: shared initialization, refresh, cursor progression, pagination single-flight, duplicate suppression, stale server/config response, 410 one-time recovery, retryable outbox UUID reuse, definitive dislike rollback, import success/failure feedback, fallback notice once, and reset isolation.

## Batch D — Playback Feedback

### Task 8: Publish sanitized typed playback failures

Files:

- Create `lib/player/playback_origin.dart`
- Modify `lib/player/audio_handler.dart`
- Modify `lib/player/audio_player_service.dart`
- Modify `test/audio_handler_server_scope_test.dart`

Why: only the actual playback owner can classify URL/source load failure without exposing URLs or raw exceptions.

Implementation:

1. Define immutable `PlaybackOrigin` in `playback_origin.dart` with `sessionId`, `candidateId`, and recommendation impression ID; keep it out of `Song` serialization. Define `PlaybackFailureKind` and immutable `PlaybackFailure` with server ID, `Song.storageKey`, request generation, optional origin, kind, and retryable flag.
2. Extend `NavidromeAudioHandler` queue ownership with a parallel origin list. Add optional origin parameters to `setQueue`, `addToQueue`, and `insertNext`; update/remove/reorder/shuffle origins atomically with songs; default null preserves every existing caller. Publish the current origin with media-item changes and own/dispose the broadcast controllers.
3. Add matching optional origin parameters to `AudioPlayerService.playSong`, `addToQueue`, and `playNext`. Define `playAll`/handler `setQueue` to accept `List<PlaybackOrigin?>? origins`, require the list length to equal the song list when supplied, and preserve null origins for generic entries. Expose `currentPlaybackOriginStream`. In `_loadCurrent`, classify resolver/source terminal failures separately from timeout/connectivity failures and attach the origin of the exact queue item. Publish only if request generation, scoped current song, and current origin still match.
4. Never include URL, credentials, exception text, or stack traces in the event.
5. Expose typed failure and origin streams unchanged from `AudioPlayerService`; it must not reinterpret or mutate handler state.
6. Clear stale origin/failure attribution on client/server switch, queue replacement, removal, reorder, shuffle, skip, and stop through the same queue mutation/request invalidation path.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
flutter test --no-pub test/audio_handler_server_scope_test.dart test/playback_repeat_mode_test.dart
dart format --output=none --set-exit-if-changed lib/player/playback_origin.dart lib/player/audio_handler.dart lib/player/audio_player_service.dart test/audio_handler_server_scope_test.dart
git diff --check
```

Tests: per-song origin preservation through playAll/queue/next/remove/reorder/shuffle, origin-list length rejection, generic null origins, terminal failure with exact origin, retryable classification, no URL/error text, stale generation suppression, and server-switch suppression.

### Task 9: Implement recommendation playback tracker

Files:

- Create `lib/services/recommendation_playback_tracker.dart`
- Modify `lib/providers/audio_providers.dart`
- Create `test/recommendation_playback_tracker_test.dart`

Why: played/completed/unavailable feedback must observe playback without becoming a second player owner.

Implementation:

1. Tracker subscribes to current song, current playback origin, duration, position, playing, and typed failure streams.
2. A recommendation action creates a unique `PlaybackOrigin(sessionId, candidateId, impressionId)` and passes it through `AudioPlayerService` into the handler queue. The tracker accepts only the origin attached to the actual current queue item; matching song identity without a recommendation origin is always treated as ordinary playback.
3. Emit `played` once at `position >= 30s OR position/duration >= 25%`; emit `completed` once at `>=90%`.
4. Map only a non-retryable failure carrying the same active recommendation origin to `unavailable`; retryable or null-origin failures never create recommendation feedback.
5. Invalidate active impression on server/client generation change, stop/current-song change, or recommendation reset. Keep stable event UUID generation in notifier/outbox, not tracker.
6. Wire lifecycle through Riverpod disposal. Tracker invokes a feedback callback/provider method and never calls player controls.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
flutter test --no-pub test/recommendation_playback_tracker_test.dart test/audio_handler_server_scope_test.dart
dart format --output=none --set-exit-if-changed lib/services/recommendation_playback_tracker.dart lib/providers/audio_providers.dart test/recommendation_playback_tracker_test.dart
git diff --check
```

Tests: 30-second threshold, 25% threshold, 90%, one event each, ordinary/null-origin song exclusion even for the same online identity, queued origin preservation, origin/current-song mismatch, retryable failure exclusion, terminal unavailable, and server-switch invalidation.

## Batch E — Flutter Product UI

### Task 10: Build reusable recommendation item actions and infinite page

Files:

- Create `lib/ui/screens/recommendations/recommendations_screen.dart`
- Modify `lib/ui/widgets/song_context_menu.dart`
- Modify `lib/app.dart`
- Create `test/recommendations_screen_test.dart`

Why: users need the full infinite feed and explicit play/import/dislike workflows.

Implementation:

1. Add an optional `PlaybackOrigin` constructor parameter and successful-import callback to `SongContextMenu`; for play/play-next/add-queue it forwards the origin to `AudioPlayerService`. Defaults preserve all existing callers and generic playback.
2. Build a dense responsive list/grid using existing cover widgets, typography, context menu, queue/download/import services, and icon conventions. No nested cards or explanatory marketing UI.
3. Use a stable scroll threshold near 400 px, call `loadMore()` once per cursor, and keep fixed row/tile geometry while loading.
4. Provide direct play, overflow actions, explicit import, and icon-only dislike with tooltip/semantics. Create one new recommendation impression origin per recommendation item when constructing a recommendation-origin queue, and pass the origin list in the same order as songs to `playAll`; play/play-next/add-queue forwards the selected item's single origin.
5. Preserve items on load-more failure and show inline retry. Initial error/empty/backend-unconfigured states are local to this page.
6. Add `/recommendations` under the existing shell route without adding a primary navigation destination.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
flutter test --no-pub test/recommendations_screen_test.dart test/widget_test.dart
dart format --output=none --set-exit-if-changed lib/ui/screens/recommendations/recommendations_screen.dart lib/ui/widgets/song_context_menu.dart lib/app.dart test/recommendations_screen_test.dart
git diff --check
```

Widget tests cover initial/error/inline retry, scroll single-flight, action callbacks, per-song origin alignment for homepage/full-page `playAll`, optimistic dislike, import progress, text fit at narrow/wide sizes, and no automatic queue/import.

### Task 11: Replace homepage random owner and add settings reset

Files:

- Modify `lib/ui/screens/home/home_screen.dart`
- Modify `lib/providers/library_cache_provider.dart`
- Modify `lib/ui/screens/settings/settings_screen.dart`
- Modify `lib/ui/screens/shell/app_shell.dart`
- Modify `lib/ui/widgets/song_context_menu.dart` to remove the deleted-song refresh reference to the retired provider
- Modify `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Regenerate `lib/l10n/app_localizations*.dart`
- Extend `test/recommendations_screen_test.dart` or create focused home/settings widget tests

Why: this completes the approved product replacement and preference lifecycle.

Implementation:

1. Replace `dailySongsProvider` consumption with the shared notifier preview (first 6 mobile/9 wide) and add “More” to `/recommendations`.
2. Keep newest/recent album loading independent; recommendation failure cannot replace the whole homepage with an error.
3. Pull-to-refresh refreshes albums and creates one new recommendation session.
4. Once homepage tests use the new owner, replace `dailySongsProvider` invalidation in `AppShell` with recommendation-provider scope invalidation, remove its deleted-song invalidation from `SongContextMenu`, then delete `dailySongsProvider` from `library_cache_provider.dart`. Retain generic Subsonic `getRandomSongs`.
5. Add Settings recommendation section showing current AI/basic mode and reset action.
6. Confirmation copy states that songs, downloads, play history, and server configuration remain. Disable repeat reset while active; preserve state on failure and show scoped error.
7. Add all English/Chinese strings to ARB and regenerate localization output; do not hand-edit generated files.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
flutter gen-l10n
flutter test --no-pub test/recommendations_screen_test.dart test/widget_test.dart
dart format --output=none --set-exit-if-changed lib/ui/screens/home/home_screen.dart lib/ui/screens/shell/app_shell.dart lib/ui/widgets/song_context_menu.dart lib/providers/library_cache_provider.dart lib/ui/screens/settings/settings_screen.dart
git diff --check
rg -n 'dailySongsProvider' lib test && exit 1 || true
```

Expected: no recommendation owner/reference remains under `dailySongsProvider`; unrelated random-song client capability remains.

## Batch F — Full Verification, Smoke Test, and Architecture Record

### Task 12: Run both full suites and contract drift check

Files: no product edits unless verification exposes an in-scope defect.

Backend:

```bash
cd /Users/wangjianguo/MyProject/navidrome-backend
.venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
.venv/bin/python -m compileall app tests
python3 -m json.tool tests/contracts/recommendation_page.v1.json >/dev/null
git diff --check
git status --short
```

Flutter:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
cmp test/fixtures/recommendation_page.v1.json ../navidrome-backend/tests/contracts/recommendation_page.v1.json
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub
git diff --check
git status --short
```

Expected: Backend tests pass, compile succeeds, Flutter analyze has no issues, Flutter full test count is at least the existing 113 plus recommendation tests, fixtures match exactly, and diff checks pass.

### Task 13: Environment-bound smoke test

External-write boundary: this task requires the user's existing Backend environment to have `OPENAI_API_KEY` configured. Never inspect or print its value. Do not deploy or alter production/NAS configuration without separate approval.

Procedure:

1. Start Backend locally with a temporary recommendation DB and configured environment, or use an explicitly approved test deployment.
2. Submit a synthetic three-song history containing public metadata only.
3. Verify response `contractVersion=1`, `mode=ai` when OpenAI succeeds, 20 or fewer verified online candidates, and no duplicate strong identity.
4. Temporarily run with OpenAI key absent in a local process and verify `mode=fallback` returns online-source candidates.
5. Exercise duplicate feedback UUID, reset, and old-cursor 410.
6. Inspect only sanitized application logs for absence of prompt/history/key/raw response/playback URL.

Stop if only a production/NAS instance is available; request explicit deployment/test authorization instead of running this task there.

### Task 14: Record proven architecture decision and sync index

Files:

- Create `docs/adr/0002-verified-online-recommendation-pipeline.md`
- Modify `docs/aegis/INDEX.md` to link the ADR

Why: implementation proves the durable planner/verified-source/persistence boundary identified by the approved spec's ADR signal.

ADR content:

- Decision: Backend-only LLM planner, verified real-source recall, dedicated recommendation SQLite, Flutter as presentation/feedback client.
- Alternatives rejected: Flutter direct OpenAI, direct LLM playable songs, Navidrome DB history/profile, local-random fallback.
- Consequences: external latency/cost, contract fixture, one Backend profile, fallback behavior, future profile/vector/AI-radio triggers.
- Compatibility/retirement: preserve media/import owners; retire homepage random owner only.

Verification:

```bash
cd /Users/wangjianguo/MyProject/navidrome_player
rg -n 'Status: approved' docs/aegis/specs/2026-07-20-llm-online-recommendations-design.md
git diff --check -- docs/adr docs/aegis
```

## Review Gates

1. Backend Gate: Tasks 1–5 complete; full Backend suite and fixture pass before Flutter consumption.
2. Flutter Contract Gate: Tasks 6–7 pass; no UI work before state/cursor/outbox behavior is stable.
3. Playback Gate: Tasks 8–9 pass existing server-scope/repeat regressions before UI registration uses tracker.
4. Product Gate: Tasks 10–11 pass widget and l10n checks; `dailySongsProvider` has no references.
5. Completion Gate: Task 12 fresh full evidence, Task 13 only with environment authorization, and independent code review of both repositories.

Any owner/contract/schema change that contradicts the approved spec stops execution and returns to design rather than silently changing the plan.

## Risks and Mitigations

- Dirty Flutter workspace: recommended execution mode is to checkpoint/separate existing Flutter changes first. If the user explicitly chooses current-tree execution instead, use a task-file allowlist, inspect every touched diff, never revert existing lines, and make no mixed commit.
- Backend has no existing tests: use standard-library unittest/ASGI transport without adding dependencies.
- Upstream formats vary: one normalization function plus deterministic source fakes; reject incomplete identity.
- Reset/refill races: monotonic generation, conditional writes, and SQLite refill leases; in-process cancellation/locks are optimizations only.
- Feedback retries: one UUID persisted per event plus semantic Backend uniqueness.
- OpenAI cost/latency: one bounded call at cold session/refill, output caps, no planner retry.
- Infinite-feed claim: deterministic 100-candidate verification; production exposes retryable exhaustion.
- Typed playback failure blast radius: additive stream only; existing playback state and controls remain unchanged.
- Docker path portability: `/app/data` uses a dedicated Docker named volume by default; any NAS bind-mount override is a deployment decision requiring approval.

## Rollback and Retirement

Backend rollback:

- Removing recommendation router/lifespan wiring disables the feature without affecting existing endpoints.
- Dedicated recommendation SQLite and `/app/data` mount can remain unused; deletion requires explicit data-loss approval.
- Never roll back by editing Navidrome DB.

Flutter rollback:

- Repoint homepage to the previous provider only as a code rollback; do not retain two active recommendation owners.
- New route/provider/tracker can be removed together; additive playback failure stream may remain only if independently useful and tested.
- Existing history, downloads, imports, and server data need no migration rollback.

Retirement:

- Remove `dailySongsProvider` only after new homepage tests pass.
- Keep generic `getRandomSongs` unless a separate unused-code review proves no callers.
- No compatibility adapter is planned for recommendation contract v0 because no released recommendation API exists.

## Execution Readiness View

- Intent Lock: implement only the approved online recommendation feed/profile/feedback/reset behavior.
- Scope Fence: two local repositories; no deployment, credential handling, Navidrome migration, AI radio, profiles, embeddings, or cleartext policy work.
- Baseline Lock: approved spec, initial baseline, and server-isolation ADR.
- Approved Behavior: versioned online feed, 70/30 target, explicit import/dislike, long-lived Backend feedback, rule fallback, reset isolation.
- Owner/Contract Constraints: provider/service/store/planner/tracker boundaries above; `contractVersion=1` fixture is the cross-repo source of truth.
- Compatibility Boundary: preserve all current media, server, history, download, and import behavior.
- Retirement Boundary: retire homepage random provider only; retain generic random-song API.
- Task Batches: Backend contract/store → Backend planner/service/API → Flutter contract/state → playback observer → UI → full verification/ADR.
- Test Obligations: all task-focused checks plus fresh full Backend/Flutter suites and fixture equality.
- Review Gates: five gates listed above and independent final review.
- Drift/Rewind Rules: stale generation/cursor is explicit; architecture/spec contradiction returns to design; failed gate rewinds only its batch.
- Evidence Required Before Completion: exact commands/results, changed-file lists for both repos, contract equality, no-secret review, residual smoke/deployment risk.
- Advisory Boundary: method-pack execution guidance only; not GateDecision, PolicySnapshot, or completion authority.

## Workspace Decision Required Before Execution

`navidrome-backend` is currently clean. `navidrome_player` has extensive prior uncommitted edits, including files this feature must modify (`backend_client.dart`, audio files, l10n, and others). A clean worktree from current `HEAD` would omit those prior fixes, while implementing directly risks mixed ownership.

Choose one execution mode:

1. **Inline on the current Flutter workspace** — preserve all existing edits, use a strict file allowlist, inspect task diffs carefully, and make no Flutter commit until prior changes are separated. Backend remains independently committable after verification.
2. **First checkpoint the existing Flutter changes** — user reviews/commits the current baseline, then recommendation work runs in a clean worktree or clean current branch.

No execution should begin until this workspace choice is explicit.
