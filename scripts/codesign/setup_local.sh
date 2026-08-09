#!/usr/bin/env bash

set -euo pipefail

certificateFile="codesign"
passwordDirectory="$HOME/Library/Application Support/ScryTab"
passwordFile="$passwordDirectory/local-signing-password"
regenerateCertificate=false

if [[ ! -s "$passwordFile" ]]; then
  umask 077
  mkdir -p "$passwordDirectory"
  openssl rand -base64 32 > "$passwordFile"
  regenerateCertificate=true
fi
chmod 700 "$passwordDirectory"
chmod 600 "$passwordFile"
certificatePassword="$(<"$passwordFile")"
if [[ -z $certificatePassword ]]; then
  echo "Local signing password is empty: $passwordFile" >&2
  exit 1
fi

if [[ ! -f "$certificateFile.p12" || $regenerateCertificate == true ]]; then
  scripts/codesign/generate_selfsigned_certificate.sh "$certificateFile" "$certificatePassword"
fi
chmod 600 "$certificateFile.p12"
if [[ -f "$certificateFile.key" ]]; then chmod 600 "$certificateFile.key"; fi
scripts/codesign/import_certificate_into_new_keychain.sh "$certificateFile" "$certificatePassword" "$certificatePassword"
