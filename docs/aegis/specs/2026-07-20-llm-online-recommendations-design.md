# LLM Online Recommendations Design

Date: 2026-07-20
Amended: 2026-07-21
Status: approved; staged-fill amendment pending written review

## 1. Goal

Replace the homepage's fixed nine-song local random recommendation with a personalized, effectively unbounded online recommendation feed. The feature uses recent listening and explicit feedback to improve recommendations, but every displayed song must be resolved through a real online music source before reaching the Flutter client.

Success means:

- Homepage previews online personalized recommendations and links to an infinite-scroll recommendation page.
- A cached or rule-driven first page is returned without waiting for an LLM call.
- Recommendations do not enter Navidrome automatically.
- Import and dislike actions improve one persistent Backend-owned taste profile.
- At least five pages can be loaded without duplicates or a fixed total limit.
- Planner failure leaves usable rule-driven online recommendations in place.
- No OpenAI or Navidrome secret reaches the wrong boundary.

## 2. Confirmed product decisions

1. OpenAI runs only in `navidrome-backend`; Flutter never receives its key.
2. The model, compatible endpoint, and reasoning effort are deployment configuration. The recommended online planner profile is GPT-5.6 Terra with `xhigh` reasoning and a 45-second background timeout.
3. Session creation never waits for a new LLM call. It immediately serves an existing candidate pool, a previously cached AI plan resolved through real sources, or rule-driven online candidates in that order.
4. A newly created rule-only session schedules one background AI plan. Verified AI candidates append after already-served candidates; current items, cursors, and playback queues are never reordered.
5. The latest valid AI plan is cached per profile generation. A later explicit refresh may resolve that cached plan for its first page without another synchronous planner call.
6. Flutter uploads at most the active server's 30 most recent song summaries as the initial signal. Backend does not infer listening history from Navidrome's internal tables.
7. One Backend instance owns one recommendation profile shared by all client devices using it. Multi-user profiles are not part of the first version.
8. Recommendation balance targets 70% similar content and 30% exploration.
9. The current homepage local random section is replaced by an online recommendation preview; “More” opens an infinite feed.
10. Every recommendation originates from an online music source. The first version does not scan the whole local library, so an online version of a pre-existing local song may occasionally appear.
11. Feedback persists until the user explicitly resets recommendation preferences.
12. Dislike blocks only the exact `source + sourceId`; it does not block the artist or style.
13. Import is explicit and is the strongest positive signal. No recommendation is imported automatically.
14. `played` is stored but does not trigger planning. Five accepted `completed` events since the last plan trigger a debounced refresh; an accepted `imported` or `disliked` event also triggers one. Only one planner job may run per profile generation.
15. Background AI completion affects subsequent pages and future explicit refreshes. It does not live-replace the visible first page.

## 3. Non-goals

The first version does not include:

- AI radio or automatic queue replenishment
- automatic Navidrome import
- multiple recommendation profiles or user accounts
- a full local-library duplicate index
- embeddings or a vector database
- a local LLM
- artist/style-level dislike
- free-text feedback reasons
- LLM-generated explanations in the UI
- direct playback of unverified LLM output
- changes to Android/iOS cleartext-network compatibility

## 4. Architecture

```text
Flutter App
  ├─ recent 30-song summary
  ├─ recommendation page state
  ├─ played/completed/imported/disliked/unavailable events
  └─ existing online playback and Navidrome import
             │ X-API-Key
             ▼
navidrome-backend
  ├─ RecommendationRouter
  ├─ RecommendationService                 canonical orchestration owner
  │    ├─ synchronous cached/rule first-page fill
  │    └─ background AI plan/refill single-flight
  ├─ RecommendationStore (independent SQLite)
  │    └─ profile-scoped latest valid plan + trigger watermark
  ├─ OpenAIPlanner (structured plan only)
  └─ MusicProxyService
              ├─ OpenAI-compatible API
              └─ real online music sources
```

The LLM is a background planner, not a music database and not part of the first-page critical path. Its structured plan is validated, cached for the current profile generation, searched against real sources, normalized, deduplicated, filtered, and ranked before candidates become API results.

## 5. OpenAI contract and prompt boundary

Backend configuration:

```env
OPENAI_API_KEY=
OPENAI_MODEL=gpt-5.6-terra
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_REASONING_EFFORT=xhigh
RECOMMENDATION_PLANNER_TIMEOUT=45
RECOMMENDATION_DB_PATH=/app/data/recommendations.db
RECOMMENDATION_SESSION_TTL_HOURS=24
RECOMMENDATION_DISCOVERY_SEEDS=流行新歌,热门歌曲,经典歌曲
```

