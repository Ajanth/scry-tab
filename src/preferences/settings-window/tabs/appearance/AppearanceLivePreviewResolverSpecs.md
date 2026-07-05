# AppearanceLivePreviewResolver - Specs

## Summary

The Appearance tab's style preview cycles the focus state across demo app tiles once per second
so the user can see how selection looks in the chosen style.
`AppearanceLivePreviewResolver` holds the two pure decisions behind that loop:
`nextFocusedIndex` picks which tile is highlighted next, and `shouldRun` decides whether the
loop should currently be advancing at all.

`shouldRun` combines four independent gates: the user's own manual pause/resume toggle, whether
the Settings window is actually visible, whether the real switcher panel is currently active
(so the decorative preview never competes with it for main-thread work), and whether the system
Reduce Motion accessibility setting is on. All four must be favorable for the loop to run.

Only pure decisions live here. Building the demo tiles, running the timer, updating the
highlight view, and observing window/accessibility notifications are AppKit glue outside this
resolver and are not covered by its tests.

## Test scenarios

### Cycling through tiles
- **testAdvancesOncePerSecond** - The preview holds each focused item for exactly one second.
- **testCyclesToNextIndex** - Advancing from a middle index moves to the next one.
- **testWrapsFromLastIndexToFirst** - Advancing from the last index wraps around to zero.
- **testHandlesSingleTile** - A single tile always advances to itself.
- **testHandlesZeroTilesWithoutCrashing** - Zero tiles resolves to index zero instead of dividing by zero.
- **testNormalizesOutOfRangeCurrentIndex** - An out-of-range current index (e.g. a style switch shrank the tile count) is normalized before advancing.

### Run/pause gating
- **testRunsWhenNothingBlocksIt** - All four conditions favorable resolves to running.
- **testManualPauseStopsIt** - A manual pause stops the loop regardless of the other conditions.
- **testHiddenWindowStopsIt** - A not-visible Settings window stops the loop.
- **testActiveSwitcherStopsIt** - An active switcher session stops the loop.
- **testReducedMotionStopsIt** - Reduce Motion stops the loop regardless of the other conditions.
