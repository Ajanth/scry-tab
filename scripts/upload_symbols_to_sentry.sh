#!/usr/bin/env bash

set -euo pipefail

: "${SENTRY_AUTH_TOKEN:?SENTRY_AUTH_TOKEN must be configured}"
: "${SENTRY_ORG:?SENTRY_ORG must be configured}"
: "${SENTRY_PROJECT:?SENTRY_PROJECT must be configured}"

dsyms=()
while IFS= read -r -d '' dsym; do
  dsyms+=("$dsym")
done < <(find "$XCODE_BUILD_PATH" -type d -name '*.dSYM' -print0)
if [[ ${#dsyms[@]} -eq 0 ]]; then
  echo "No dSYM bundles found in $XCODE_BUILD_PATH" >&2
  exit 1
fi

npx --no-install sentry-cli debug-files upload "${dsyms[@]}"
