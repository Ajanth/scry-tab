# Focus Sets: Browse-and-Select Project Switching Plan

## Status

The membership, picker, lifecycle, top-level Settings, and presentation-decoupling work described
here and in [`focus-sets/FocusSetsTopLevelMigrationPlan.md`](focus-sets/FocusSetsTopLevelMigrationPlan.md)
is implemented. This document retains the product and architecture rationale.

Focus Sets is a user-facing, opt-in project scope feature for people
working across many IDE, terminal, browser, and coding-agent windows.

## Product decision

Users must never type, see, or learn application bundle identifiers.

A Focus Set is created by browsing the applications and windows that are currently open, selecting
them by name and icon, and naming the resulting set. ScryTab records stable application identity
internally so the selection survives an application restart.

The first release uses application membership only:

- A user selects apps such as Cursor, Visual Studio Code, Terminal, Chrome, Codex, or Antigravity.
- Every current and future window of those selected apps belongs to the set.
- The setup UI shows normal app names and icons, never bundle IDs, PIDs, window IDs, or AX details.

Optional title-based narrowing is a later enhancement. It must be chosen from an actual open
window and pre-filled from its visible title; users must not be asked to invent a matching rule or
type a technical identifier.

### V1 scope contract

- A Focus Set persists application membership only. It never persists a Space ID, display ID, or
  physical-monitor association.
- Focus Sets uses its own explicit all-apps, all-Spaces, all-screens visibility policy while
  retaining normal phantom-window and exception exclusions.
- Focus Sets uses the app-wide appearance and shared window ordering/app/tab grouping defaults. It
  never persists or resolves a numbered shortcut as a presentation owner.
- Focus Set membership is an additional AND condition. It never bypasses the Focus Sets policy or
  an exception.

## Problem

The normal ScryTab switcher is intentionally a flat list of real windows. That is ideal for a
small number of windows, but becomes expensive when a developer keeps many projects and agents
open simultaneously:

- Multiple Cursor or VS Code windows become visually similar.
- A task is usually cross-app: editor, terminal, browser, documentation, chat, and agent.
- macOS Spaces are useful but too coarse for tasks that coexist on one Space or across displays.
- Search works when the user remembers a title, but not when they first need to recall the task
  context that owns a window.

Focus Sets provide a deliberate context layer without changing how existing shortcuts, window
focus, Spaces, search, or ordinary flat switching work.

## Intended behavior

### Creating a Focus Set

1. The user opens **Settings → Focus Sets**.
2. They choose **Add Focus Set** and enter a human name such as “Agentic coding” or “ScryTab”.
3. The editor presents a searchable, icon-and-name list of currently known applications:
   - selected applications first;
   - other open applications below;
   - selected applications that are not currently running, shown by their saved display name with a
     zero count and a generic icon;
   - a count of child-grid candidates under the explicit Focus Sets visibility policy;
   - checkboxes or native multi-selection controls;
   - no bundle IDs or technical identity fields.
4. The user selects apps and saves.
5. The set is usable immediately and continues to match those apps when they reopen later.

The editor can show a short explanation such as “Includes all windows from the selected apps.”
It must not imply that selecting an app moves, resizes, hides, launches, or otherwise manages its
windows.

### Switching through a Focus Set

1. A configurable global **Open Focus Sets** shortcut opens a compact first-level picker.
2. The picker lists:
   - **All Windows**;
   - each saved Focus Set;
   - optionally **Unassigned Windows** when at least one open window matches no set.
3. The user navigates with arrows, Vim keys when enabled, type-to-filter, mouse, and VoiceOver,
   then confirms a set.
4. ScryTab opens its existing normal window grid as the second level, filtered to that scope and
   the explicit Focus Sets visibility policy.
5. Selecting a child window uses the existing focus path unchanged.
6. Escape first preserves existing search-exit behavior. Once search is inactive, Escape from the
   child grid returns to the Focus Set picker; Escape there dismisses the entire flow.

