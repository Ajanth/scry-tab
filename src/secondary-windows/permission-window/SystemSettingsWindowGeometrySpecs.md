# SystemSettingsWindowGeometry — Specs

## Summary

`SystemSettingsWindowGeometry` converts CG window frames into AppKit coordinates using screen
descriptors, and decides whether a converted frame is large enough to treat as a System Settings
window. Selection prefers the screen with the largest CG-bounds intersection; when none intersect,
conversion still runs against the first (primary) descriptor.

## Test scenarios

Mirrors `SystemSettingsWindowGeometryTests.swift` 1:1.

### A. CG → AppKit conversion
- **testConvertsMatchingScreenWithYFlipped** — known CG frame on a matching screen flips Y into AppKit coords and keeps that screen’s visibleFrame.
- **testPicksLargestIntersectionScreen** — when multiple screens intersect, convert on the one with the largest intersection area.
- **testFallsBackToFirstScreenWhenNoneIntersect** — no intersection still converts via the first descriptor (not raw CG).
- **testReturnsZeroWhenScreensEmpty** — empty screens list → zero frame and visibleFrame.

### B. Eligibility
- **testEligibilityRejectsSmallFrames** — width ≤ 320 or height ≤ 240 → ineligible.
- **testEligibilityAcceptsLargeFrames** — width > 320 and height > 240 → eligible.
