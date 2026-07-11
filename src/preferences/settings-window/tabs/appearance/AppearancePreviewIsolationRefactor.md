# Appearance Preview Isolation: Issue Details and Implementation Plan

## Status

Implementation approved. The live switcher source tree must remain byte-for-byte unchanged by this
work. Controls retains its established outer radio-card selection indication; the preview renderer
owns exactly one internal item highlight.

## Intended behavior

The settings UI needs one reusable animated switcher preview shared by:

- Settings → Appearance, where the user can switch between App Icons and Titles and control the
  existing pause/resume behavior.
- Settings → Controls → Appearance, where both styles are visible simultaneously, both start
  paused, selecting a style starts only that style, and switching styles pauses the previous one.

This preview is illustrative settings UI. It must not execute, mutate, subclass, or depend on the
latency-critical live window switcher implementation.

## Current architecture and boundary violation

The current dependency chain is:

```text
AppearanceLivePreviewView
└── AnimatedSwitcherPresentationView
    ├── TileView
    ├── TileUnderLayer
    ├── Appearance / Preferences
    ├── SwitcherSession
    └── TilesView layout state
```

Controls adds another layer:

```text
ShortcutOverrideRadios
└── ImageTextButtonView selection chrome
    └── AppearanceLivePreviewView
```

`AnimatedSwitcherPresentationView` has only a settings caller, but it lives under
`src/switcher/main-window/` and constructs production `TileView` and `TileUnderLayer` objects.
Preview-specific style overrides, presentation scaling, label behavior, sizing, and highlight
behavior were consequently added to `TileView.swift`. That directly changes the production live
switcher path and violates the required isolation boundary.

## User-visible failures

The coupling has produced several related regressions rather than independent cosmetic defects:

1. **Controls App Icons preview uses incorrect highlight/chrome.** The live switcher highlight and
   the Controls radio-card selection chrome are rendered in nested coordinate systems. In the
   compact host this produces an incorrect blue border/highlight and degraded rendering.
2. **Main Appearance Titles selection geometry changed.** Host-dependent scaling changed the real
   switcher highlight into a sharp-cornered elongated border instead of preserving the previously
   correct preview appearance.
3. **App Icons label flashes hidden during style changes.** Style changes rebuild tiles, but the
   new tiles temporarily use production/global style state before the preview layout applies its
   local state. The focused label becomes visible only after a later layout pass.
4. **Highlight behavior depends on navigation history.** Rebuilding removes tiles but does not
   atomically clear and replace every highlight/layout state. A stale highlight can remain until
   the next AppKit layout pass, so the artifact can disappear or reappear depending on which tab or
   style was visited immediately beforehand.
5. **Sizing fixes affect the other style.** App Icons and Titles use different layout assumptions,
   but both currently share production tile state and global metrics. Correcting one host/style has
   repeatedly exposed another implicit dependency.

## Root causes

### 1. Production and settings responsibilities are mixed

`TileView` owns production concerns: recycled live-window content, global preferences, current
switcher session state, hover/focus behavior, status indicators, search highlights, and the
performance-sensitive layout path. It is not a safe settings-preview primitive.

### 2. Style has multiple sources of truth

Preview style is passed through `AnimatedSwitcherPresentationView`, while production tiles also
resolve style from `Preferences.effectiveAppearanceStyle` and `SwitcherSession`. A tile can be
created under one style and laid out under another.

### 3. Style changes are not atomic

`update(style:items:)` rebuilds the view hierarchy, marks layout dirty, and returns. Until AppKit
runs layout, labels, highlight frames, tile frames, and the background can represent different
states. This creates the label flash and navigation-dependent stale border.

### 4. Highlight ownership is duplicated

The preview has a real-switcher `TileUnderLayer` highlight. Controls independently draws selected
radio-card chrome through `ImageTextButtonView`. The two layers have different purposes but are
visually adjacent and can overlap or appear to be one malformed highlight.

### 5. Preview sizing is derived from production geometry

