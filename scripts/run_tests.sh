#!/usr/bin/env bash

set -ex

xcodebuild -version
xcodebuild -project scry-tab.xcodeproj -scheme Release -showBuildSettings | grep SWIFT_VERSION

set -o pipefail && xcodebuild test -project scry-tab.xcodeproj -scheme Test -configuration Release | scripts/xcbeautify