The planner receives bounded data:

- at most 30 recent songs
- at most 50 recent positive feedback records
- aggregated long-term artist/song preference summaries
- exact disliked/imported identities needed for exclusion
- current-session exclusions
- fixed 70/30 similar/explore instruction

It does not receive server URLs, credentials, local paths, playback URLs, device data, or arbitrary transcript text.

Structured output contains exact candidate title/artist pairs and discovery search seeds divided into `similar` and `explore`. Each plan is capped at 40 exact candidates per category and 20 search seeds, with each generated text field capped at 200 Unicode characters. Invalid JSON, schema violations, timeouts, excessive output, or oversized fields invalidate only that background plan; the existing cached/rule candidate pool remains usable. Song metadata is treated as quoted data, not as instructions.

## 6. Real-source recall, ranking, and deduplication

Backend searches explicit `title + artist` candidates first, then discovery seeds. Supported sources are rotated through existing music-proxy capabilities with bounded concurrency (initially four to six upstream searches).

Strong identity:

```text
source + sourceId
```

Strong identity owns feedback, served-state, availability, and exact blocking.

Weak identity:

```text
normalize(title) + normalize(artist)
```

Weak identity is used only to collapse obvious cross-source duplicates in a batch. Normalization is conservative: Unicode/case/whitespace/common punctuation only. It must not erase Live, Remix, Remaster, language version, or collaboration distinctions.

Per page, Backend targets 14 similar and 6 explore candidates and generally limits an artist to two songs. It filters recent songs, served candidates, disliked songs, recommendation-imported songs, unavailable versions, and duplicates. Source search existence is verified before serving; expiring playback URLs are still resolved on demand by the existing playback path. Only a typed, non-retryable playback failure produces `unavailable`; transient network/time-out failures remain retryable and do not permanently suppress a source version.

## 7. Candidate pool and pagination

Defaults:

```text
page size: 20
pool target: 60
pool low watermark: 20
session TTL: 24 hours
planner timeout: 45 seconds (background only)
```

First-page order:

```text
existing session candidates
  → latest cached AI plan resolved through real sources
  → rule-driven online search
  → temporary no-more-results error
```

Session creation synchronously prepares at most the requested first page without invoking the planner. It then schedules one background AI job when the profile has no current plan or the feedback trigger watermark is dirty. Verified AI candidates append after current ranks, preserving every cursor and visible item. A valid completed plan is cached with the profile generation and feedback watermark so an explicit refresh can use it immediately.

Only one refill/planner task may run for a profile generation. Background work that finishes after reset or session expiry cannot write candidates or plan cache. There is no total page limit; refill continues while cached AI or rule search can produce unseen candidates.

Cursor is opaque to Flutter and stable for repeated requests. Existing items remain visible while planning, refill, or next-page work is in progress. Flutter does not poll or live-replace the first page; AI results naturally appear on later pages or after explicit refresh.

Rule-driven search uses recent/high-positive artists and tracks across sources/pages while applying the same exclusions and diversity rules. When no recent or positive signal exists, it rotates through the configurable neutral `RECOMMENDATION_DISCOVERY_SEEDS` list so a cold profile can still receive real online candidates. It never returns local random songs.

## 8. Persistence

Recommendation data is stored in its own SQLite file at `/app/data/recommendations.db`, mounted from a dedicated Backend data directory. It never writes recommendation state into Navidrome's SQLite database.

Tables:

- `recommendation_profile`: single-profile derived preference summary, latest valid structured plan, plan feedback watermark, monotonic profile generation, and update time
- `recommendation_feedback`: idempotent long-lived events and normalized identities
- `recommendation_sessions`: status, mode, creation, expiry, and refill state
- `recommendation_candidates`: source song payload, rank/type, served/blocked state, and session relation

The profile summary is derived from trusted feedback rows and excludes planner cache metadata before being sent to the model. Plan cache and trigger watermark are conditional on the captured profile generation. Reset atomically increments the generation, clears preference content, cached plan, feedback, sessions, and candidates, and leaves only the non-personal generation marker needed to reject stale work. OpenAI/upstream calls that finish after reset may return, but cannot repopulate cleared state. Old session cursors return `410 recommendation_session_expired`.

## 9. Backend API

