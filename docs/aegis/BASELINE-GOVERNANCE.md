# Baseline Governance

## Baseline roles

- **Product / Requirement Baseline:** confirmed target behavior, scenarios, acceptance criteria, non-goals, and user decisions.
- **Architecture / Runtime Boundary Baseline:** canonical owners, contracts, dependency direction, compatibility, persistence, and retirement boundaries.

## Alignment rules

- Fix a confirmed requirement/design defect before adapting implementation around it.
- Treat implementation that deviates from an approved unchanged baseline as implementation drift.
- Baseline snapshots are evidence; accepted ADRs and explicit user decisions retain authority.
- Non-trivial changes must preserve one canonical owner per responsibility and include fresh verification.

## Hard boundaries

- Persistent user data is not deleted without explicit scoped confirmation.
- Client and Backend secrets never enter design fixtures, logs, or committed configuration.
- Compatibility paths need a retention reason and a clear retirement trigger.
