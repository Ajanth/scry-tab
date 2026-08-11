#!/usr/bin/env bash

set -euo pipefail

version="${1:-}"
version="${version#v}"
tag="v$version"
releaseRepo="Ajanth/scrytab-public"
appName="ScryTab"
bundleID="com.perpro.scry-tab"
teamID="8M242ZY4BY"
dmgName="$appName-$version.dmg"
zipName="$appName-$version.zip"
sourceName="$appName-$version-source.tar.gz"
expectedAssets=("$dmgName" "$zipName" "$sourceName")
workDir="$(mktemp -d)"
mountDir="$workDir/dmg"
mounted=false

cleanup() {
  if [[ $mounted == true ]]; then hdiutil detach "$mountDir" -quiet || true; fi
  rm -rf "$workDir"
}
trap cleanup EXIT

fail() {
  echo "Release verification failed: $*" >&2
  exit 1
}

[[ -n $version ]] || fail "usage: $0 <version>"
[[ $(gh release view "$tag" --repo "$releaseRepo" --json tagName --jq .tagName) == "$tag" ]] || fail "missing public tag $tag"
[[ $(gh release view "$tag" --repo "$releaseRepo" --json isDraft --jq .isDraft) == false ]] || fail "public release is a draft"
[[ $(gh release view "$tag" --repo "$releaseRepo" --json isPrerelease --jq .isPrerelease) == false ]] || fail "public release is a prerelease"
assetNames="$(gh release view "$tag" --repo "$releaseRepo" --json assets --jq '.assets[].name' | sort)"
sortedExpected="$(printf '%s\n' "${expectedAssets[@]}" | sort)"
[[ $assetNames == "$sortedExpected" ]] || fail "unexpected public assets: $assetNames"

gh release download "$tag" --repo "$releaseRepo" --dir "$workDir"
for asset in "${expectedAssets[@]}"; do
  expectedDigest="$(gh release view "$tag" --repo "$releaseRepo" --json assets --jq ".assets[] | select(.name == \"$asset\") | .digest")"
  actualDigest="sha256:$(shasum -a 256 "$workDir/$asset" | awk '{ print $1 }')"
  [[ -n $expectedDigest && $actualDigest == "$expectedDigest" ]] || fail "$asset digest mismatch"
done

sourceListing="$(tar -tzf "$workDir/$sourceName")"
for required in VERSION.txt src/App.swift LICENCE.md docs/third-party-notices.md vendor/Sparkle; do
  grep -Fq "$appName-$version/$required" <<< "$sourceListing" || fail "source archive missing $required"
done
for forbidden in .agents AGENTS.md config/local.xcconfig codesign.p12 scripts/notarytool; do
  if grep -Fq "$appName-$version/$forbidden" <<< "$sourceListing"; then fail "source archive contains $forbidden"; fi
done
[[ $(tar -xOzf "$workDir/$sourceName" "$appName-$version/VERSION.txt") == "$version" ]] || fail "source archive version mismatch"

mkdir "$workDir/zip"
ditto -x -k "$workDir/$zipName" "$workDir/zip"
zipApp="$workDir/zip/$appName.app"
codesign --verify --deep --strict --verbose=2 "$zipApp"
[[ $(codesign -dv --verbose=4 "$zipApp" 2>&1 | awk -F= '/^TeamIdentifier=/{ print $2 }') == "$teamID" ]] || fail "ZIP Team ID mismatch"
[[ $(plutil -extract CFBundleIdentifier raw -o - "$zipApp/Contents/Info.plist") == "$bundleID" ]] || fail "ZIP bundle ID mismatch"
spctl --assess --type execute --verbose "$zipApp"
xcrun stapler validate "$zipApp"

codesign --verify --verbose=2 "$workDir/$dmgName"
spctl --assess --type open --context context:primary-signature --verbose "$workDir/$dmgName"
xcrun stapler validate "$workDir/$dmgName"
mkdir "$mountDir"
hdiutil attach "$workDir/$dmgName" -mountpoint "$mountDir" -nobrowse -readonly -quiet
mounted=true
dmgApp="$mountDir/$appName.app"
codesign --verify --deep --strict --verbose=2 "$dmgApp"
[[ $(codesign -dv --verbose=4 "$dmgApp" 2>&1 | awk -F= '/^TeamIdentifier=/{ print $2 }') == "$teamID" ]] || fail "DMG Team ID mismatch"
[[ $(plutil -extract CFBundleIdentifier raw -o - "$dmgApp/Contents/Info.plist") == "$bundleID" ]] || fail "DMG bundle ID mismatch"
spctl --assess --type execute --verbose "$dmgApp"
xcrun stapler validate "$dmgApp"
hdiutil detach "$mountDir" -quiet
mounted=false

manifest="$(curl -fsSL "https://scrytab.pages.dev/release.json?release=$version")"
[[ $(plutil -extract version raw -o - - <<< "$manifest") == "$version" ]] || fail "live manifest version mismatch"
releaseRoot="https://github.com/$releaseRepo/releases/download/$tag"
[[ $(plutil -extract downloadUrl raw -o - - <<< "$manifest") == "$releaseRoot/$dmgName" ]] || fail "live DMG URL mismatch"
[[ $(plutil -extract sourceUrl raw -o - - <<< "$manifest") == "$releaseRoot/$sourceName" ]] || fail "live source URL mismatch"

appcast="$(curl -fsSL "https://scrytab.pages.dev/appcast.xml?release=$version")"
itemXPath="//*[local-name()='item'][.//*[local-name()='enclosure' and @*[local-name()='version' and .='$version']]]/*[local-name()='enclosure']"
appcastURL="$(xmllint --xpath "string($itemXPath/@url)" - <<< "$appcast")"
appcastLength="$(xmllint --xpath "string($itemXPath/@length)" - <<< "$appcast")"
appcastSignature="$(xmllint --xpath "string($itemXPath/@*[local-name()='edSignature'])" - <<< "$appcast")"
[[ $appcastURL == "$releaseRoot/$zipName" ]] || fail "live appcast URL mismatch"
[[ $appcastLength == "$(stat -f %z "$workDir/$zipName")" ]] || fail "live appcast enclosure length mismatch"
[[ -n $appcastSignature ]] || fail "live appcast lacks an EdDSA signature"

echo "Verified public ScryTab $version release, artifacts, signatures, source, manifest, and appcast."
