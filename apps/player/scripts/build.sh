#!/usr/bin/env bash
set -euo pipefail

# Navidrome Player — Build Script
# Usage: ./scripts/build.sh <platform>
# Platforms: android | ios | macos | windows | all | clean

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
VERSIONS_FILE="$SCRIPT_DIR/versions.env"

APP_NAME="navidrome_player"

# Load platform versions from versions.env
[ -f "$VERSIONS_FILE" ] || { echo "ERROR: $VERSIONS_FILE not found" >&2; exit 1; }
source "$VERSIONS_FILE"

log()  { echo "==> $*"; }
err()  { echo "ERROR: $*" >&2; exit 1; }

sign_item() {
  local identity="$1"
  local path="$2"
  shift 2
  [ -e "$path" ] || return 0
  codesign --force --options runtime --timestamp --sign "$identity" "$@" "$path"
}

sign_sparkle_framework() {
  local identity="$1"
  local sparkle="$2"
  [ -d "$sparkle" ] || return 0
  local version_dir="$sparkle/Versions/B"
  [ -d "$version_dir" ] || version_dir="$sparkle/Versions/Current"
  sign_item "$identity" "$version_dir/XPCServices/Installer.xpc"
  if [ -d "$version_dir/XPCServices/Downloader.xpc" ]; then
    sign_item "$identity" "$version_dir/XPCServices/Downloader.xpc" \
      --preserve-metadata=entitlements
  fi
  sign_item "$identity" "$version_dir/Autoupdate"
  sign_item "$identity" "$version_dir/Updater.app"
  sign_item "$identity" "$sparkle"
}

