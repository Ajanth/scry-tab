# AccessibilitySettingsGuideTracking — Specs

## Summary

`AccessibilitySettingsGuideTracking.tick` decides what one 150ms tracking pulse should do
when System Settings is present or missing, before and after the overlay has been shown.
Miss thresholds allow Settings to launch (~6s) and end a session soon after Settings
disappears (~1.5s).

## Test scenarios

Mirrors `AccessibilitySettingsGuideTrackingTests.swift` 1:1.

### A. Settings present
- **testSettingsPresentTracksRegardlessOfMissesAndDidPresent** — settings present → trackSettings for any prior miss count and didPresent value.

### B. Absent, not yet presented
- **testAbsentNotPresentedBelowThresholdAwaits** — absent, not yet presented, below threshold → awaitSettings with incremented count.
- **testAbsentNotPresentedAtThresholdEndsSession** — absent, not yet presented, at threshold → endSession.

### C. Absent, already presented
- **testAbsentAlreadyPresentedBelowThresholdHidesOverlay** — absent, already presented, below threshold → hideOverlay with incremented count.
- **testAbsentAlreadyPresentedAtThresholdEndsSession** — absent, already presented, at threshold → endSession.
