# Focus Sets: Browse-and-Select Project Switching Plan

## Status

Draft. This plan refines Focus Sets into a user-facing, opt-in project scope feature for people
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

1. The user opens **Settings → Controls → Advanced → Focus Sets**.
2. They choose **Add Focus Set** and enter a human name such as “Agentic coding” or “ScryTab”.
3. The editor presents a searchable, icon-and-name list of currently known applications:
   - selected applications first;
   - other open applications below;
   - a count of currently matching windows;
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
4. ScryTab opens its existing normal window grid as the second level, filtered to that set.
5. Selecting a child window uses the existing focus path unchanged.
6. Escape from the child grid returns to the Focus Set picker; Escape there dismisses it.

The ordinary ScryTab shortcuts keep opening the ordinary flat window grid. A Focus Set is a new
entry path, not a replacement for current switching behavior.

### Example

“Agentic coding” contains Cursor, Visual Studio Code, Terminal, Chrome, Codex, and Antigravity.
Choosing it presents all currently open windows from those applications, including five separate
VS Code windows. The user then selects the exact child window using the existing grid, search, and
navigation behavior.

## Explicit non-goals

- No manual entry of bundle IDs, process IDs, window IDs, AX identifiers, regexes, or shell paths.
- No automatic guesses based on repository files, agent transcript data, terminal contents, or
  cloud services.
- No app launch, window movement, snapping, tiling, minimizing, hiding, or group-wide actions.
- No changes to the behavior of existing window-switching shortcuts when Focus Sets are unused.
- No agent-status integration in the first release.
- No per-Focus-Set global hotkeys in the first release. One picker avoids shortcut conflicts and
  the existing shortcut-slot limit.

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

Persist a single JSON preference, for example `focusSets`, containing:

```text
FocusSet
├── id: UUID
├── name: String
├── order: Int
└── rules: [FocusSetRule]

FocusSetRule
├── applicationBundleIdentifier: String
└── titleContains: String?    // nil in the initial app-only release
```

Rules within a set use OR semantics. A window belongs to multiple Focus Sets when it satisfies
rules in multiple sets; overlapping sets are intentional. All normal ScryTab filters then compose
with the selected set using AND semantics.

The decoder must be permissive for future optional fields and reject malformed individual rules
without deleting valid sibling Focus Sets. It must not use a decode failure to erase the user’s
entire configuration.

## Architecture

### Preserve the existing window switcher as the child level

Do not add synthetic group entries to `Windows.list` and do not make `TileView` pretend a Focus
Set is a `Window`. The current switcher’s tile layout, mouse callbacks, selection preservation,
accessibility, and focus action all assume a tile represents a real live window.

Instead:

- `FocusSetPickerPanel` owns only first-level set selection.
- Confirming a set creates a normal `SwitcherSession` with an optional `focusSetID`.
- The existing `TilesPanel`, `TilesView`, `Search`, selection resolver, ordering resolver, and
  `Window.focus()` remain the second-level window experience.
- The normal focus path remains responsible for minimized windows, cross-Space windows, and
  application activation.

This isolation prevents first-level selection from regressing the latency-sensitive real-window
grid.

### Filter integration

Add the selected Focus Set to the existing snapshot taken before a switcher display:

1. Resolve the active Focus Set once at summon/refresh time.
2. Compute a pure membership result from `WindowState`, `ApplicationState`, and the snapshot.
3. Pass a default-true `matchesFocusSet` fact into `WindowFilterResolver.shouldShow`.
4. Keep every existing exception, app, Space, screen, hidden, minimized, fullscreen, tab, and
   windowless-app rule intact.

The membership check must be in-memory and allocation-light. It must not read UserDefaults,
perform AX IPC, query Spaces, or inspect the filesystem inside a per-window loop.

### Picker interaction state

Keep picker state separate from the ordinary `SwitcherSession` until the user confirms a set.
The picker needs only:

- an ordered snapshot of selectable sets;
- a selected index;
- a filter query;
- whether the user arrived from the Focus Set shortcut.

After confirmation, the child switcher stores:

- `focusSetID`;
- whether Cancel should return to the picker rather than immediately dismissing;
- the originating shortcut index for existing appearance and filtering preferences.

