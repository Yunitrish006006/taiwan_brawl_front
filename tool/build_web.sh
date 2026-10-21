#!/usr/bin/env bash
set -euo pipefail

# Standalone Flutter Web build entrypoint.
# The backend deploy script may continue to use its integrated compatibility
# path, while frontend-only CI and hosting can call this script directly.

if [[ -n "${FLUTTER_BIN_DIR:-}" ]]; then
  FLUTTER_BIN_DIR="${FLUTTER_BIN_DIR}"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN_DIR="$(dirname "$(command -v flutter)")"
else
  FLUTTER_BIN_DIR="/Volumes/DataExtended/flutter/bin"
fi

if [[ ! -x "${FLUTTER_BIN_DIR}/flutter" ]]; then
  echo "Unable to locate Flutter SDK. Set FLUTTER_BIN_DIR." >&2
  exit 1
fi

flutter_args=(build web --release)
if [[ -n "${BUILD_NAME:-}" ]]; then
  flutter_args+=("--build-name=${BUILD_NAME}")
fi

add_define() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "${value}" ]]; then
    flutter_args+=("--dart-define=${name}=${value}")
  fi
}

for define_name in \
  API_BASE_URL \
  GOOGLE_WEB_CLIENT_ID \
  GOOGLE_SERVER_CLIENT_ID \
  P2P_CHAT_ENABLED \
  PEER_VERIFICATION_ENABLED \
  PREVIEW_MODE \
  ANDROID_BANNER_AD_UNIT_ID \
  IOS_BANNER_AD_UNIT_ID \
  ANDROID_INTERSTITIAL_AD_UNIT_ID \
  IOS_INTERSTITIAL_AD_UNIT_ID \
  DEFAULT_LLM_BASE_URL \
  DEFAULT_LLM_MODEL
do
  add_define "${define_name}"
done

echo "Building Flutter Web with ${FLUTTER_BIN_DIR}/flutter"
"${FLUTTER_BIN_DIR}/flutter" "${flutter_args[@]}"
