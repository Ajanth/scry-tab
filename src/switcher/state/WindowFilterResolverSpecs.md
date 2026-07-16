# WindowFilterResolver — Specs

> **Line coverage:** `WindowFilterResolver.swift` 100% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

`WindowFilterResolver.shouldShow` decides whether a single window appears in the switcher for the
current shortcut. It's the per-window predicate behind `Windows.refreshIfWindowShouldBeShownToTheUser`,
extracted as a pure kernel. The caller passes the window's `WindowState`, the owning app's
`ApplicationState`, the per-shortcut dropdown booleans + the runtime context (frontmost pid, visible
space ids, exceptions list), and the default-true `matchesFocusSet` fact as labeled parameters with
`false` / `true` / `nil` / `[]` defaults — so each test spells out only the knob it exercises. The only
comparatively expensive fact — `isOnScreen` (multi-screen quartz / `Spaces.screenSpacesMap`) — is
passed as `@autoclosure` so the kernel evaluates it **only when the short-circuit reaches it** (a
phantom, exception-hidden, Focus Set-excluded, app-filtered, or windowless window never triggers an
`isOnScreen` computation). The other two derived facts (exception match, visible-space membership) are
pure expressions over the inputs, evaluated inline inside the same short-circuit chain so they're cheap
to keep eager. This makes the "why is/isn't this window showing?" logic — easily the most combinatorially
fiddly part of the app — fully unit-testable *without* losing the original boolean's laziness.

## Behavior & edge cases

The predicate, in order:

1. **Phantom** windows are always excluded (unconditional, first).
2. Windows matching a **hide-exception** (by bundle-id prefix + the exception's hide rule) are excluded.
3. **Focus Set membership**: a false `matchesFocusSet` fact excludes the row, whether it represents a
   real window or a windowless app. It defaults to `true`, preserving existing callers' behavior.
   Like the preferred-screen fact, it is lazy, so phantom and exception-hidden rows never evaluate
   membership.
4. **App scope** (`appsToShow`): `.active` keeps only the frontmost app's windows; `.nonActive` excludes them.
5. **Hidden apps** (⌘H): excluded when the "hide hidden" dropdown is set.
6. **Windowless apps** (placeholder rows for apps with no open window): shown unless hidden — and they
   **bypass** the window-only filters below (space/screen/fullscreen/minimized/tab), since those only
   make sense for real windows.
7. For **real windows**: also exclude fullscreen / minimized (when set), windows not in a visible space
   (`.visible`) or in a visible space (`.nonVisible`), windows off the preferred screen
   (`.showingScryTab`), and non-frontmost native **tabs**.

Precedence matters: `isPhantom` wins over everything (even a would-be-shown windowless row), and a
false Focus Set membership is a strict AND gate before app, windowless, and screen predicates.

## Test scenarios

Mirrors `WindowFilterResolverTests.swift` 1:1. Each test flips one knob from an all-permissive baseline.

### A. Defaults & always-excluded
- **testDefaultsShowARealWindow** — a plain visible window with no filters shows.
- **testPhantomIsHidden** — phantom → hidden.
- **testHiddenByExceptionIsHidden** — a hide-exception match → hidden.
- **testPhantomSkipsFocusSetEvaluation** — a phantom row bypasses membership evaluation.
- **testHiddenExceptionSkipsFocusSetEvaluation** — an exception-hidden row bypasses membership evaluation.

### B. Focus Set membership
- **testFocusSetDefaultsToMatching** — omitting membership preserves the matching default.
- **testNonMatchingFocusSetHidesRealWindow** — a false membership fact hides an otherwise valid real window.
- **testNonMatchingFocusSetHidesWindowlessRow** — a false membership fact hides an otherwise valid windowless row.
- **testNonMatchingFocusSetSkipsPreferredScreenEvaluation** — a false membership fact bypasses the lazy preferred-screen fact.

### C. App scope (`appsToShow`)
- **testOnlyFrontmostAppHidesNonFrontmost** — `.active` hides a non-frontmost app.
- **testOnlyFrontmostAppShowsFrontmost** — `.active` keeps the frontmost app.
- **testExcludeFrontmostAppHidesFrontmost** — `.nonActive` hides the frontmost app.
- **testExcludeFrontmostAppShowsNonFrontmost** — `.nonActive` keeps a non-frontmost app.

### D. Hidden apps
- **testHideHiddenHidesHiddenApp** — hidden app excluded when "hide hidden" is set.
- **testHiddenAppShownWhenNotHiding** — otherwise shown.

### E. Windowless apps
- **testWindowlessShownByDefault** — windowless row shows by default.
- **testHideWindowlessHidesIt** — hidden when "hide windowless" is set.
- **testWindowlessBypassesWindowOnlyFilters** — shows even under space/screen filters that would hide a real window.

### F. Fullscreen
- **testHideFullscreenHidesFullscreen** — fullscreen window is hidden when configured.
- **testFullscreenShownWhenNotHiding** — fullscreen window otherwise shows.

### G. Minimized
- **testHideMinimizedHidesMinimized** — minimized window is hidden when configured.
- **testMinimizedShownWhenNotHiding** — minimized window otherwise shows.

### H. Spaces
- **testOnlyVisibleSpacesHidesWindowNotInVisibleSpace** — `.visible` hides a window outside visible spaces.
- **testOnlyVisibleSpacesShowsWindowInVisibleSpace** — `.visible` keeps a window in a visible space.
- **testOnlyNonVisibleSpacesHidesWindowInVisibleSpace** — `.nonVisible` excludes windows in a visible space.

### I. Screens
- **testOnlyPreferredScreenHidesOffScreenWindow** — `.showingScryTab` hides an off-screen window.
- **testOnlyPreferredScreenShowsOnScreenWindow** — `.showingScryTab` keeps an on-screen window.

### J. Tabs (macOS native tabs)
- **testNonFrontmostTabIsHidden** — a non-frontmost tab is always hidden.

### K. Combinations
- **testAllFiltersOnAndWindowPassesEachShows** — every filter on, a window that satisfies all of them shows.
- **testPhantomBeatsWindowlessShow** — `isPhantom` overrides the windowless "show" path.
