#!/bin/sh
# Xcode Cloud: runs before each xcodebuild action.
# Fail archives that would ship without an Amplitude key:
# tag builds (App Store release) need AMPLITUDE_API_KEY_PROD,
# other archives (TestFlight internal testing) need AMPLITUDE_API_KEY_DEV.
set -eu

[ "${CI_XCODEBUILD_ACTION:-}" = "archive" ] || exit 0

if [ -n "${CI_TAG:-}" ]; then
    required_key="AMPLITUDE_API_KEY_PROD"
    required_value="${AMPLITUDE_API_KEY_PROD:-}"
else
    required_key="AMPLITUDE_API_KEY_DEV"
    required_value="${AMPLITUDE_API_KEY_DEV:-}"
fi

if [ -z "$required_value" ]; then
    echo "error: $required_key is not set for this archive (workflow: ${CI_WORKFLOW:-unknown}, tag: ${CI_TAG:-none})" >&2
    exit 1
fi

echo "Archive will use $required_key"
