#!/usr/bin/env bash
# Local navidrome-cloud recommendation smoke harness.
# Requires RECOMMENDATION_SMOKE_API_KEY (or API_KEY) in the environment.
# It mutates recommendation sessions/profile; do not point it at production unintentionally.
set -euo pipefail

BASE_URL="${RECOMMENDATION_SMOKE_BASE_URL:-http://127.0.0.1:8600}"
API_KEY="${API_KEY:-${RECOMMENDATION_SMOKE_API_KEY:-}}"

if [[ -z "${API_KEY}" ]]; then
  echo "missing API_KEY / RECOMMENDATION_SMOKE_API_KEY" >&2
  exit 2
fi

auth=(-H "X-API-Key: ${API_KEY}" -H "Content-Type: application/json")

echo "== create/resume session =="
create_body='{"refresh":false,"pageSize":10,"recent":[{"title":"Northern Lights","artist":"Harbor Lines","album":"Night Signals","source":"netease","sourceId":"demo-1"},{"title":"Paper Satellites","artist":"Static Coast","album":"Open Frequencies","source":"migu","sourceId":"demo-2"},{"title":"City After Rain","artist":"Signal Bloom","album":"Glass Streets","source":"joox","sourceId":"demo-3"}]}'
create_resp="$(curl -fsS "${auth[@]}" -d "${create_body}" "${BASE_URL}/v1/recommendations/sessions")"
python3 - <<'PY' "${create_resp}"
import json,sys
page=json.loads(sys.argv[1])
assert page.get("contractVersion")==1, page
assert page.get("mode") in {"ai","fallback"}, page
assert isinstance(page.get("items"), list) and len(page["items"])<=20
print("session", page.get("sessionId"), "mode", page.get("mode"), "items", len(page["items"]))
print(page.get("sessionId") or "")
print(page["items"][0]["candidateId"] if page["items"] else "")
PY
mapfile -t meta < <(python3 - <<'PY' "${create_resp}"
import json,sys
page=json.loads(sys.argv[1])
print(page.get("sessionId") or "")
print(page["items"][0]["candidateId"] if page.get("items") else "")
print(page.get("nextCursor") or "")
PY
)
SESSION_ID="${meta[0]}"
CANDIDATE_ID="${meta[1]}"
CURSOR="${meta[2]}"

if [[ -n "${SESSION_ID}" && -n "${CANDIDATE_ID}" ]]; then
  KEY="$(python3 - <<'PY'
import uuid; print(uuid.uuid4())
PY
)"
  echo "== feedback once =="
  curl -fsS "${auth[@]}" -d "{\"idempotencyKey\":\"${KEY}\",\"sessionId\":\"${SESSION_ID}\",\"candidateId\":\"${CANDIDATE_ID}\",\"event\":\"played\"}" \
    "${BASE_URL}/v1/recommendations/feedback" >/tmp/rec-smoke-feedback1.json
  echo "== feedback duplicate =="
  curl -fsS "${auth[@]}" -d "{\"idempotencyKey\":\"${KEY}\",\"sessionId\":\"${SESSION_ID}\",\"candidateId\":\"${CANDIDATE_ID}\",\"event\":\"played\"}" \
    "${BASE_URL}/v1/recommendations/feedback" >/tmp/rec-smoke-feedback2.json
  python3 - <<'PY'
import json
a=json.load(open("/tmp/rec-smoke-feedback1.json"))
b=json.load(open("/tmp/rec-smoke-feedback2.json"))
assert a.get("contractVersion")==1 and b.get("contractVersion")==1
assert a.get("accepted") is True
assert b.get("duplicate") is True
print("feedback ok", a, b)
PY
fi

if [[ -n "${SESSION_ID}" && -n "${CURSOR}" ]]; then
  echo "== next page =="
  curl -fsS "${auth[@]}" \
    "${BASE_URL}/v1/recommendations/sessions/${SESSION_ID}/items?limit=10&cursor=${CURSOR}" \
    >/tmp/rec-smoke-page.json || true
fi

echo "== reset profile =="
curl -fsS -X DELETE "${auth[@]}" "${BASE_URL}/v1/recommendations/profile" >/tmp/rec-smoke-reset.json
python3 - <<'PY'
import json
r=json.load(open("/tmp/rec-smoke-reset.json"))
assert r.get("contractVersion")==1 and r.get("reset") is True
print("reset ok")
PY

if [[ -n "${SESSION_ID}" ]]; then
  echo "== stale session expect 410 =="
  code="$(curl -sS -o /tmp/rec-smoke-stale.json -w '%{http_code}' "${auth[@]}" \
    "${BASE_URL}/v1/recommendations/sessions/${SESSION_ID}/items?limit=5" || true)"
  echo "stale status=${code}"
  python3 - <<'PY'
import json
from pathlib import Path
raw=Path("/tmp/rec-smoke-stale.json").read_text().strip()
if raw:
    data=json.loads(raw)
    assert data.get("contractVersion")==1
    print("stale body code", data.get("code"))
PY
fi

echo "smoke finished (inspect /tmp/rec-smoke-*.json). Never commit those files."
