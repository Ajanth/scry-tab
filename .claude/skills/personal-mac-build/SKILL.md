---
name: personal-mac-build
description: Build and package ScryTab for personal use on another Mac without a paid Apple Developer account. Use when the user asks for a local, self-signed, non-notarized, no-App-Store, or transfer-ready ScryTab zip.
---

# /personal-mac-build

## Goal

Create a `ScryTab.zip` that can be copied to another personal Mac without using Developer ID notarization. This is for private testing only; public distribution still needs a paid Developer ID certificate and notarization.

## Workflow

1. Prepare the local self-signed signing identity once (re-run only if `codesign.p12` was deleted):
   ```sh
   scripts/codesign/setup_local.sh
   ```
   Debug builds use bundle id `com.perpro.scry-tab.local` and display name `ScryTab (Local)` so Accessibility permission does not collide with a release or older self-signed `com.perpro.scry-tab` entry in System Settings.

2. Build the Debug app through the repository wrapper:
   ```sh
   ai/build.sh
   ```

3. Package the built app with `ditto` so macOS bundle attributes are preserved:
   ```sh
   rm -f ScryTab.zip
   ditto -c -k --keepParent DerivedData/Build/Products/Debug/ScryTab.app ScryTab.zip
   ```

4. Verify the output before claiming it is ready:
   ```sh
   test -d DerivedData/Build/Products/Debug/ScryTab.app
   codesign --verify --deep --strict --verbose=2 DerivedData/Build/Products/Debug/ScryTab.app
   unzip -l ScryTab.zip >/dev/null
   ls -lh ScryTab.zip
   ```

## Using On Another Mac

Copy `ScryTab.zip` to the other Mac, unzip it, then clear quarantine if Gatekeeper blocks the app:

```sh
xattr -cr /path/to/ScryTab.app
```

In System Settings > Privacy & Security > Accessibility, enable **ScryTab (Local)** — not a plain **ScryTab** row left over from another build. If the list is confusing, reset the stale production entry and re-enable the local one:

```sh
tccutil reset Accessibility com.perpro.scry-tab
```

If this app later needs stable Keychain or permission continuity across machines, reuse the same self-signed signing certificate instead of regenerating one per Mac.
