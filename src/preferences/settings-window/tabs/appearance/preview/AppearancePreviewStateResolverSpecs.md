# AppearancePreviewStateResolver - Specs

## Summary

The settings preview owns its focus and playback decisions independently of live switcher sessions.
App Icons begins on its middle demo item, Titles begins on the first row, and Controls can either
pause every preview or run exactly one selected style.

## Test scenarios

- **testLightThemeAlwaysResolvesLight** - Light theme remains light regardless of the current system appearance.
- **testDarkThemeAlwaysResolvesDark** - Dark theme remains dark regardless of the current system appearance.
- **testSystemThemeFollowsSystemAppearance** - System theme follows both light and dark system appearance snapshots.
- **testAppearanceSnapshotUpdatesOneFieldAtATime** - Updating one appearance field preserves every other explicit settings snapshot.
- **testAppIconsStartsOnMiddleItem** - App Icons starts focused on the second demo item when it exists.
- **testTitlesStartsOnFirstItem** - Titles starts focused on the first demo row.
- **testEmptyPreviewUsesSafeFocus** - An empty preview resolves focus to zero without indexing an item.
- **testNoPlayingIndexPausesEveryPreview** - Controls initial binding pauses every style preview.
- **testPlayingIndexRunsOnlySelectedPreview** - Selecting a style runs only its matching preview.
- **testInvalidPlayingIndexPausesEveryPreview** - An out-of-range selection cannot accidentally start a preview.
- **testRightToLeftReversesStatusSymbolOrder** - Right-to-left previews reverse status symbol order to match mirrored geometry.
