#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"
source "$SCRIPT_DIR/versions.env"
UPDATE_ORIGIN="${UPDATE_ORIGIN:-https://player.himym.us.ci}"

android="navidrome_player-${ANDROID_VERSION}+${ANDROID_BUILD}-android.apk"
macos="navidrome_player-${MACOS_VERSION}+${MACOS_BUILD}-macos.dmg"
windows="navidrome_player-${WINDOWS_VERSION}+${WINDOWS_BUILD}-windows.zip"
[ -f "$DIST_DIR/$android" ] || { echo "Missing $DIST_DIR/$android" >&2; exit 1; }
[ -f "$DIST_DIR/$macos" ] || { echo "Missing $DIST_DIR/$macos" >&2; exit 1; }

cd "$DIST_DIR"
if [ -f "$windows" ]; then
  shasum -a 256 "$android" "$macos" "$windows" > SHA256SUMS
else
  shasum -a 256 "$android" "$macos" > SHA256SUMS
fi

python3 - "$ANDROID_VERSION" "$ANDROID_BUILD" "$android" \
  "$MACOS_VERSION" "$MACOS_BUILD" "$macos" "$UPDATE_ORIGIN" \
  "${WINDOWS_VERSION:-}" "${WINDOWS_BUILD:-}" "$windows" <<'PY'
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
    windows_version,
    windows_build,
    windows_name,
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
    "changelog": (
        "曲库体检分音质与版本；替换可选搜索结果；歌单有详情页；首页改为最新歌曲。"
    )
}
if Path(windows_name).is_file():
    if not re.fullmatch(r"\d+\.\d+\.\d+", windows_version):
        raise SystemExit(f"Invalid version: {windows_version}")
    if not windows_build.isdecimal() or int(windows_build) < 1:
        raise SystemExit(f"Invalid build: {windows_build}")
    data["windows"] = {
        "version": windows_version,
        "build": int(windows_build),
        "url": f"{origin}/{windows_name}",
        "sha256": digest(windows_name),
    }
Path("version.json").write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
PY

SPARKLE_BIN="$("$SCRIPT_DIR/ensure-sparkle-tools.sh")"
sign_output="$("$SPARKLE_BIN/sign_update" "$DIST_DIR/$macos")"
python3 "$SCRIPT_DIR/write_appcast.py" \
  --origin "$UPDATE_ORIGIN" \
  --macos-version "$MACOS_VERSION" \
  --macos-build "$MACOS_BUILD" \
  --macos-name "$macos" \
  --sign-output "$sign_output" \
  --changelog "曲库体检分音质与版本；替换可选搜索结果；歌单有详情页；首页改为最新歌曲。" \
  --output "$DIST_DIR/appcast.xml"

echo "Prepared private update metadata in $DIST_DIR"
