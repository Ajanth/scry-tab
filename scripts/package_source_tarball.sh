#!/usr/bin/env bash

# Builds the Corresponding Source archive that GPL-3.0 §6(d) requires us to publish alongside
# every binary release. `git archive` exports the tagged release tree without any commit
# history, and untracked/ignored paths (codesign.p12, codesign.key, config/local.xcconfig,
# DerivedData, node_modules) are excluded by construction — never add them back.
#
# The archive must stay downloadable for as long as the matching binary is downloadable.

set -euo pipefail

version="$(cat "$VERSION_FILE")"
tarballName="$APP_NAME-$version-source.tar.gz"
releaseRef="v$version"
releaseCommit="$(git rev-parse --verify "$releaseRef^{commit}")" || {
  echo "Corresponding Source release tag does not exist: $releaseRef" >&2
  exit 1
}
releaseVersion="$(git show "$releaseCommit:$VERSION_FILE")"
if [[ $releaseVersion != "$version" ]]; then
  echo "Corresponding Source version mismatch: $releaseRef contains $releaseVersion, expected $version" >&2
  exit 1
fi
if git grep -Eq 'keychainPassword="password"|local-dev-password' "$releaseCommit" -- scripts/codesign; then
  echo "Refusing to publish source archive containing a fixed local-signing password" >&2
  exit 1
fi

git archive \
  --format=tar.gz \
  --prefix="$APP_NAME-$version/" \
  -o "$XCODE_BUILD_PATH/$tarballName" \
  "$releaseCommit"

archiveListing="$(tar -tzf "$XCODE_BUILD_PATH/$tarballName")"
archiveVersion="$(tar -xOzf "$XCODE_BUILD_PATH/$tarballName" "$APP_NAME-$version/$VERSION_FILE")"
if [[ $archiveVersion != "$version" ]]; then
  echo "Corresponding Source archive version mismatch: found $archiveVersion, expected $version" >&2
  exit 1
fi

# fail loudly if the archive is missing anything needed to rebuild the binary
for required in \
  "$APP_NAME-$version/src/App.swift" \
  "$APP_NAME-$version/config/base.xcconfig" \
  "$APP_NAME-$version/scry-tab.xcodeproj/project.pbxproj" \
  "$APP_NAME-$version/vendor/Sparkle" \
  "$APP_NAME-$version/resources/l10n" \
  "$APP_NAME-$version/docs/third-party-notices.md" \
  "$APP_NAME-$version/LICENCE.md"; do
  grep -Fq "$required" <<< "$archiveListing" || {
    echo "Corresponding Source is incomplete: missing $required" >&2
    exit 1
  }
done

licenseText="$(tar -xOzf "$XCODE_BUILD_PATH/$tarballName" "$APP_NAME-$version/LICENCE.md")"
noticesText="$(tar -xOzf "$XCODE_BUILD_PATH/$tarballName" "$APP_NAME-$version/docs/third-party-notices.md")"
readmeText="$(tar -xOzf "$XCODE_BUILD_PATH/$tarballName" "$APP_NAME-$version/README.md")"
grep -Fq "GNU GENERAL PUBLIC LICENSE" <<< "$licenseText"
grep -Fq "ShortcutRecorder is licensed under the Creative Commons Attribution 4.0" <<< "$noticesText"
grep -Fq "Copyright (c) 2006-2013 Andy Matuschak." <<< "$noticesText"
grep -Fq "Copyright (c) 2015 Sentry" <<< "$noticesText"
grep -Fq "Copyright (c) 2025 Charles Pisciotta and other contributors" <<< "$noticesText"
grep -Fq "It retains portions derived from" <<< "$readmeText" || {
  echo "Corresponding Source README is missing the AltTab-derived portions notice" >&2
  exit 1
}
grep -Fq "Development of ScryTab began in 2026" <<< "$readmeText" || {
  echo "Corresponding Source README is missing the ScryTab development date" >&2
  exit 1
}

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
  docs/PUBLIC_REPOSITORY_MIGRATION.md \
  docs/luminare-appkit-ui-migration-plan.md \
  docs/appcenter-to-sentry-migration-plan.md \
  docs/pro-gating-restoration.md \
  mac-app-store-publishing.md \
  src/preferences/settings-window/tabs/appearance/AppearanceInspectorContext.md; do
  if grep -Fq "/$forbidden" <<< "$archiveListing"; then
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