All endpoints use existing Backend authentication and rate limiting.

### `POST /v1/recommendations/sessions`

Request:

```json
{
  "refresh": false,
  "pageSize": 20,
  "recent": [
    {
      "title": "Song",
      "artist": "Artist",
      "album": "Album",
      "source": "subsonic",
      "sourceId": "id"
    }
  ]
}
```

`refresh=false` resumes a valid current session or creates one. `refresh=true` ends the old session and creates a new one from the latest history. Both paths may resolve an already cached plan or rules, but neither waits for a new planner call.

Validation is strict and bounded: request body ≤64 KiB; `pageSize` 1–20; `recent` 0–30; `title` 1–200 Unicode characters; `artist`/`album` 0–200; `source` 1–32 using `[A-Za-z0-9_-]+`; and `sourceId` 1–256. The synchronous path prepares no more than the accepted `pageSize` and performs no LLM request. Any violation returns the versioned `400 recommendation_invalid_request` envelope without calling OpenAI or an upstream music source.

Response:

```json
{
  "contractVersion": 1,
  "sessionId": "opaque-id",
  "mode": "ai",
  "items": [
    {
      "candidateId": "opaque-id",
      "recommendationType": "similar",
      "song": {
        "id": "source-id",
        "title": "Song",
        "artist": "Artist",
        "album": "Album",
        "backend": "solara",
        "onlineSource": "netease",
        "urlId": "source-id"
      }
    }
  ],
  "nextCursor": "opaque-cursor",
  "hasMore": true
}
```

`contractVersion` remains `1`; Flutter rejects unsupported versions. `mode` is `fallback` while only rule candidates are available and may become `ai` after a valid cached/background plan supplies verified candidates. The value describes the session's current planning capability, not the provenance of every item already served. Existing items are never reordered when mode changes. Both session creation and every next-page response use this same versioned page envelope. Recommendation endpoint errors use a versioned envelope: `{"contractVersion":1,"code":"...","detail":"...","retryable":false}`; this includes stale-session `410` and recommendation-path authentication/rate-limit errors.

### `GET /v1/recommendations/sessions/{sessionId}/items?cursor=...&limit=20`

Returns the next stable page in the same `contractVersion: 1` envelope and triggers a single refill when the pool reaches its low watermark. `limit` is required to be 1–20, `cursor` is limited to 512 characters, and `sessionId` to 128 characters; invalid values return the versioned `400 recommendation_invalid_request` envelope before storage or upstream work. A session/cursor from an expired or reset profile generation returns the versioned `410 recommendation_session_expired` error envelope.

### `POST /v1/recommendations/feedback`

```json
{
  "idempotencyKey": "uuid",
  "sessionId": "session-id",
  "candidateId": "candidate-id",
  "event": "disliked"
}
```

Events are `played`, `completed`, `imported`, `disliked`, and `unavailable`. Backend resolves trusted metadata from `candidateId`; feedback does not accept an arbitrary profile payload. Feedback from a stale profile generation is rejected and cannot recreate reset data.

Accepted feedback updates the derived profile immediately. `played` and `unavailable` do not schedule planning. Five new `completed` events after the persisted plan watermark, or one new `imported`/`disliked` event, marks the profile dirty and schedules one debounced background plan. Duplicate feedback never advances the trigger watermark.

Feedback has two database uniqueness barriers: `UNIQUE(idempotency_key)` and semantic `UNIQUE(profile_generation, session_id, candidate_id, event)`. Flutter creates one UUID when an event first becomes eligible and reuses that UUID for every network retry until a definitive response. Repeating either key returns HTTP 200 with `{"contractVersion":1,"accepted":false,"duplicate":true}` and never increments preference weight twice. The semantic key intentionally permits the same candidate to earn a new positive event in a later session while preventing duplicate scoring within one impression.

Feedback validation requires an RFC 4122 UUID `idempotencyKey`, `sessionId`/`candidateId` of 1–128 characters, and one of the five declared event values. The feedback body is limited to 4 KiB. Invalid feedback returns the versioned `400 recommendation_invalid_request` envelope without a database mutation.

### `DELETE /v1/recommendations/profile`

Atomically advances profile generation and clears recommendation preference content, feedback, sessions, and candidates only. In-flight work from the prior generation is discarded on write.

Initial limits:

- session creation: 5/minute
- next page: 60/minute
- feedback: 120/minute
- reset: 2/minute

## 10. Feedback semantics

