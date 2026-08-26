#!/usr/bin/env bash
set -euo pipefail

# Downloads Sparkle CLI (generate_keys / sign_update) into tools/sparkle.
# Private EdDSA key stays in the macOS Keychain. Do not copy it into the repo.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${SPARKLE_TOOLS_VERSION:-2.8.0}"
TOOLS_DIR="${SPARKLE_TOOLS_DIR:-$PROJECT_ROOT/tools/sparkle/$VERSION}"
BIN_DIR="$TOOLS_DIR/bin"

if [ -x "$BIN_DIR/sign_update" ] && [ -x "$BIN_DIR/generate_keys" ]; then
  printf '%s\n' "$BIN_DIR"
  exit 0
fi

mkdir -p "$TOOLS_DIR"
archive="$TOOLS_DIR/Sparkle-$VERSION.tar.xz"
if [ ! -f "$archive" ]; then
  curl -fsSL \
    "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" \
    -o "$archive"
fi
tar -xJf "$archive" -C "$TOOLS_DIR"
if [ ! -x "$BIN_DIR/sign_update" ]; then
  # Some archives unpack bin/ next to Sparkle.framework.
  found="$(find "$TOOLS_DIR" -type f -name sign_update -perm -u+x | head -n 1)"
  [ -n "$found" ] || { echo "sign_update not in Sparkle $VERSION archive" >&2; exit 1; }
  BIN_DIR="$(cd "$(dirname "$found")" && pwd)"
fi
printf '%s\n' "$BIN_DIR"
