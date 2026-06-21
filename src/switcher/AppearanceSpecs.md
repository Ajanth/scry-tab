# Appearance (window sizing) — Specs

> **Line coverage:** `AppearanceTestable.swift` 79% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

The switcher offers two appearance styles, both selectable from the top of the Appearance tab:

- **App Icons** — a center-aligned grid of large app icons.
- **Titles** — a left-aligned dense list of rows (app icon, title, status indicators).

There is no window-screenshot ("thumbnails") style and no selected-window preview overlay; the app never captures window screenshots and never requests Screen Recording.

`AppearanceTestable.comfortableWidth(physicalDimension)` is the one pure sizing function the suite pins: it returns the fraction of the screen the switcher should occupy, so the UI feels right from an 11" laptop to a 60" TV. Both styles use it to bound the panel width.

## Behavior & edge cases

- `comfortableWidth` clamps between 0.45 (biggest, ~60" screens) and 0.9 (Windows-11-style cap), using a 60 cm comfortable-viewing heuristic (`600 / physicalWidth`).
- When the screen's physical dimensions aren't reported, it falls back to the 0.9 default rather than the 0.45 floor — losing the data shouldn't shrink the panel.
- Bigger physical screens get a smaller comfortable fraction; ultrawides get distinct horizontal vs vertical fractions (the fixture table pins both).

## Test scenarios

Mirrors `AppearanceTests.swift` 1:1.

- **testComfortableWidth** — for every model in the 21-device fixture, the comfortable width fraction matches for both horizontal and vertical screen use.
- **testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil** — when the screen's physical dimensions aren't reported, fall back to the 0.9 default rather than the 0.45 floor.
