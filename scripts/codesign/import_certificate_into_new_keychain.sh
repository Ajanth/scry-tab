#!/usr/bin/env bash

set -euo pipefail

certificateFile="$1"
certificatePassword="$2"
keychainPassword="$3"

keychain="scry-tab.keychain"
keychainPath="$HOME/Library/Keychains/${keychain}-db"
loginKeychain="$HOME/Library/Keychains/login.keychain-db"
identityName="Scry Tab Local Self-Signed"

security delete-identity -c "$identityName" "$loginKeychain" 2>/dev/null || true

security delete-keychain "$keychain" 2>/dev/null || true
security create-keychain -p "$keychainPassword" "$keychain"
security unlock-keychain -p "$keychainPassword" "$keychain"
# disable auto-lock (no idle timeout, no lock-on-sleep) so codesign never triggers
# a Keychain unlock prompt during local Debug builds
security set-keychain-settings "$keychain"
security import "$certificateFile.p12" -k "$keychain" -P "$certificatePassword" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychainPassword" "$keychain"
security add-trusted-cert -d -r trustRoot -p codeSign -k "$keychain" "$certificateFile.crt"
searchList=("$keychainPath")
while IFS= read -r currentKeychain; do
  [[ "$currentKeychain" == "$keychainPath" ]] && continue
  searchList+=("$currentKeychain")
done < <(security list-keychains -d user | tr -d '"' | sed 's/^ *//')
security list-keychains -d user -s "${searchList[@]}"
security default-keychain -d user -s "$loginKeychain"
