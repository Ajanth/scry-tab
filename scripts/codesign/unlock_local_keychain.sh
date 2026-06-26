#!/usr/bin/env bash

# Local-dev only: make the self-signed Debug signing key usable by codesign
# without a Keychain unlock prompt. Safe to run before every build (idempotent,
# no-op if the keychain doesn't exist, e.g. on CI). Does NOT touch the login
# keychain.

set -u

keychain="scry-tab.keychain"
keychainPassword="password"
keychainPath="$HOME/Library/Keychains/${keychain}-db"

[[ -f "$keychainPath" ]] || exit 0

security unlock-keychain -p "$keychainPassword" "$keychain" 2>/dev/null || exit 0
# no idle timeout, no lock-on-sleep
security set-keychain-settings "$keychain" 2>/dev/null || true
# (re)grant non-interactive codesign access to the private key
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychainPassword" "$keychain" >/dev/null 2>&1 || true