- `played`: +1 after 30 seconds or 25% of duration
- `completed`: +4 at 90%
- `imported`: +6 and exact-song suppression
- `disliked`: permanent exact `source + sourceId` deny
- `unavailable`: permanent source-version suppression without taste penalty, emitted only for a typed non-retryable resolution/source failure

Client and Backend both prevent duplicate events using the stable event UUID and the semantic uniqueness constraint above. Pure scrolling/skipping is not negative feedback.

## 11. Flutter design

### Models

`RecommendationItem` contains `candidateId`, `recommendationType`, and `Song`. `RecommendationPage` contains session ID, mode, items, cursor, and `hasMore`. Generic `Song` remains free of recommendation session state.

### State owner

A single `RecommendationNotifier` owns homepage preview and the full feed. Its state includes items, session ID, cursor, mode, initial/loading-more/error flags, and per-item dislike/import progress. It watches Backend configuration and active server identity, uses request generation, rejects stale responses, and prevents concurrent pagination.

The notifier obtains recent songs from `AudioPlayerService.playHistory`, calls Backend APIs, performs defensive identity deduplication, handles optimistic dislike with rollback, and delegates import to the existing `NavidromeImportService`. It never waits for or polls planner completion, and it never replaces visible items because a session mode changes. Pull-to-refresh is the explicit first-page adoption boundary for a newly cached AI plan.

### Playback feedback observer

A `RecommendationPlaybackTracker` observes player streams but never controls playback. `NavidromeAudioHandler`, as the actual source owner, publishes a sanitized typed `PlaybackFailure` stream containing scoped song identity, failure kind, request generation, and a retryable flag—never the URL or raw exception. `AudioPlayerService` exposes that stream without reinterpreting it. The recommendation owner registers served candidate identities; the tracker maps successful playback thresholds and non-retryable failures back to candidate IDs. It emits `played`, `completed`, or `unavailable` once per recommendation impression using idempotency keys. Ordinary library songs and retryable network failures do not produce recommendation suppression feedback.

### Homepage

The old `dailySongsProvider`/local random product path is retired. Homepage consumes the same recommendation state as the full page, displays six to nine items, and adds “More” to `/recommendations`. Pull-to-refresh requests a new recommendation session while preserving unrelated homepage refresh behavior.

### Infinite page

`RecommendationsScreen` uses lazy list/sliver rendering and loads near 400 pixels from the end. It preserves existing items on next-page error and exposes play, play-next, queue, download, explicit import, and dislike actions. It never automatically imports or fills the playback queue.

### Settings

A Recommendation section shows `AI` or `Basic recommendation` mode and provides “Reset recommendation preferences”. Reset requires confirmation and explicitly states that songs, downloads, play history, and server configuration are unaffected.

## 12. UI and failure behavior

- Backend not configured: show a configuration action in the recommendation section.
- Initial rule/cache failure: recommendation-local retry; other homepage sections remain usable.
- Next-page failure: preserve current feed and show inline retry.
- Background planner failure: retain cached/rule candidates; no blocking error replaces usable content.
- Dislike: optimistically remove; rollback and notify on API failure.
- Import: show item-local progress; report `imported` and remove only after existing import succeeds.
- Typed non-retryable playback failure: report `unavailable`, remove/replace the candidate, and do not treat it as dislike. Retryable network/time-out failures retain the candidate and expose retry.
- Empty/temporary exhaustion: retain the feed and offer retry rather than fabricating candidates.

## 13. Rate, cost, and latency controls

- No OpenAI call is allowed on the first-page request path.
- One concurrent planner/refill task per profile generation.
- New planning occurs on cold profile, low watermark, five completed events, or an imported/disliked event; triggers coalesce through one debounce and persisted feedback watermark.
- Bounded recent/feedback context and structured output size.
- Configurable reasoning effort and background planner timeout; no unbounded retry.
- Bounded upstream search concurrency.
- Cached candidate pages return without an OpenAI round trip.
- Cold first-page latency contains only SQLite and bounded real-source search; target p95 is under two seconds when upstream sources are healthy.
- Background planning latency does not block playback, homepage rendering, or current pagination.

## 14. Verification

Backend tests use fake planner and fake music proxy; no test calls real OpenAI or music sources. Coverage includes immediate cold rule first page with zero planner calls, cached-plan first page, background plan append, stable ranks/cursors, explicit refresh adopting the cached plan, planner single-flight, feedback trigger thresholds/debounce, duplicate feedback not retriggering, restart-persisted watermark, session resume/refresh, cold-profile neutral seeds, 70/30 selection, diversity, strong/weak deduplication, recent/dislike/import/unavailable filtering, reset racing with planner/refill, stale-generation rejection, timeout retention of rule candidates, auth/rate limits, SQLite restart persistence, and strict request limits.

