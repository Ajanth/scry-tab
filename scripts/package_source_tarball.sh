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

archiveListing="$(tar -tzf "$XCODE_BUILD_PATH/$tarballName")"

# fail loudly if the archive is missing anything needed to rebuild the binary
for required in \
  "$APP_NAME-$version/src/App.swift" \
  "$APP_NAME-$version/config/base.xcconfig" \
  "$APP_NAME-$version/scry-tab.xcodeproj/project.pbxproj" \
  "$APP_NAME-$version/vendor/Sparkle" \
  "$APP_NAME-$version/resources/l10n" \
  "$APP_NAME-$version/LICENCE.md"; do
  printf '%s\n' "$archiveListing" | grep -Fq "$required" || {
    echo "Corresponding Source is incomplete: missing $required" >&2
    exit 1
  }
done

# private release operations, local tooling, and Apple software are not Corresponding Source
for forbidden in \
  codesign.p12 \
  codesign.key \
  codesign.crt \
  config/local.xcconfig \
  scripts/notarytool \
  .agents \
  .cursor \
  .vscode \
  AGENTS.md \
  CLAUDE.md \
  docs/RELEASE_BLOCKERS.md \
  docs/luminare-appkit-ui-migration-plan.md \
  docs/appcenter-to-sentry-migration-plan.md \
  docs/pro-gating-restoration.md \
  mac-app-store-publishing.md \
  src/preferences/settings-window/tabs/appearance/AppearanceInspectorContext.md; do
  if printf '%s\n' "$archiveListing" | grep -Fq "/$forbidden"; then
    echo "Refusing to publish source archive containing $forbidden" >&2
    exit 1
  fi
done

usersRoot="/Users"
personalPaths="$(tar -xOzf "$XCODE_BUILD_PATH/$tarballName" |
  LC_ALL=C grep -aEo "$usersRoot/[^/[:space:]]+/" |
  sort -u |
  grep -Ev "^$usersRoot/(test|other|runner)/$" || true)"
if [[ -n $personalPaths ]]; then
  echo "Refusing to publish source archive containing personal absolute paths:" >&2
  echo "$personalPaths" >&2
  exit 1
fi
