#!/usr/bin/env bash
# Idempotent Cloud Agent install. No servers, secrets, or production deploy.
set -euo pipefail

export PATH="${HOME}/flutter/bin:${HOME}/.local/bin:${PATH}"

FLUTTER_VERSION="3.38.10"
FLUTTER_HOME="${HOME}/flutter"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    return 0
  fi
  if [ -x "${FLUTTER_HOME}/bin/flutter" ]; then
    export PATH="${FLUTTER_HOME}/bin:${PATH}"
    return 0
  fi

  local archive="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  local url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${archive}"
  echo "Installing Flutter ${FLUTTER_VERSION} to ${FLUTTER_HOME}"
  curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors -o "/tmp/${archive}" "${url}"
  rm -rf "${FLUTTER_HOME}"
  tar -xJf "/tmp/${archive}" -C "${HOME}"
  rm -f "/tmp/${archive}"
  export PATH="${FLUTTER_HOME}/bin:${PATH}"
}

persist_path() {
  local line='export PATH="$HOME/flutter/bin:$HOME/.local/bin:$PATH"'
  local rc
  for rc in "${HOME}/.profile" "${HOME}/.bashrc"; do
    if [ -f "${rc}" ] && grep -Fqx "${line}" "${rc}"; then
      continue
    fi
    echo "${line}" >> "${rc}"
  done

  if [ -x "${FLUTTER_HOME}/bin/flutter" ]; then
    sudo ln -sfn "${FLUTTER_HOME}/bin/flutter" /usr/local/bin/flutter
    sudo ln -sfn "${FLUTTER_HOME}/bin/dart" /usr/local/bin/dart
  fi
}

ensure_flutter
persist_path

command -v flutter >/dev/null
command -v dart >/dev/null
flutter --version
flutter pub get --directory apps/player
python3 -m pip install --user -r services/cloud/requirements.txt
python3 -m pip install --user -r services/nas-agent/requirements-dev.txt