The ordinary ScryTab shortcuts keep opening the ordinary flat window grid. A Focus Set is a new
entry path, not a replacement for current switching behavior. Invoking an ordinary numbered
shortcut or gesture while the picker is open dismisses the picker and opens the ordinary unfiltered
grid. Invoking one while a Focus Set child grid is open clears the Focus Set scope and follows the
ordinary cross-shortcut behavior.

### Example

“Agentic coding” contains Cursor, Visual Studio Code, Terminal, Chrome, Codex, and Antigravity.
Choosing it presents currently open windows from those applications across all Spaces and screens,
including five separate VS Code windows. Shared app and tab grouping controls determine whether
those candidates collapse. The user then selects the exact child window using the existing grid,
search, and navigation behavior.

## Explicit non-goals

- No manual entry of bundle IDs, process IDs, window IDs, AX identifiers, regexes, or shell paths.
- No automatic guesses based on repository files, agent transcript data, terminal contents, or
  cloud services.
- No app launch, window movement, snapping, tiling, minimizing, hiding, or group-wide actions.
- No changes to the behavior of existing window-switching shortcuts when Focus Sets are unused.
- No agent-status integration in the first release.
- No per-Focus-Set global hotkeys in the first release. One picker avoids shortcut conflicts and
  the existing shortcut-slot limit.
- No persisted per-Space, per-display, or physical-monitor membership. Those are volatile topology
  concerns, not durable project identity.
- No per-Focus-Set appearance, ordering, grouping, Space, or screen override in the first release.

## Why app selection is the first release

Application membership is both understandable and durable:

- It directly solves the common “many IDE and agent windows” case.
- Users can configure it by browsing familiar app names and icons.
- It persists reliably because the app stores a stable identity behind the selected app.
- It does not require a new permission or tool-specific integration.
- It does not create false confidence by attempting to infer a repository from an arbitrary window
  title.

The internal persistence key is an implementation detail. Prefer an application bundle identifier;
do not use a process ID or the live `wid-*` window ID because both change across launches.
Applications without a stable bundle identifier are not selectable for persisted app membership in
v1; the UI should simply omit them or explain that they cannot be saved reliably.

## Later enhancement: narrow an app by a visible window title

App-only membership is intentionally broad. Some users will eventually want separate Focus Sets
for two projects both open in Cursor or VS Code.

Only after the app-only flow is stable, add an optional **Narrow this app to a project window**
action:

1. The user chooses an existing open window from a list grouped by its application.
2. ScryTab proposes a readable title fragment taken from that window’s visible title.
3. The user can accept, shorten, or remove the fragment in ordinary text.
4. Matching is case- and diacritic-insensitive substring matching, not regex.

The set editor continues to show a human explanation such as “Cursor windows whose title contains
‘scry-tab’.” It never exposes the stored application identity. A stale or renamed title simply
produces zero matching windows; it must never match an unrelated window by heuristic.

## Data model

Create feature-local source under `src/switcher/focus-sets/` when implementation begins:

```text
src/switcher/focus-sets/
├── FocusSet.swift
├── FocusSetResolver.swift
├── FocusSetResolverSpecs.md
├── FocusSetResolverTests.swift
├── FocusSetPickerModel.swift
├── FocusSetPickerResolver.swift
├── FocusSetPickerResolverSpecs.md
├── FocusSetPickerResolverTests.swift
├── FocusSetPickerPanel.swift
├── FocusSetPickerView.swift
└── FocusSetSettingsView.swift
```

Persist one versioned JSON preference, for example `focusSets`, containing:

```text
FocusSetsConfiguration
├── version: Int
└── sets: [FocusSet]             // array order is display order

FocusSet
├── id: UUID
├── name: String
└── rules: [FocusSetRule]

FocusSetRule
├── applicationBundleIdentifier: String
├── cachedApplicationName: String
└── titleContains: String?    // nil in the initial app-only release
```

Rules within a set use OR semantics. A window belongs to multiple Focus Sets when it satisfies
rules in multiple sets; overlapping sets are intentional. All normal ScryTab filters then compose
with the selected set using AND semantics.

