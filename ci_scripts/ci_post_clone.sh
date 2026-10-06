#!/bin/sh
# Xcode Cloud: runs after the repository is cloned.
# Configs/Base.xcconfig includes Secrets.xcconfig, which is gitignored,
# so generate it from the workflow's (secret) environment variables.
set -eu

# Archives always use the Release configuration (AMPLITUDE_API_KEY_PROD).
# A workflow that defines only AMPLITUDE_API_KEY_DEV (TestFlight internal
# testing) archives with the dev key; the App Store workflow defines _PROD.
AMPLITUDE_API_KEY_DEV="${AMPLITUDE_API_KEY_DEV:-}"
AMPLITUDE_API_KEY_PROD="${AMPLITUDE_API_KEY_PROD:-$AMPLITUDE_API_KEY_DEV}"

secrets_file="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}/Configs/Secrets.xcconfig"

mkdir -p "$(dirname "$secrets_file")"
cat > "$secrets_file" <<XCCONFIG
AMPLITUDE_API_KEY_DEV = ${AMPLITUDE_API_KEY_DEV:-}
AMPLITUDE_API_KEY_PROD = ${AMPLITUDE_API_KEY_PROD:-}
XCCONFIG

echo "Generated $secrets_file"