Deleting or editing a selected set while its child switcher is open must invalidate the stale
selection safely: refresh to matching remaining windows when possible; otherwise return to the
picker rather than attempting to focus a stale target.

### Shortcut integration

Add one static global shortcut labelled **Open Focus Sets** in Controls. It opens on key down and
does not use hold-and-release behavior. This avoids accidental focus on shortcut release before a
user has selected a set.

Do not repurpose `nextWindowShortcut`, alter the existing hold-key state machine, or require a
Focus Set to occupy one of the existing numbered switcher shortcuts.

## Settings UI

The Focus Sets manager must use the checked-in design system:

- grouped settings panels and rows;
- shared material/surface roles;
- standard buttons, segmented controls, sheets, and selection behavior;
- no feature-local panel material, tint, border, or spacing system.

The manager contains:

- a list of Focus Sets with name, current matching-window count, and Edit/Delete actions;
- **Add Focus Set**;
- a set editor with Name and Included Applications sections;
- an application picker sheet with app icons, app names, search, and checked state;
- a clear empty state that explains how to create the first set;
- a searchable Settings route and localized labels/tooltips.

The application picker reads the application inventory already maintained by ScryTab. It does not
scan the disk for installed applications, launch applications to inspect them, or require network
access.

## Implementation phases

### Phase 1: Pure model, persistence, and matching

1. Define `FocusSet` and `FocusSetRule`.
2. Add a tolerant JSON preference and focused migration/decoder tests.
3. Implement `FocusSetResolver.matches`.
4. Add specs and tests for app-only matching, no active set, overlapping sets, empty sets, and
   title matching reserved for the later enhancement.
5. Add a default-true membership input to the window-filter kernel and prove it changes nothing
   when no Focus Set is active.

**Gate:** all existing filter tests stay green and the new resolver has no AppKit, AX, or
UserDefaults dependency.

### Phase 2: Settings manager and browse-and-select application picker

1. Add the Controls → Advanced Focus Sets route.
2. Build the list, editor, and application picker entirely with shared design-system primitives.
3. Resolve the selected app’s stable identity internally when the user checks its name/icon row.
4. Persist app-only rules and show the live matching-window count.
5. Add localization for all new user-facing strings.

**Gate:** a user can create, edit, reorder, and delete a set without ever encountering a technical
identifier.

### Phase 3: First-level picker and shortcut

1. Add the Open Focus Sets shortcut and conflict handling.
2. Implement an isolated picker panel/model with keyboard, mouse, VoiceOver, and search behavior.
3. Add All Windows and conditionally add Unassigned Windows.
4. Confirming a set launches the existing window switcher with that set as an additional scope.
5. Make Escape return from the child grid to the picker, then dismiss from the picker.

**Gate:** ordinary ScryTab shortcuts continue to open the unfiltered grid exactly as before.

### Phase 4: Child-grid filtering and refresh behavior

1. Snapshot the selected set once per display refresh.
2. Apply membership before the existing normal grid renders.
3. Preserve current selection by real window ID when asynchronous window events reorder matching
   windows.
4. Handle a deleted set, a set with zero open windows, renamed applications, minimized windows,
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
- Empty sets show no child windows without crashing or focusing the wrong window.
- Overlapping sets include shared windows in each relevant set.
- Hidden, minimized, fullscreen, tabbed, Space, screen, exception, and windowless rules retain
  their current semantics after Focus Set membership is applied.
- Malformed persisted data preserves valid Focus Sets and fails safely.
- A live `wid-*` or PID never appears in persisted data.

### Picker tests

- Arrow, Vim, type-to-filter, mouse, Enter, and Escape all select or dismiss predictably.
- VoiceOver announces the set name and current matching-window count.
- All Windows behaves like an ordinary switcher summon.
- Unassigned Windows appears only when it has results.
- A deleted set cannot be selected from stale picker or child-session state.

### Regression tests

- Normal numbered shortcuts remain unfiltered.
- Existing hold-and-release shortcuts retain their focus behavior.
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
applications by icon and name; stable identifiers exist only in persistence. The initial release
groups all windows of selected applications, uses a separate first-level picker, and funnels into
the existing real-window switcher. It deliberately does not become a window manager or an
agent-integration product.