Bundle identifier matching is exact in v1. The cached name is presentation-only, lets an
unavailable selected application remain editable, and is never used for matching. Apps without a
stable bundle identifier are not selectable or matchable in persisted Focus Set membership.

The decoder must be permissive for future optional fields and reject malformed individual rules
without deleting valid sibling Focus Sets. Use a dedicated `FocusSetsStore` parser and setter; do
not use the generic JSON preference accessor that resets a malformed value. Version 3 tolerantly
reads older payloads, removes the retired presentation-owner field during normalization, and
preserves unrelated unknown root and nested fields.

## Architecture

### Preserve the existing window switcher as the child level

Do not add synthetic group entries to `Windows.list` and do not make `TileView` pretend a Focus
Set is a `Window`. The current switcher’s tile layout, mouse callbacks, selection preservation,
accessibility, and focus action all assume a tile represents a real live window.

Instead:

- One `SwitcherSession` owns the entire Focus Sets flow. It has a `phase` of
  `focusSetPicker` or `windowGrid`; the picker and grid never have key panels simultaneously.
- `FocusSetPickerPanel` owns only first-level visual selection. It does not create a parallel
  session or input system.
- Confirming a set changes the same session to `windowGrid` with a `FocusSetScope`.
- The existing `TilesPanel`, `TilesView`, `Search`, selection resolver, ordering resolver, and
  `Window.focus()` remain the second-level window experience.
- The normal focus path remains responsible for minimized windows, cross-Space windows, and
  application activation.

The session owns an explicit `.focusSets` presentation source and active scope. It records whether
the child grid returns to the picker on cancellation and gives Focus Sets do-nothing-on-release
semantics. This preserves the current hold-key state machine without allowing a released opener
modifier to focus a tile.

The flow has four explicit lifecycle operations:

1. `showFocusSetPicker()` creates a picker-phase session.
2. `confirmFocusSet(scope)` hides the picker and shows the child grid.
3. `returnToFocusSetPicker()` hides the child grid without destroying the session.
4. `dismissSwitcherUi()` tears down either phase completely.

This isolation prevents first-level selection from regressing the latency-sensitive real-window
grid while retaining existing session-gated keyboard, cursor, trackpad, refresh, and teardown
behavior.

### Filter integration

Add the selected Focus Set to the existing snapshot taken before a switcher display:

1. Resolve the active `FocusSetScope` and Focus Sets policy once at the display-refresh boundary.
2. Compile immutable exact-bundle-ID membership sets and per-application facts in memory.
3. Pass a default-true `matchesFocusSet` fact into `WindowFilterResolver.shouldShow`.
4. Keep every existing exception, app, Space, screen, hidden, minimized, fullscreen, tab,
   windowless-app, and grouping rule intact.

The membership check must be in-memory and allocation-light. It must not read UserDefaults,
perform AX IPC, query Spaces, or inspect the filesystem inside a per-window loop.

Membership is evaluated after the existing phantom and exception exclusions, before the
windowless-app branch and the lazy screen predicate. This preserves every existing rule and avoids
screen work for non-members. `FocusSetScope` has four cases:

- `allWindows`: membership always passes; the Focus Sets visibility policy remains active.
- `set(id)`: membership passes only for that set's exact application bundle IDs.
- `unassigned`: membership passes only when an app belongs to no saved Focus Set.
- `none`: used only for ordinary sessions and always passes.

Selected windowless-app rows pass only when their application belongs to the active Focus Set.
`Unassigned Windows` is the inverse of all saved Focus Set app membership, then intersects with
the Focus Sets visibility policy.

### Picker and child interaction state

The picker phase stores an ordered scope snapshot, selected index, filter query, and the explicit
Focus Sets presentation source. The grid phase stores the selected scope and return-to-picker intent.
`Windows.updatesBeforeShowing()` runs only in the grid phase; picker counts refresh through the
same event-throttled flow without rebuilding tile UI.

