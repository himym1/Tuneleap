#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"
source "$SCRIPT_DIR/versions.env"
UPDATE_ORIGIN="${UPDATE_ORIGIN:-https://player.himym.us.ci}"

android="navidrome_player-${ANDROID_VERSION}+${ANDROID_BUILD}-android.apk"
macos="navidrome_player-${MACOS_VERSION}+${MACOS_BUILD}-macos.dmg"
[ -f "$DIST_DIR/$android" ] || { echo "Missing $DIST_DIR/$android" >&2; exit 1; }
[ -f "$DIST_DIR/$macos" ] || { echo "Missing $DIST_DIR/$macos" >&2; exit 1; }

cd "$DIST_DIR"
shasum -a 256 "$android" "$macos" > SHA256SUMS

python3 - "$ANDROID_VERSION" "$ANDROID_BUILD" "$android" \
  "$MACOS_VERSION" "$MACOS_BUILD" "$macos" "$UPDATE_ORIGIN" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit

(
    android_version,
    android_build,
    android_name,
    macos_version,
    macos_build,
    macos_name,
    update_origin,
 ) = sys.argv[1:]
for version in (android_version, macos_version):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise SystemExit(f"Invalid version: {version}")
for build in (android_build, macos_build):
    if not build.isdecimal() or int(build) < 1:
        raise SystemExit(f"Invalid build: {build}")

def digest(name: str) -> str:
    value = hashlib.sha256()
    with Path(name).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()

parsed_origin = urlsplit(update_origin)
if (
    parsed_origin.scheme != "https"
    or not parsed_origin.netloc
    or parsed_origin.username is not None
    or parsed_origin.password is not None
    or parsed_origin.path not in ("", "/")
    or parsed_origin.query
    or parsed_origin.fragment
):
    raise SystemExit(f"Invalid UPDATE_ORIGIN: {update_origin}")
origin = f"{update_origin.rstrip('/')}/releases"
data = {
    "android": {
        "version": android_version,
        "build": int(android_build),
        "url": f"{origin}/{android_name}",
        "sha256": digest(android_name),
    },
    "macos": {
        "version": macos_version,
        "build": int(macos_build),
        "url": f"{origin}/{macos_name}",
        "sha256": digest(macos_name),
    },
    "changelog": "登录页合并 Cloud 账号；启动静默恢复会话，避免反复弹出登录。",
}
Path("version.json").write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
PY

echo "Prepared private update metadata in $DIST_DIR"