Flutter tests cover contract-version/response parsing, immediate rule page, later `fallback → ai` mode transition without item replacement, initial/pagination/error states, duplicate and stale-response rejection, shared homepage/feed state, dislike rollback, import feedback, typed playback-failure mapping, playback thresholds, stable feedback UUID reuse, semantic duplicate responses, ordinary-song exclusion, reset confirmation, and server/config changes.

Cross-repository contract fixtures remain versioned as `recommendation_page.v1.json` in Backend `tests/contracts/` and Flutter `test/fixtures/`. No response field or enum value is added by staged fill. Backend ASGI tests produce/validate the canonical camelCase page and error envelopes; Flutter parses the same fixture. A cross-repository integration check compares normalized fixtures before release.

An environment-bound smoke test may call a configured planner and real music search with sanitized synthetic history. It verifies first-page response latency separately from background-plan readiness and must not log the key, prompt, source history, or raw model response.

## 15. Acceptance criteria

- Homepage local random recommendation is replaced by online personalized preview.
- A first page is returned without waiting for an LLM call; fake-planner tests prove zero synchronous planner invocations.
- Every served candidate comes from a real online music-source search result.
- With a deterministic fake source capable of at least 100 unique candidates, five consecutive pages load without duplicate strong identities or a fixed total cap.
- A valid background plan appends candidates without changing existing ranks/cursors, and an explicit refresh can adopt the cached plan for its first page.
- Feedback triggers are batched: five completed events or one imported/disliked event; duplicates and played-only activity do not start planner work.
- No recommendation is imported automatically.
- Import and dislike match the confirmed feedback behavior.
- Effective session restores after App restart and refresh creates a new session.
- Planner outage or timeout retains online rule recommendations when sources are available.
- Feedback, latest-plan watermark, and cached plan persist across Backend restart; reset affects only recommendation-owned data.
- OpenAI key is absent from Flutter, API responses, logs, fixtures, and committed configuration.
- Flutter and Backend static checks and full test suites pass.

## 16. Ownership, compatibility, and retirement

Canonical owners:

- recommendation product state: Flutter `RecommendationNotifier`
- actual playback state: existing `NavidromeAudioHandler`
- typed playback failure ownership: existing `NavidromeAudioHandler`, exposed unchanged by `AudioPlayerService`
- recommendation orchestration: Backend `RecommendationService`
- recommendation persistence: Backend `RecommendationStore`
- LLM interaction: Backend `OpenAIPlanner`
- real-source access: existing `MusicProxyService`
- Navidrome import: existing `NavidromeImportService`

The old homepage `dailySongsProvider` random recommendation is retired after the new provider passes homepage and regression tests. Navidrome `getRandomSongs` remains a valid generic API method and is not deleted solely because this homepage consumer retires.

This feature does not change existing multi-server data migration, download/history retention, Backend credential separation, or cleartext-network compatibility decisions.

## 17. Risks and evolution triggers

- If one Backend is shared by multiple people, introduce explicit profiles; do not infer users from device IDs.
- If exact-song search quality is poor, measure misses before adding aliases or fuzzy-version heuristics.
- If planner cost dominates, raise feedback thresholds or plan TTL before adding another cache/queue owner.
- If process-local debounce loss during restart causes material extra calls, add a durable job owner as a separate decision; the persisted watermark already preserves correctness.
- If recommendation quality needs semantic retrieval over a known catalog, evaluate an indexed catalog/vector stage as a separate architecture decision.
- If users request continuous playback, build AI radio on the same session API as a later feature rather than coupling it into this feed.
- If neutral cold-start discovery proves culturally biased, change the deployment-configured seed list or add an explicit onboarding preference; do not silently infer locale from credentials or device identity.

## 18. Requirement and architecture alignment

- Product baseline: confirmed through the staged user decisions recorded in this design.
- Architecture baseline: aligned with Backend-owned secrets/orchestration, Riverpod state ownership, existing playback/import owners, and independent recommendation persistence.
- Result: aligned; scope covers both requirements and architecture.
- ADR signal: the durable split “LLM planner + verified source recall” and independent recommendation store should receive an ADR when implementation proves the contract.