The compact Controls preview and larger Appearance preview are different hosts. Production tile
geometry, host-relative scaling, nested frame/bounds scaling, and pixel alignment are mixed rather
than resolved once by a settings-specific layout model.

### 6. Verification did not cover the state/host matrix

Pure resolver tests covered isolated decisions, but there was no deterministic coverage for:

- both styles in both hosts;
- repeated App Icons → Titles → App Icons transitions;
- immediate label and highlight state before the next run-loop layout;
- Controls card selection chrome versus preview highlight chrome;
- entering Appearance from Controls and entering Controls from Appearance.

## Required architectural boundary

After the refactor, settings-preview code must not reference or instantiate:

- `TileView`
- `TileUnderLayer`
- `TilesView`
- `TilesPanel`
- `SwitcherSession`
- live-window hover, search, recycling, or focus callbacks

The refactor must restore `TileView.swift` and other production switcher files so they contain no
settings-preview state, presentation overrides, presentation scaling, or preview-only methods.

Settings preview code may reuse stable lower-level facilities that do not execute the production
switcher path, such as AppKit, design-system tokens, icon lookup, wallpaper artwork, and the generic
timer/playback controller.

## Proposed settings-only architecture

Place the implementation with the feature, for example:

```text
src/preferences/settings-window/tabs/appearance/preview/
├── AppearancePreviewModel.swift
├── AppearancePreviewLayoutResolver.swift
├── AppearancePreviewLayoutResolverSpecs.md
├── AppearancePreviewLayoutResolverTests.swift
├── AppearancePreviewStateResolver.swift
├── AppearancePreviewStateResolverSpecs.md
├── AppearancePreviewStateResolverTests.swift
└── AppearancePreviewSwitcherView.swift
```

Responsibilities:

- **AppearancePreviewModel**: immutable style, items, focused index, and host configuration.
- **AppearancePreviewLayoutResolver**: pure, deterministic frames and scale for App Icons and
  Titles at a supplied host size.
- **AppearancePreviewStateResolver**: pure initial-focus and Controls playback decisions.
- **AppearancePreviewSwitcherView**: applies a complete preview state atomically and privately owns
  its lightweight tile and single-highlight views. It has no preferences, sessions, recycled live
  windows, search state, or hover callbacks.
- **AppearanceLivePreviewView**: remains the shared wallpaper/playback host used by both settings
  tabs.

## Implementation plan

### Phase 1: Restore the production boundary

1. Identify every preview-driven change in production switcher files.
2. Revert only those changes; preserve unrelated user and repository work.
3. Remove the settings dependency on `AnimatedSwitcherPresentationView` in
   `src/switcher/main-window/`.
4. Verify the production switcher files have no settings-preview API or state.
5. Build and run the existing test suite before adding the replacement renderer.

**Gate:** no further UI integration until the app builds with the production switcher restored.

### Phase 2: Implement a settings-only renderer

1. Define a small immutable preview model using the existing demo items.
2. Implement pure layout resolution for App Icons and Titles.
3. Render icons at the final pixel-aligned target size; avoid nested transform-based downscaling
   that can blur icons or distort corner radii.
4. Implement one settings-only highlight with style-specific geometry.
5. Reuse existing design-system colors and appearance artwork; add no feature-local chrome.
6. Keep the renderer independent of preferences and live switcher session state.

**Gate:** both styles must render deterministically at the main Appearance and Controls card sizes
before animation or tab integration is added.

### Phase 3: Make state changes atomic

1. Keep a single preview state as the source of truth.
2. On style change, compute the complete new layout first.
3. Clear the previous highlight and configure every tile/label while the new scene is hidden, or
   update persistent tile views inside a disabled-actions Core Animation transaction.
4. Force the settings preview subtree to lay out synchronously.
5. Reveal/commit only after tile frames, label visibility, and highlight geometry agree.
6. Do not wait for a later run-loop layout to make the selected label visible.

**Gate:** repeated App Icons → Titles → App Icons transitions must have no stale border, hidden-label
frame, or navigation-history dependency.

