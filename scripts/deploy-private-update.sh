#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
REMOTE_HOST="${REMOTE_HOST:-himym}"
REMOTE_DIR="${REMOTE_DIR:-/volume1/docker/navidrome-backend/releases}"
source "$SCRIPT_DIR/versions.env"

"$SCRIPT_DIR/prepare-private-update.sh"

files=(
  "navidrome_player-${ANDROID_VERSION}+${ANDROID_BUILD}-android.apk"
  "navidrome_player-${MACOS_VERSION}+${MACOS_BUILD}-macos.dmg"
  "SHA256SUMS"
  "version.json"
)

cd "$DIST_DIR"
tar -cf - "${files[@]}" | ssh "$REMOTE_HOST" "set -euo pipefail
mkdir -p '$REMOTE_DIR'
staging=\$(mktemp -d '$REMOTE_DIR/.staging.XXXXXX')
trap 'rm -rf \"\$staging\"' EXIT
tar -xf - -C \"\$staging\"
for file in ${files[*]}; do mv -f \"\$staging/\$file\" '$REMOTE_DIR/'; done
"

echo "Deployed private update artifacts to $REMOTE_HOST:$REMOTE_DIR"
