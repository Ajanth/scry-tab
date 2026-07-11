# Focus Sets: Top-Level Presentation Decoupling

## Status and scope

This is the canonical plan for the remaining Focus Sets architecture and Settings information
architecture work. It supersedes the shortcut-profile decisions in
[`../FocusSetsPlan.md`](../FocusSetsPlan.md), while retaining that document's completed
membership, picker, persistence, and child-grid foundations.

The goal is not to add per-set appearance or filter configuration. It is to make Focus Sets a
first-class saved-app feature whose launch shortcut is an input, not its hidden presentation owner.

## Problem

The current configuration persists `presentationShortcutIdentifier`, then uses its resolved
numbered shortcut index for Focus Sets counts and child grids:

- `FocusSetPresentationSnapshotBuilder.swift` builds profile-filtered candidate counts.
- `App.updateFocusSetSession` copies that profile index into `SwitcherSession.shortcutIndex`.
- `WindowFilters`, `Appearance`, ordering, grouping, search/release behavior, key repeat, and
  several tile views subsequently read that index.

Consequently, a user-visible **Focus Sets profile** control appears to select only filters but
also changes unrelated presentation and keyboard behavior. A matching app can also disappear
because an unrelated numbered shortcut is restricted to a Space or screen. Screen-scoped profile
counts additionally require eager per-window screen work before the picker is shown.

## Product contract

### Ownership

- A **Focus Set** owns saved application membership and an optional direct shortcut.
- A **shortcut** owns its key binding and ordinary-switcher hold/release behavior.
- **Focus Sets** own their picker/direct-invocation semantics and never inherit a numbered shortcut
  profile.
- Shared presentation owns standard appearance, ordering, and grouping. Focus Sets may consume
  those defaults but may not duplicate their controls or select a numbered shortcut as a proxy.

### Focus Sets visibility

The Focus Sets child grid is always:

```text
normal safety exclusions AND Focus Set membership AND Focus Sets visibility policy
```

The policy is explicit:

- all applications, all Spaces, and all screens;
- normal phantom-window and exception handling remain in force;
- default normal handling for hidden, minimized, fullscreen, and windowless rows remains explicit
  in one policy, never inherited from a shortcut;
- membership continues to be exact app-bundle membership for `.set`, its inverse for
  `.unassigned`, and unrestricted for `.allWindows`.

Do not implement this by using shortcut index `0`, by copying a shortcut's current values, or by
passing an empty `FocusSetCandidateFilters` value that would bypass exceptions.

### Shared presentation

- Appearance uses the existing app-wide base values:
  `Preferences.appearanceStyle`, `appearanceSize`, and `appearanceTheme`, never a numbered
  shortcut override.
- Add feature-neutral shared defaults for window ordering and app/tab grouping. Their initial
  values match the current normal defaults; Focus Sets reads them through a typed resolver.
- Numbered shortcut behavior remains unchanged. Existing per-shortcut ordering/grouping values
  become explicit overrides over the new shared defaults, rather than silently changing a user’s
  established shortcut behavior.
- The Focus Sets Settings page explains that it uses standard appearance, ordering, and grouping,
  and links to the shared controls. It does not reproduce those controls.

### Invocation

- **Open Focus Sets** opens or refreshes the picker on key down and never focuses a window on key
  release.
- A direct Focus Set shortcut opens/cycles its set using Focus Sets behavior, not
  `focusOnRelease` or `searchOnRelease` from a numbered profile.
- Existing numbered shortcuts and gestures retain their current profile-specific behavior.
- Existing picker/direct-grid lifecycle and repeat-cycling behavior remain; only the presentation
  source changes.

## Target design

### Presentation source must be explicit

Introduce a small runtime abstraction, for example `SwitcherPresentationSource` and
`SwitcherPresentation`, rather than letting focus-session code mutate `shortcutIndex`.

```text
ordinary shortcut / gesture  -> .shortcut(index)
Focus Sets picker/direct grid -> .focusSets
```

The source resolves all behavior needed by a live grid:

