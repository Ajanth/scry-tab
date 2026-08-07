#!/usr/bin/env bash

set -euo pipefail

: "${APPLE_P12_CERTIFICATE:?APPLE_P12_CERTIFICATE must be configured}"
: "${GITHUB_ENV:?GITHUB_ENV must be configured}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID must be configured}"
: "${RUNNER_TEMP:?RUNNER_TEMP must be configured}"

certificateFile="$RUNNER_TEMP/scry-tab-$GITHUB_RUN_ID.p12"
keychainName="scry-tab-ci-$GITHUB_RUN_ID.keychain"
keychainPath="$HOME/Library/Keychains/${keychainName}-db"
keychainPassword="$(openssl rand -hex 32)"
identityName="$(awk -F ' = ' '/^CODE_SIGN_IDENTITY/ { print $2; }' config/release.xcconfig)"

cleanupFailedSetup() {
  rm -f "$certificateFile"
  security delete-keychain "$keychainName" 2>/dev/null || true
}

trap cleanupFailedSetup ERR
printf '%s' "$APPLE_P12_CERTIFICATE" | base64 --decode > "$certificateFile"
chmod 600 "$certificateFile"
security delete-keychain "$keychainName" 2>/dev/null || true
security create-keychain -p "$keychainPassword" "$keychainName"
security set-keychain-settings -lut 7200 "$keychainName"
security unlock-keychain -p "$keychainPassword" "$keychainName"
security import "$certificateFile" -k "$keychainName" -P "" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychainPassword" "$keychainName"
security find-identity -v -p codesigning "$keychainName" | grep -F -- "$identityName" >/dev/null
searchList=("$keychainPath")
while IFS= read -r currentKeychain; do
  [[ "$currentKeychain" == "$keychainPath" ]] && continue
  searchList+=("$currentKeychain")
done < <(security list-keychains -d user | tr -d '"' | sed 's/^ *//')
security list-keychains -d user -s "${searchList[@]}"
rm -f "$certificateFile"
printf 'SCRYTAB_CI_KEYCHAIN=%s\n' "$keychainName" >> "$GITHUB_ENV"
trap - ERR
