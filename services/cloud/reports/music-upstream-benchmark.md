# Music upstream benchmark

Date: 2026-07-31
Execution host: dmit Docker network
Corpus: 10 query types × 2 rounds per provider, plus page 1–3 and resource probes.

## Compared upstreams

- GDStudio: `https://music-api.gdstudio.xyz/api.php`
- Public Meting: `https://meting.mikus.ink/api`
- Ephemeral self-hosted Meting: `ghcr.io/metowolf/meting-api:latest`, Docker-internal only

The standard Meting protocol and deployment behavior were checked against:

- https://github.com/metowolf/Meting-API
- https://meting.mikus.ink/
- https://github.com/qq01-hub/openmusic/blob/main/docs/DEPLOY.md

## Public endpoint comparison

| Metric | GDStudio | Public Meting |
|---|---:|---:|
| Search attempts | 20 | 20 |
| HTTP/adapter success | 100% | 100% |
| Non-empty rate for expected-result queries | 22.2% | **100%** |
| Mean relevant ratio in top 10 | 22.2% | **98.9%** |
| Search latency P50 | **303.9 ms** | 859.3 ms |
| Search latency P95 | **846.4 ms** | 1531.6 ms |
| Correctly empty for nonsense query | 50% | 0% |
| Top-5 URL resolution/playability probe | not consistently sampleable | **20/20 (100%)** |
| Cover / lyric probe | no stable search sample | passed |

GDStudio was faster when it returned, but usually returned HTTP 200 with an empty list. Public Meting was slower but returned relevant content for every expected-result query and resolved all 20 sampled playback URLs.

Both providers can return irrelevant fallback content for a nonsense query; HTTP 200/non-empty alone is not a relevance guarantee.

## Self-hosted Meting comparison

| Metric | GDStudio in same run | Self-hosted Meting |
|---|---:|---:|
| Non-empty rate | 0% | **100%** |
| Mean relevant ratio in top 10 | 0% | **97.8%** |
| Search latency P50 | 301.8 ms | 396.3 ms |
| Search latency P95 | 470.4 ms | 730.0 ms |
| Top-5 actual playability without NetEase cookie | — | 5/20 (25%) |

Self-hosting improves latency substantially, but anonymous NetEase URL resolution is not good enough for primary production use. Search, cover, and lyrics work; playback requires a maintained NetEase cookie to approach the public endpoint's result.

## Pagination

- GDStudio exposes a `pages` parameter but behaved inconsistently: different runs returned empty pages, and one run returned results only on page 3.
- Standard Meting returns one result window (30 items) and has no stable page parameter. The adapter intentionally treats page 2+ as terminal so it cannot repeat page 1 indefinitely.

## Decision

Use the public Meting endpoint first and GDStudio second:

```env
METING_API_BASE_URLS=https://meting.mikus.ink/api
MUSIC_ADAPTER_ORDER=meting,gdstudio
```

Rationale:

1. Search availability and top-10 relevance dominate the latency difference; a fast empty response is not useful.
2. Public Meting passed search, URL, cover, lyric, and sampled media playability probes.
3. GDStudio remains a separate-family fallback for endpoint outages.
4. A self-hosted Meting instance should replace the public endpoint only after a NetEase cookie is configured and the 20-song playability probe passes at an acceptable rate.

## Known limits

- Public Meting is third-party infrastructure and has no project-controlled SLO.
- Standard Meting search currently provides only the first 30 items.
- Both providers need relevance filtering or explicit “no good matches” handling for nonsense queries.
- Results are a bounded operational benchmark, not a long-duration availability study.

Machine-readable evidence:

- `reports/music-upstream-benchmark.json`
- `reports/music-upstream-benchmark-selfhost.json`
- `reports/meting-playability-public.json`
- `reports/meting-playability-selfhost.json`