Deleting the selected set while its child grid is open returns to the picker. An existing set with
zero current candidates shows a deliberate empty child state and returns to the picker on Escape.
The existing selection resolver remains responsible for preserving a real selected window across
asynchronous reordering; do not add a second selection implementation.

### Shortcut integration

Add one static global shortcut labelled **Open Focus Sets** in Controls. It opens on key down and
does not use hold-and-release behavior. This avoids accidental focus on shortcut release before a
user has selected a set.

Do not repurpose `nextWindowShortcut`, alter the existing hold-key state machine, or require a
Focus Set to occupy one of the existing numbered switcher shortcuts.

The shortcut is a distinct global key-down action with a dedicated hotkey ID, conflict detection,
and no synthetic numbered shortcut index. It participates in the normal disabled-shortcuts policy.
Repeated invocation while the picker is open refreshes that picker; invocation while a child grid
is open returns to the picker.

## Settings UI

The Focus Sets manager must use the checked-in design system:

- grouped settings panels and rows;
- shared material/surface roles;
- standard buttons, segmented controls, sheets, and selection behavior;
- no feature-local panel material, tint, border, or spacing system.

The manager contains:

- concise visibility-policy text and a link to the shared appearance and organization controls;
- a list of Focus Sets with name, current matching-window count, and Edit/Delete actions;
- **Add Focus Set**;
- a set editor with Name and Included Applications sections;
- an application picker sheet with app icons, app names, search, and checked state;
- a clear empty state that explains how to create the first set;
- a searchable Settings route and localized labels/tooltips.

The application picker reads the application inventory already maintained by ScryTab. It does not
scan the disk for installed applications, launch applications to inspect them, or require network
access.

The matching-window count uses the Focus Sets visibility policy and the same membership snapshot
as the child grid, before child search. Its label makes that scope clear. It must not invoke the
full filter pipeline once per set or mutate `Windows.shouldShowTheUser`.

## Implementation phases

### Phase 1: Pure model, persistence, and matching

1. Define `FocusSetsConfiguration`, `FocusSet`, `FocusSetRule`, and `FocusSetScope`.
2. Add a versioned tolerant store, dedicated setter, legacy-field migration, and focused
   migration/decoder tests.
3. Implement exact app-only matching plus `allWindows` and `unassigned` scope resolution.
4. Add specs and tests for app-only matching, no active scope, overlapping sets, unavailable apps,
   empty sets, windowless rows, and title matching reserved for the later enhancement.
5. Add a default-true membership input to the window-filter kernel and prove it changes nothing
   when no Focus Set is active.

**Gate:** all existing filter tests stay green and the new resolver has no AppKit, AX, or
UserDefaults dependency.

### Phase 2: Settings manager and browse-and-select application picker

1. Add the top-level Focus Sets route and settings-search descriptor.
2. Build the list, editor, and application picker entirely with shared design-system primitives.
3. Add concise policy text and links to shared presentation controls.
4. Resolve the selected app’s stable identity internally when the user checks its name/icon row,
   retaining a presentation name for unavailable selected apps.
5. Persist app-only rules and show the policy-scoped candidate count.
6. Add localization for all new user-facing strings.

**Gate:** a user can create, edit, reorder, and delete a set without ever encountering a technical
identifier.

### Phase 3: First-level picker and shortcut

1. Add the Open Focus Sets shortcut and conflict handling.
2. Implement picker and child-grid phases on the existing `SwitcherSession`, including exclusive
   key-panel ownership, cursor containment, and external-event refresh routing.
3. Implement the explicit dismiss, confirm, and return-to-picker lifecycle operations.
4. Implement picker keyboard, mouse, VoiceOver, and search behavior.
5. Add All Windows and conditionally add Unassigned Windows.
6. Confirming a set launches the existing window switcher with that scope and `.focusSets`
   presentation source.
7. Preserve search Escape behavior, then return from child grid to picker, then dismiss from picker.

**Gate:** ordinary ScryTab shortcuts continue to open the unfiltered grid exactly as before.