- visibility snapshot used by `WindowFilterResolver`;
- app/tab grouping and window order used by `Windows`;
- appearance style, size, and theme used by `Appearance` and tile/panel code;
- release/search/key-repeat semantics used by `App`, `ATShortcut`, `KeyboardEventsTestable`,
  `KeyRepeatTimer`, and `TrackpadEvents`.

`SwitcherSession.shortcutIndex` remains meaningful only for `.shortcut`. A Focus Sets session must
not carry a disguised profile index. Prefer a session-owned immutable presentation snapshot at
entry/rebuild boundaries so per-window loops do not read preferences repeatedly.

### One filter implementation

Keep `WindowFilterResolver` as the sole predicate. Add a Focus Sets policy snapshot that supplies
the normal predicate’s facts, then pass `matchesFocusSet` exactly as today. Picker counts in
`FocusSetCandidateCounter` and visible child-grid windows must resolve from the same policy.

For the all-screens policy, `FocusSetPresentationSnapshotBuilder` must not eagerly call
`Window.isOnScreen` while creating picker candidates. This removes the profile-screen path without
claiming to remove all count work; counting is still synchronous work proportional to open windows
and picker scopes.

### Persistence and compatibility

`FocusSetsConfiguration` advances to version 3 and no longer exposes
`presentationShortcutIdentifier`.

- The tolerant parser accepts V1/V2 JSON containing the retired field and ignores it.
- The next normalized read/write removes that known retired field while preserving all unrelated
  unknown root, set, and rule fields.
- Remove profile rebinding and the `availableShortcutIdentifiers` parameter from `FocusSetsStore`.
- Direct-set shortcut data and saved membership remain untouched.

For shared ordering/grouping defaults, add a preference migration before changing effective
readers:

1. Capture each legacy numbered shortcut’s effective order and grouping.
2. Seed the new shared defaults from shortcut 1’s effective values.
3. Persist an explicit per-shortcut override wherever that shortcut differs from the new shared
   default.
4. Make the new effective readers use a persisted override when present and the shared default
   otherwise.

This preserves every ordinary shortcut while giving Focus Sets a real, non-shortcut default source.

## Implementation chunks

### 1. Establish shared presentation defaults

**Files:** `Preferences.swift`, `PreferencesMigrations.swift`,
`PreferencesMigrationsTests.swift`, `MacroPreferences.swift`, the ordering/grouping Controls
editor and its specs/tests.

1. Add typed shared defaults for order, app grouping, and tab grouping; use the existing base
   Appearance preferences for appearance.
2. Add effective readers that distinguish a persisted numbered-shortcut override from a registered
   default.
3. Migrate legacy values with the preservation algorithm above.
4. Keep ordinary shortcut UI and runtime behavior stable; expose the shared defaults once in the
   appropriate existing Appearance/Controls surface rather than in every Focus Set.

**Exit criteria:** existing shortcuts render and sort exactly as before; a unit test proves
different legacy shortcut settings survive the migration.

### 2. Add a pure Focus Sets policy and retire profile persistence

**Files:** `FocusSet.swift`, `FocusSetsStore.swift`,
`FocusSetsStoreSpecs.md`, `FocusSetsStoreTests.swift`,
`FocusSetPresentationSnapshotBuilder.swift`, `FocusSetPickerResolver.swift`,
`FocusSetCandidateCounter.swift`, and their co-located specs/tests.

1. Add a Foundation-only `FocusSetsPresentationPolicy`/resolver with explicit visibility and
   presentation facts.
2. Bump the Focus Sets configuration version, remove the profile field, and implement tolerant
   V1/V2 migration without dropping unknown JSON fields.
3. Remove profile-index construction from `FocusSetPresentationSnapshotBuilder`; build candidate
   counts from the Focus Sets policy.
4. Update count specs from “profile-scoped” to the explicit Focus Sets policy and test
   picker-count/child-grid parity.

**Exit criteria:** no Focus Sets model, store, or snapshot builder reads a shortcut identifier or
index; all-screens counts do not materialize preferred-screen facts.

### 3. Switch the live Focus Sets flow to its own presentation source