### Phase 4: Integrate the main Appearance tab

1. Replace its production-switcher-backed preview with the settings-only renderer.
2. Preserve its current wallpaper size, pause control, accessibility behavior, and animation timing.
3. Match the previously accepted App Icons and Titles visuals exactly.
4. Confirm the selected label is visible immediately when returning to App Icons.

### Phase 5: Integrate Controls → Appearance

1. Use the same settings-only renderer for both style cards.
2. Keep both previews initially paused.
3. Selecting a card starts only its preview and pauses the other.
4. Keep Controls card selection chrome outside the preview renderer.
5. Do not add a second highlight or border inside the preview.
6. Preserve the requested flush preview without reintroducing the outer gray surround.

### Phase 6: Remove obsolete preview code

1. Leave the existing production switcher tree unchanged, including the now-unused legacy
   `AnimatedSwitcherPresentationView`.
2. Remove settings references to the legacy renderer and presentation-only resolver helpers.
3. Update Xcode target membership for the added settings-only files.

## Test plan

### Pure layout tests

- App Icons frames remain inside both host sizes.
- Titles frames remain inside both host sizes.
- Highlight frames use the expected style-specific radius and bounds.
- Final icon frames are pixel aligned.
- Host resizing does not change the semantic selection or label visibility.

### State-transition tests

- App Icons → Titles applies complete Titles state atomically.
- Titles → App Icons exposes the focused label immediately.
- Repeated switching does not retain a stale highlight frame.
- Entering from Controls and entering from Appearance yield identical preview state.
- Initial paused state and explicit pause/resume state are deterministic.

### Controls playback tests

- Binding a shortcut pauses both previews.
- Selecting App Icons runs only App Icons.
- Selecting Titles pauses App Icons and runs only Titles.
- Re-selecting or removing an override leaves one correct selected state.

### Boundary verification

- Search the final settings-preview sources for forbidden production switcher types.
- Confirm the final diff contains no preview-driven production `TileView`, `TileUnderLayer`,
  `TilesView`, `TilesPanel`, or `SwitcherSession` changes.
- Run the required command sequence from `ai/build.sh`.
- Run the complete Test scheme and the spec/test audit.
- Run `git diff --check` on staged and unstaged changes.

## Visual acceptance matrix

Verify each cell before completion:

| Host | Style | State |
| --- | --- | --- |
| Main Appearance | App Icons | initial, focused-label visible, animating, paused |
| Main Appearance | Titles | initial, animating, paused |
| Controls Appearance | App Icons | selected, unselected, paused, animating |
| Controls Appearance | Titles | selected, unselected, paused, animating |

Also verify:

- App Icons → Titles → App Icons without label flash.
- Titles → App Icons → Titles without stale or malformed borders.
- Appearance → Controls → Appearance and Controls → Appearance → Controls.
- Light and dark appearance.
- Reduce Motion and Increase Contrast.
- Small, Medium, Large, and Auto appearance sizes.
- Retina pixel alignment and no thumbnail blur.

## Non-goals

- No production live-switcher behavior, layout, event handling, or performance changes.
- No preference-key or migration changes.
- No new materials, colors, control chrome, or visual redesign.
- No change to unrelated settings tabs.
- No server or browser work.

## Risks and controls

- **Visual drift from the accepted preview:** compare against the supplied screenshots and stop at
  each integration gate for review.
- **Duplicating production logic:** implement only the small illustrative settings model; do not
  copy production window/session/recycling behavior.
- **Another hidden global dependency:** pass every preview input explicitly and prohibit references
  to `Preferences` and `SwitcherSession` inside preview tiles/layout.
- **Transition flicker:** make state application synchronous and test state immediately, before a
  later run-loop iteration.
- **Accidental production regression:** require a zero preview-driven diff in production switcher
  files before final verification.

## Decision record

The settings-only renderer and restoration of the production switcher files are approved. Controls
retains the established outer radio-card selection indication. The preview itself has exactly one
item highlight and no additional custom border.
