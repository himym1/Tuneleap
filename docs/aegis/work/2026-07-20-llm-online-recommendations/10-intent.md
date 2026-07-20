# LLM Online Recommendations Implementation - Intent

## TaskIntentDraft

- Requested outcome: Implement the approved verified online recommendation feed across Flutter and FastAPI Backend.
- Goal: Implement the approved verified online recommendation feed across Flutter and FastAPI Backend.
- Success evidence:
- All 14 plan tasks and five review gates pass; both repositories pass full verification and contract fixtures match.
- Stop condition: Stop when verified complete, blocked on external authorization, needs verification, or scope would exceed the approved spec.
- Non-goals:
- Deployment, credentials, AI radio, profiles, embeddings, Navidrome DB changes, or cleartext policy.
- Scope: Backend recommendation contract/store/planner/service/API and Flutter contract/provider/playback feedback/UI/reset.
- Change kinds:
- feature
- Risk hints:
- Cross-repository contract, persistent feedback, OpenAI boundary, playback attribution, and dirty main workspace isolation.

## BaselineReadSetHint

- docs/aegis/specs/2026-07-20-llm-online-recommendations-design.md
- docs/aegis/plans/2026-07-20-llm-online-recommendations-implementation.md
- docs/adr/0001-multi-server-session-isolation.md

## BaselineUsageDraft

- Required baseline refs:
- docs/aegis/specs/2026-07-20-llm-online-recommendations-design.md
- docs/aegis/plans/2026-07-20-llm-online-recommendations-implementation.md
- docs/adr/0001-multi-server-session-isolation.md
- Acknowledged before plan:
- none
- Cited in plan:
- none
- Missing refs:
- docs/aegis/specs/2026-07-20-llm-online-recommendations-design.md
- docs/aegis/plans/2026-07-20-llm-online-recommendations-implementation.md
- docs/adr/0001-multi-server-session-isolation.md
- Advisory decision: needs-baseline-readback

## ImpactStatementDraft

- Compatibility boundary: Preserve existing playback, server isolation, downloads, history, import, and Backend endpoints.
- Affected layers:
- backend
- flutter
- Owners:
- RecommendationService / RecommendationNotifier
- Invariants:
- Only verified real-source songs reach Flutter; recommendation state never controls playback.
- Non-goals:
- Deployment, credentials, AI radio, profiles, embeddings, Navidrome DB changes, or cleartext policy.

These records are Method Pack drafts / hints, not authoritative runtime decisions.
