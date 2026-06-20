#!/bin/bash

xcodebuild \
  -project scry-tab.xcodeproj \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData
