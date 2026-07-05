---
name: personal-mac-build
description: Build and package this project's macOS app for personal use on another Mac without a paid Apple Developer account. Use for a local, self-signed, non-notarized, no-App-Store, or transfer-ready archive.
---

# Personal Mac Build

Create a self-signed Debug archive for private testing. Public distribution still requires Developer ID signing and notarization.

## Build and Package

1. Run `scripts/codesign/setup_local.sh` when the local signing identity or keychain is missing or invalid. The Debug bundle identifier and display name are defined in `config/debug.xcconfig`.
2. Inspect `ai/build.sh`, copy its complete non-comment command sequence, resolve script-relative paths against `ai/build.sh`, and run the commands directly in order.
3. Locate, package, and verify the single Debug app:

```bash
(
set -euo pipefail
shopt -s nullglob
apps=(DerivedData/Build/Products/Debug/*.app)
if (( ${#apps[@]} != 1 )); then
  printf 'Expected one Debug app, found %d\n' "${#apps[@]}" >&2
  exit 1
fi
app_path="${apps[0]}"
archive="$(basename "$app_path" .app).zip"
codesign --verify --deep --strict --verbose=2 "$app_path"
rm -f "$archive"
ditto -c -k --keepParent "$app_path" "$archive"
unzip -l "$archive" >/dev/null
ls -lh "$archive"
)
```

## Use on Another Mac

- Copy and unpack the reported archive.
- If Gatekeeper blocks the app, use Finder's **Control-click > Open** or **Privacy & Security > Open Anyway**.
- Enable the Debug display-name row under **System Settings > Privacy & Security > Accessibility**. Remove stale rows there manually; do not reset the production app's Accessibility grant.
- Reuse the same self-signed certificate and keep the Debug bundle identifier stable when permission or Keychain continuity must survive rebuilds or migrations.
