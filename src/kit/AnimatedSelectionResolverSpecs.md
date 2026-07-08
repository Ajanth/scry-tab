# AnimatedSelectionResolver - Specs

## Summary

`AnimatedSelectionResolver` is the reusable pure decision core behind any
`AnimatedSelectionContainerView` auto-cycling preview. `nextFocusedIndex` picks which item is
highlighted next, and `shouldRun` decides whether the loop should currently be advancing.

`shouldRun` combines four independent gates: a manual pause/resume toggle, whether the host
window is visible, whether the system Reduce Motion accessibility setting is on, and a
caller-supplied `shouldAdvance` gate for host-specific concerns (for example, not competing with
a live switcher panel). All four must be favorable for the loop to run.

Only pure decisions live here. Timer scheduling, pause state, building items, and updating the
selection view are AppKit glue outside this resolver and are not covered by its tests.

## Test scenarios

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
