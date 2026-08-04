#!/usr/bin/env bash

# Builds the Corresponding Source archive that GPL-3.0 §6(d) requires us to publish alongside
# every binary release. `git archive` exports the tracked tree at HEAD without any commit
# history, and untracked/ignored paths (codesign.p12, codesign.key, config/local.xcconfig,
# DerivedData, node_modules) are excluded by construction — never add them back.
#
# The archive must stay downloadable for as long as the matching binary is downloadable.

set -exu

version="$(cat "$VERSION_FILE")"
tarballName="$APP_NAME-$version-source.tar.gz"

git archive \
  --format=tar.gz \
  --prefix="$APP_NAME-$version/" \
  -o "$XCODE_BUILD_PATH/$tarballName" \
  HEAD

# fail loudly if the archive is missing anything needed to rebuild the binary
for required in \
  "$APP_NAME-$version/src/App.swift" \
  "$APP_NAME-$version/config/base.xcconfig" \
  "$APP_NAME-$version/scry-tab.xcodeproj/project.pbxproj" \
  "$APP_NAME-$version/vendor/Sparkle" \
  "$APP_NAME-$version/resources/l10n" \
  "$APP_NAME-$version/LICENCE.md"; do
  tar -tzf "$XCODE_BUILD_PATH/$tarballName" | grep -q "^$required" || {
    echo "Corresponding Source is incomplete: missing $required" >&2
    exit 1
  }
done

# a secret leaking into the published source archive is worse than a failed release
for forbidden in codesign.p12 codesign.key codesign.crt config/local.xcconfig; do
  if tar -tzf "$XCODE_BUILD_PATH/$tarballName" | grep -q "/$forbidden$"; then
    echo "Refusing to publish source archive containing $forbidden" >&2
    exit 1
  fi
done
