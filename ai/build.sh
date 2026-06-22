#!/bin/bash

# ensure the local self-signed signing key is unlocked (no Keychain prompt)
"$(dirname "$0")/../scripts/codesign/unlock_local_keychain.sh"

xcodebuild \
  -project scry-tab.xcodeproj \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData
