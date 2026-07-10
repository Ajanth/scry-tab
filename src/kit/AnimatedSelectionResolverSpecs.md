# AnimatedSelectionResolver - Specs

## Summary

`AnimatedSelectionResolver` is the reusable pure decision core behind any
`AnimatedSelectionContainerView` auto-cycling preview. `nextFocusedIndex` picks which item is
highlighted next, `shouldRun` decides whether the loop should currently be advancing, and
`scaleToFit` sizes reusable preview content within caller-supplied parent ratios.
`scaleToFit` never magnifies content that already fits; it only shrinks oversized content.

`shouldRun` combines four independent gates: a manual pause/resume toggle, whether the host
window is visible, whether the system Reduce Motion accessibility setting is on, and a
caller-supplied `shouldAdvance` gate for host-specific concerns (for example, not competing with
a live switcher panel). All four must be favorable for the loop to run.

Only pure decisions live here. Timer scheduling, pause state, building items, and updating the
selection view are AppKit glue outside this resolver and are not covered by its tests.

## Test scenarios

### Parent-relative sizing
- **testScaleToFitDoesNotUpscaleForWidth** - Content already inside the configured width share keeps its real size.
- **testScaleToFitDoesNotUpscaleForHeight** - Content already inside the configured height share keeps its real size.
- **testScaleToFitShrinksOversizedContent** - Oversized content shrinks to the tighter configured parent bound.
- **testScaleToFitHandlesEmptyContent** - Unlaid-out content keeps its neutral scale instead of producing an invalid transform.

### Cycling through items
- **testCyclesToNextIndex** - Advancing from a middle index moves to the next one.
- **testWrapsFromLastIndexToFirst** - Advancing from the last index wraps around to zero.
- **testHandlesSingleItem** - A single item always advances to itself.
- **testHandlesZeroItemsWithoutCrashing** - Zero items resolves to index zero instead of dividing by zero.
- **testNormalizesOutOfRangeCurrentIndex** - An out-of-range current index is normalized before advancing.

### Run/pause gating
- **testRunsWhenNothingBlocksIt** - All four conditions favorable resolves to running.
- **testManualPauseStopsIt** - A manual pause stops the loop regardless of the other conditions.
- **testHiddenWindowStopsIt** - A not-visible host window stops the loop.
- **testReducedMotionStopsIt** - Reduce Motion stops the loop regardless of the other conditions.
- **testShouldAdvanceFalseStopsIt** - A caller-supplied shouldAdvance gate of false stops the loop.
