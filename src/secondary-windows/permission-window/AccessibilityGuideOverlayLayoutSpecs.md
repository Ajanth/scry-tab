# AccessibilityGuideOverlayLayout — Specs

## Summary

`AccessibilityGuideOverlayLayout` parks the accessibility-permission guide panel **beside** the System
Settings window rather than on top of it, so the user can still reach the Accessibility list and toggle.
It prefers the window's trailing (right) edge with a constant gap — closer to the app list and toggles —
falls back to the leading edge when the trailing side has no room, and clamps the panel into the screen's
visibleFrame. Vertically it sits slightly above the window center (toward the list). The returned `edge`
tells the controller which way the guide arrow should point at the list (left when docked trailing, right
when docked leading).

## Test scenarios

Mirrors `AccessibilityGuideOverlayLayoutTests.swift` 1:1.

### A. Docking
- **testPrefersTrailingEdgeBesideSettings** — panel parks on the trailing edge with a gap, vertically biased above center, not intersecting the window.
- **testFallsBackToLeadingEdgeWhenTrailingBlocked** — no trailing room flips the panel to the leading edge, still clear of the window.
- **testClampsIntoVisibleFrameWhenNoEdgeFits** — no room on either side picks the roomier side and clamps inside the visible frame.
- **testClampsVerticallyIntoVisibleFrame** — a settings window near the screen's top keeps the panel on-screen vertically.
