#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"
REMOTE_HOST="${REMOTE_HOST:-dmit}"
REMOTE_DIR="${REMOTE_DIR:-/opt/navidrome-cloud/releases}"
REMOTE_ENV_FILE="${REMOTE_ENV_FILE:-/opt/navidrome-cloud/.env}"
UPDATE_ORIGIN="${UPDATE_ORIGIN:-https://player.himym.us.ci}"
source "$SCRIPT_DIR/versions.env"

DIST_DIR="$DIST_DIR" UPDATE_ORIGIN="$UPDATE_ORIGIN" \
  "$SCRIPT_DIR/prepare-private-update.sh"

android_file="navidrome_player-${ANDROID_VERSION}+${ANDROID_BUILD}-android.apk"
macos_file="navidrome_player-${MACOS_VERSION}+${MACOS_BUILD}-macos.dmg"
files=("$android_file" "$macos_file" "SHA256SUMS" "version.json")

for file in "${files[@]}"; do
  test -f "$DIST_DIR/$file" || { echo "missing artifact: $DIST_DIR/$file" >&2; exit 2; }
done

cd "$DIST_DIR"
tar -cf - "${files[@]}" | ssh "$REMOTE_HOST" "set -euo pipefail
mkdir -p '$REMOTE_DIR'
staging=\$(mktemp -d '$REMOTE_DIR/.staging.XXXXXX')
manifest_tmp=''
previous_tmp=''
trap 'rm -rf \"\$staging\"; test -z \"\$manifest_tmp\" || rm -f \"\$manifest_tmp\"; test -z \"\$previous_tmp\" || rm -f \"\$previous_tmp\"' EXIT
tar -xf - -C \"\$staging\"
cd \"\$staging\"
sha256sum -c SHA256SUMS
for file in '$android_file' '$macos_file' SHA256SUMS; do
  incoming='$REMOTE_DIR/.incoming.'\"\$file\"'.'\"\$\$\"
  install -m 0644 \"\$file\" \"\$incoming\"
  mv -f \"\$incoming\" '$REMOTE_DIR/'\"\$file\"
done
manifest_tmp=\$(mktemp '$REMOTE_DIR/.version.json.XXXXXX')
install -m 0644 version.json \"\$manifest_tmp\"
if test -f '$REMOTE_DIR/version.json'; then
  previous_tmp=\$(mktemp '$REMOTE_DIR/.version.previous.json.XXXXXX')
  cp -p '$REMOTE_DIR/version.json' \"\$previous_tmp\"
  mv -f \"\$previous_tmp\" '$REMOTE_DIR/.version.previous.json'
  previous_tmp=''
fi
mv -f \"\$manifest_tmp\" '$REMOTE_DIR/version.json'
manifest_tmp=''
"

ssh "$REMOTE_HOST" bash -s -- \
  "$REMOTE_ENV_FILE" "$UPDATE_ORIGIN" "$ANDROID_VERSION" "$ANDROID_BUILD" \
  "$REMOTE_DIR" <<'REMOTE'
set -euo pipefail
env_file="$1"
origin="$2"
expected_version="$3"
expected_build="$4"
release_dir="$5"
rollback_on_error() {
  status=$?
  trap - EXIT
  if test "$status" -eq 0; then return; fi
  if test -f "$release_dir/.version.previous.json"; then
    rollback_tmp=$(mktemp "$release_dir/.version.rollback.XXXXXX")
    cp -p "$release_dir/.version.previous.json" "$rollback_tmp"
    mv -f "$rollback_tmp" "$release_dir/version.json"
  else
    rm -f "$release_dir/version.json"
  fi
  echo "public verification failed; version manifest rolled back" >&2
  exit "$status"
}
trap rollback_on_error EXIT
api_key=$(sed -n 's/^API_KEY=//p' "$env_file" | tail -1)
test -n "$api_key"
response=$(printf 'header = "X-API-Key: %s"\n' "$api_key" | \
  curl --config - -fsS "$origin/version.json")
UPDATE_RESPONSE="$response" python3 - \
  "$expected_version" "$expected_build" "$origin" <<'PY'
import json
import os
import sys

data = json.loads(os.environ["UPDATE_RESPONSE"])
expected_version, expected_build, origin = sys.argv[1:]
expected_prefix = f"{origin.rstrip('/')}/releases/"
for platform in ("android", "macos"):
    item = data[platform]
    assert item["url"].startswith(expected_prefix), item
android = data["android"]
assert android["version"] == expected_version, android
assert android["build"] == int(expected_build), android
print(f"public update metadata ok: android {android['version']}+{android['build']}")
PY
trap - EXIT
REMOTE

echo "Published private update to $UPDATE_ORIGIN via $REMOTE_HOST:$REMOTE_DIR"
