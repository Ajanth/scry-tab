#!/usr/bin/env bash

set -ex

set -o pipefail && xcodebuild -project scry-tab.xcodeproj -scheme Release -derivedDataPath DerivedData | scripts/xcbeautify
file "$BUILD_DIR/$XCODE_BUILD_PATH/$APP_NAME.app/Contents/MacOS/$APP_NAME"
