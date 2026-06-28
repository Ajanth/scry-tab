#!/usr/bin/env bash

set -exu

certificateFile="codesign"
certificatePassword="${SCRYTAB_LOCAL_CODESIGN_PASSWORD:-local-dev-password}"

if [[ ! -f "$certificateFile.p12" ]]; then
  scripts/codesign/generate_selfsigned_certificate.sh "$certificateFile" "$certificatePassword"
fi
scripts/codesign/import_certificate_into_new_keychain.sh "$certificateFile" "$certificatePassword"
