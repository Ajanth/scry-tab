#!/usr/bin/env bash

# Produces two artifacts from one build:
#   * $APP_NAME-$version.zip - what Sparkle downloads for in-place updates
#   * $APP_NAME-$version.dmg - what the website links to, so a first-time user gets the
#     familiar drag-to-Applications install instead of an app left running in ~/Downloads
#
# Both are notarized and stapled. Stapling matters most for the DMG: a first launch on a fresh
# machine is often offline-hostile (corporate proxies, captive wifi), and a stapled ticket lets
# Gatekeeper approve without reaching Apple.

set -euo pipefail

version="$(cat "$VERSION_FILE")"
appFile="$APP_NAME.app"
zipName="$APP_NAME-$version.zip"
dmgName="$APP_NAME-$version.dmg"
dmgStaging="dmg-staging"
signingIdentity="$(awk -F ' = ' '/^CODE_SIGN_IDENTITY/ { print $2; }' < config/release.xcconfig)"
notarize() {
  local artifact="$1"
  local requestStatus
  requestStatus=$(xcrun notarytool submit \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    "$artifact" \
    --wait --timeout 45m 2>&1 |
    tee /dev/stderr |
    awk -F ': ' '/  status:/ { print $2; }')
  if [[ $requestStatus != "Accepted" ]]; then exit 1; fi
}

cd "$XCODE_BUILD_PATH"

legalResources="$appFile/Contents/Resources"
for required in "$legalResources/LICENCE.md" "$legalResources/acknowledgments.md" "$legalResources/contributors.md" "$legalResources/third-party-notices.md"; do
  if [[ ! -f $required ]]; then
    echo "Refusing to package an app without legal resource: $required" >&2
    exit 1
  fi
done
grep -Fq "GNU GENERAL PUBLIC LICENSE" "$legalResources/LICENCE.md"
grep -Fq "## Built AltTab" "$legalResources/contributors.md"
grep -Fq "ShortcutRecorder is licensed under the Creative Commons Attribution 4.0" "$legalResources/third-party-notices.md"
grep -Fq "Copyright (c) 2006-2013 Andy Matuschak." "$legalResources/third-party-notices.md"
grep -Fq "Copyright (c) 2015 Sentry" "$legalResources/third-party-notices.md"
grep -Fq "Copyright (c) 2025 Charles Pisciotta and other contributors" "$legalResources/third-party-notices.md"

# notarize the app itself, via a zip as the transport, then staple the ticket into the bundle
ditto -c -k --keepParent "$appFile" "$zipName"
notarize "$zipName"
xcrun stapler staple "$appFile"

# re-zip so Sparkle ships the stapled bundle rather than the pre-notarization one
ditto -c -k --keepParent "$appFile" "$zipName"

# build the DMG from the already-stapled bundle so the installed copy carries its ticket
rm -rf "$dmgStaging"
mkdir -p "$dmgStaging"
ditto "$appFile" "$dmgStaging/$appFile"
ln -s /Applications "$dmgStaging/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$dmgStaging" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$dmgName"
rm -rf "$dmgStaging"

# an unsigned DMG triggers a Gatekeeper prompt of its own, before the app is ever opened
codesign --force --sign "$signingIdentity" --timestamp "$dmgName"
notarize "$dmgName"
xcrun stapler staple "$dmgName"

# refuse to ship anything Gatekeeper would reject on a user's machine
spctl --assess --type execute --verbose "$appFile"
xcrun stapler validate "$appFile"
xcrun stapler validate "$dmgName"
