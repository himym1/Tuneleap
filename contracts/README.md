# Shared contracts

This directory is for cross-deployable contracts. It is not a fourth runtime.

## HTTP APIs

Canonical HTTP docs stay next to the service that implements them:

- Cloud: [`../services/cloud/docs/API.md`](../services/cloud/docs/API.md)
- NAS Agent: [`../services/nas-agent/docs/API.md`](../services/nas-agent/docs/API.md)

Cloud owns search, media resolution, auth, recommendations, and private updates. NAS Agent owns import, delete, scan, and library identities. Do not add the other service's routes to "make the monorepo simpler".

## Identity

Recommendation filtering compares weak identity strings from:

- Flutter import/dedup (`apps/player/lib/utils/song_identity.dart`)
- Cloud recommendation scoring (`services/cloud/app/services/recommendation_identity.py`)
- NAS Agent library export (`services/nas-agent/app/services/recommendation_identity.py`)

Shared cases: [`identity/cases.v1.json`](identity/cases.v1.json).

The Dart implementation currently understands more CJK punctuation and version labels than the two Python copies. New behavior must land in the fixture first, then in all three implementations.