### Phase 4: Child-grid filtering and refresh behavior

1. Snapshot the selected scope and Focus Sets policy once per display refresh.
2. Apply membership before the existing normal grid renders.
3. Reuse the existing selection resolver to preserve a real selected window when asynchronous
   events reorder matching windows.
4. Handle a deleted set, a set with zero open windows, unavailable saved applications, minimized windows,
   and windows changing Spaces while the child grid is open.
5. Keep normal search, ordering, window actions, and focus behavior unchanged inside the narrowed
   grid.

**Gate:** a Focus Set never changes results for an ordinary switcher invocation.

### Phase 5: Optional title narrowing

Only begin after usage validation confirms that app-level sets are insufficient.

1. Add the browse-from-open-windows UI.
2. Pre-fill a visible title fragment and explain its effect in human terms.
3. Add the pure title-match cases and migration compatibility tests.
4. Verify title changes only narrow a set; they never cause fuzzy or cross-application matches.

## Test plan

### Resolver and persistence tests

- No active Focus Set produces the exact pre-feature visibility result.
- A selected app includes every matching window, including multiple VS Code windows.
- A non-selected app is excluded only in a Focus Set child session.
- `allWindows` keeps the Focus Sets visibility policy while clearing only Focus Set membership.
- `unassigned` excludes apps included by any saved Focus Set.
- Selected windowless apps obey Focus Set membership and the explicit Focus Sets windowless policy.
- Empty sets show an empty child state without crashing or focusing the wrong window.
- Overlapping sets include shared windows in each relevant set.
- Hidden, minimized, fullscreen, tabbed, Space, screen, exception, windowless, and main-window
  grouping rules retain
  their current semantics after Focus Set membership is applied.
- Malformed persisted data preserves valid Focus Sets and fails safely.
- A live `wid-*` or PID never appears in persisted data.
- Legacy persisted presentation-owner data is removed safely without changing an ordinary shortcut.

### Picker tests

- Arrow, Vim, type-to-filter, mouse, Enter, and Escape all select or dismiss predictably.
- VoiceOver announces the set name and current matching-window count.
- All Windows behaves like the Focus Sets policy with no Focus Set membership constraint.
- Unassigned Windows appears only when it has results.
- A deleted set cannot be selected from stale picker or child-session state.
- Picker and child grid never show simultaneously; ordinary shortcut, gesture, and repeated
  Focus Sets shortcut re-entry follow the documented mutual-exclusion behavior.

### Regression tests

- Normal numbered shortcuts remain unfiltered.
- Existing hold-and-release shortcuts retain their focus behavior.
- Releasing the Focus Sets opener after picker confirmation never focuses a child tile.
- Search still ranks by application and window title inside a selected set.
- Selection follows a real window across asynchronous reordering.
- Cross-Space focus, minimize/deminimize, close, quit, hide/show, and fullscreen actions target
  the selected real window exactly as before.
- Light/dark appearance, Reduce Transparency, Increase Contrast, localization expansion, and
  VoiceOver remain correct.

## Verification

After implementation:

1. Run the complete command sequence from `ai/build.sh`.
2. Run focused Focus Set tests plus the complete Test scheme.
3. Run the spec/test triad audit for every added resolver.
4. Verify settings search, all supported locales, and Xcode target membership.
5. Manually verify the ordinary switcher before and after creating a Focus Set.
6. Run `graphify update .` after code changes.
7. Run `git diff --check`.

## Decision record

Focus Sets are an opt-in, browse-and-select project scope feature. Users select familiar
applications by icon and name; stable identifiers exist only in persistence. Focus Sets use an
explicit visibility policy plus app-wide appearance and shared ordering/grouping defaults. Focus
Set membership is exact app identity and composes with that policy at runtime; it is never tied to
volatile Space or monitor identity or to a numbered shortcut.

The picker and child grid are two phases of one switcher session, preserving the app's existing
keyboard, cursor, trackpad, refresh, and teardown invariants. The feature deliberately does not
become a window manager, an agent-integration product, or a second topology model.
