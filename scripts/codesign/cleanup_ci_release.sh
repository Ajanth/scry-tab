#!/usr/bin/env bash

set -euo pipefail

if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
  echo "Refusing to clean signing material outside GitHub Actions" >&2
  exit 1
fi

if [[ -n "${SCRYTAB_CI_KEYCHAIN:-}" ]]; then
  keychainPath="$HOME/Library/Keychains/${SCRYTAB_CI_KEYCHAIN}-db"
  searchList=()
  while IFS= read -r currentKeychain; do
    [[ "$currentKeychain" == "$keychainPath" ]] && continue
    searchList+=("$currentKeychain")
  done < <(security list-keychains -d user | tr -d '"' | sed 's/^ *//')
  if [[ ${#searchList[@]} -gt 0 ]]; then security list-keychains -d user -s "${searchList[@]}"; fi
  security delete-keychain "$SCRYTAB_CI_KEYCHAIN" 2>/dev/null || true
fi

if [[ -n "${RUNNER_TEMP:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
  rm -f "$RUNNER_TEMP/scry-tab-$GITHUB_RUN_ID.p12"
fi
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  rm -f "$GITHUB_WORKSPACE/config/local.xcconfig"
fi