sign_macos_app() {
  local app_path="$1"
  local identity="$2"
  local entitlements="$3"
  local fw
  sign_sparkle_framework "$identity" "$app_path/Contents/Frameworks/Sparkle.framework"
  if [ -d "$app_path/Contents/Frameworks" ]; then
    for fw in "$app_path/Contents/Frameworks"/*.framework; do
      [ -d "$fw" ] || continue
      case "$(basename "$fw")" in
        Sparkle.framework) continue ;;
      esac
      sign_item "$identity" "$fw"
    done
  fi
  sign_item "$identity" "$app_path" --entitlements "$entitlements"
}

ensure_flutter() {
  command -v flutter >/dev/null 2>&1 || err "flutter not found in PATH"
  log "Flutter $(flutter --version --machine 2>/dev/null | grep -o '"frameworkVersion":"[^"]*"' | cut -d'"' -f4 || echo 'unknown')"
}

build_android() {
  local ver="$ANDROID_VERSION" build="$ANDROID_BUILD"
  log "Building Android APK (v${ver}+${build})..."
  cd "$PROJECT_ROOT"
  flutter build apk --release --build-name="$ver" --build-number="$build"
  local src="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
  [ -f "$src" ] || err "APK not found at $src"
  cp "$src" "$DIST_DIR/${APP_NAME}-${ver}+${build}-android.apk"
  log "Android APK -> dist/${APP_NAME}-${ver}+${build}-android.apk"
}

build_ios() {
  local ver="$IOS_VERSION" build="$IOS_BUILD"
  log "Building iOS IPA (v${ver}+${build})..."
  [[ "$(uname)" == "Darwin" ]] || err "iOS builds require macOS"
  cd "$PROJECT_ROOT"
  flutter build ipa --release --no-codesign --build-name="$ver" --build-number="$build"
  local src
  src=$(find "$PROJECT_ROOT/build/ios/archive" -name "*.xcarchive" -print -quit 2>/dev/null || true)
  if [ -n "$src" ]; then
    cp -R "$src" "$DIST_DIR/${APP_NAME}-${ver}+${build}-ios.xcarchive"
    log "iOS archive -> dist/${APP_NAME}-${ver}+${build}-ios.xcarchive"
  else
    log "iOS build completed (check build/ios/ for output)"
  fi
}

build_macos() {
  local ver="$MACOS_VERSION" build="$MACOS_BUILD"
  log "Building macOS app (v${ver}+${build})..."
  [[ "$(uname)" == "Darwin" ]] || err "macOS builds require macOS"
  cd "$PROJECT_ROOT"
  flutter build macos --release --build-name="$ver" --build-number="$build"
  local app_path
  app_path="$(find "$PROJECT_ROOT/build/macos/Build/Products/Release" -maxdepth 1 -name '*.app' -print -quit)"
  [ -n "$app_path" ] && [ -d "$app_path" ] || err "macOS app not found in build/macos/Build/Products/Release/"
  # Sign with Developer ID. Do not use --deep: it breaks Sparkle XPC services.
  local identity="${MACOS_CODESIGN_IDENTITY:-Developer ID Application: Topping Technology Co., Ltd (M336Q22BHF)}"
  local entitlements="$PROJECT_ROOT/macos/Runner/Release.entitlements"
  log "Codesigning macOS app with: $identity"
  sign_macos_app "$app_path" "$identity" "$entitlements"
  codesign --verify --strict "$app_path" || err "codesign verify failed"
  # Create DMG for distribution
  local dmg_name="${APP_NAME}-${ver}+${build}-macos.dmg"
  local tmp_dmg="$DIST_DIR/${dmg_name}.tmp"
  local staging="$PROJECT_ROOT/build/macos-dmg-staging"
  rm -rf "$staging" "$tmp_dmg"
  mkdir -p "$staging"
  cp -R "$app_path" "$staging/"
  ln -s /Applications "$staging/Applications"
  hdiutil create -volname "音跃" -srcfolder "$staging" -ov -format UDZO "$DIST_DIR/$dmg_name"
  rm -rf "$staging"
  codesign --force --timestamp --sign "$identity" "$DIST_DIR/$dmg_name"
  codesign --verify --strict "$DIST_DIR/$dmg_name" || err "DMG codesign verify failed"
  # Avoid carrying Finder quarantine into installs from this host.
  xattr -cr "$DIST_DIR/$dmg_name" 2>/dev/null || true
  # Self-use: quit running app so dragging/replacing /Applications/音跃.app works.
  osascript -e 'tell application "音跃" to quit' >/dev/null 2>&1 || true
  sleep 1
  killall "音跃" >/dev/null 2>&1 || true
  log "macOS DMG -> dist/$dmg_name"
}

build_windows() {
  local ver="$WINDOWS_VERSION" build="$WINDOWS_BUILD"
  log "Building Windows executable (v${ver}+${build})..."
  cd "$PROJECT_ROOT"
  flutter build windows --release --build-name="$ver" --build-number="$build"
  local win_dir="$PROJECT_ROOT/build/windows/x64/runner/Release"
  [ -d "$win_dir" ] || win_dir="$PROJECT_ROOT/build/windows/runner/Release"
  [ -d "$win_dir" ] || err "Windows build output not found"
  (cd "$win_dir" && zip -r -q "$DIST_DIR/${APP_NAME}-${ver}+${build}-windows.zip" .)
  log "Windows app -> dist/${APP_NAME}-${ver}+${build}-windows.zip"
}

do_clean() {
  log "Cleaning..."
  cd "$PROJECT_ROOT"
  flutter clean
  rm -rf "$DIST_DIR"/*
  log "Clean complete"
}

# --- Main ---
mkdir -p "$DIST_DIR"
ensure_flutter

PLATFORM="${1:-}"
[ -n "$PLATFORM" ] || err "Usage: $0 <android|ios|macos|windows|all|clean>"

case "$PLATFORM" in
  android) build_android ;;
  ios)     build_ios ;;
  macos)   build_macos ;;
  windows) build_windows ;;
  all)
    build_android
    [[ "$(uname)" == "Darwin" ]] && build_ios
    [[ "$(uname)" == "Darwin" ]] && build_macos
    build_windows
    ;;
  clean)   do_clean ;;
  *)       err "Unknown platform: $PLATFORM. Use android|ios|macos|windows|all|clean" ;;
esac

log "Done! Artifacts in $DIST_DIR/"
ls -lh "$DIST_DIR/" 2>/dev/null || true