**Files:** `SwitcherSession.swift`, `App.swift`, `Windows.swift`,
`WindowFilterResolver.swift`, `Appearance.swift`, `TilesPanel.swift`, `TilesView.swift`,
`TileView.swift`, `WindowlessAppIndicator.swift`, `ATShortcut.swift`, `KeyRepeatTimer.swift`,
`KeyboardEventsTestable.swift`, `TrackpadEvents.swift`, plus focused specs/tests.

1. Store an explicit presentation source/snapshot in `SwitcherSession`; stop assigning
   `session.shortcutIndex` in `App.updateFocusSetSession`.
2. Resolve Focus Sets visibility through `WindowFilters` and `WindowFilterResolver` while
   retaining exceptions and membership short-circuiting.
3. Route appearance, sorting, grouping, selection initialization, key repeat, and direct-key
   release behavior through the presentation source.
4. Make picker and direct-set entries use `.focusSets`; retain `.shortcut(index)` only for ordinary
   shortcut/gesture sessions.
5. Delete the profile-specific release/search branches for direct Focus Set shortcuts.

**Exit criteria:** no path reached from `.focusSetGrid` or `.directFocusSetGrid` depends on a
numbered profile; ordinary sessions retain their current behavior byte-for-byte at the decision
level.

### 4. Promote Focus Sets to a top-level Settings page

**Files:** `SettingsRoute.swift`, `SettingsRouteTests.swift`, `SettingsWindow.swift`,
`ControlsTab.swift`, `FocusSetSettingsView.swift`, a new
`tabs/focus-sets/FocusSetsTab.swift` (and triad where deterministic routing is extracted), plus
localization resources.

1. Add `.focusSets` as a `SettingsTopLevelPage` and `SettingsRoute`; place it beside Controls in
   the Settings sidebar using the existing page-icon and material system.
2. Move `FocusSetSettingsView` construction, search registration, route selection, and lifecycle
   ownership from Controls’ Advanced segment into `FocusSetsTab`.
3. Remove `ControlsDestination.focusSets`, its Advanced segment/state, and stale route/search
   descriptors. Normalize legacy in-memory `.controls(.focusSets)` navigation to `.focusSets`.
4. Keep hotkey registry ownership in `ControlsTab` if needed, but move the Open Focus Sets recorder
   and all Focus Set configuration UI to the new page.
5. Remove the profile popup and replace it with concise localized policy text plus links to shared
   presentation controls.

**Exit criteria:** sidebar navigation, Settings search, dynamic refresh, accessibility focus, and
shortcut conflict handling work with Focus Sets open as its own page; no feature-local Settings
chrome is introduced.

### 5. Remove stale contracts and verify end to end

**Files:** `src/switcher/FocusSetsPlan.md`, `focus-sets/AGENTS.md`, all changed
`*Specs.md`/`*Tests.swift`, and `src/coverage.md` only if coverage is intentionally refreshed.

1. Replace every remaining “Focus Sets profile”/`presentationShortcutIdentifier` contract,
   searchable string, test scenario, and migration assertion.
2. Update the local Focus Sets agent map so it states policy plus membership, not profile plus
   membership.
3. Run the spec/test triad audit after every changed triad.
4. Run focused migration, policy, window-filter, session, route, and shortcut tests; then run the
   complete `Test` scheme and the exact commands from `ai/build.sh`.
5. Manually verify the Focus Sets page and picker in light/dark appearance, keyboard-only use,
   VoiceOver, a multi-Space/multi-screen setup, direct-set shortcut release, and a normal
   profile-specific shortcut.
6. Run `graphify update .`, `git diff --check`, and inspect that ordinary shortcuts did not change.

## Non-goals

- No per-Focus-Set profile, per-set appearance, per-set ordering, or per-set Space/screen setting.
- No fallback to shortcut 1, shortcut 0, or the invoking numbered shortcut.
- No second filtering/rendering pipeline and no bypass of Exceptions.
- No change to persisted app membership, direct-set bindings, title-narrowing scope, or ordinary
  shortcut behavior beyond the explicitly migrated shared defaults.
