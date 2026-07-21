# Task 13 Smoke Runbook (authorized env only)

Do **not** run against production/NAS without separate approval.

## Preconditions
- Local or explicitly approved test Backend is running
- `API_KEY` is available to the shell (never print it)
- Optional: `OPENAI_API_KEY` configured in Backend env for `mode=ai`
- Recommendation DB may be temporary

## Command
```bash
# from either worktree
export RECOMMENDATION_SMOKE_BASE_URL=http://127.0.0.1:8503
export API_KEY=...   # do not commit
./scripts/recommendation-smoke.sh
```

## Checks covered by script
1. create/resume session with 3 synthetic recent songs
2. `contractVersion=1`, mode in `{ai,fallback}`, item count ≤ 20
3. feedback accepted then duplicate with same UUID
4. optional next-page fetch when cursor present
5. profile reset
6. old session path returns versioned stale/410 style body when applicable

## Fallback mode
Stop Backend, unset OpenAI key in a **local** process only, restart, rerun script, expect `mode=fallback` with online candidates when sources still work.

## Log review
Inspect sanitized app logs only. Confirm absence of prompt/history/raw OpenAI body/API key/playback URL.
