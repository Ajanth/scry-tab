# ScryTab AppKit visual-system migration plan

- Status: ready for implementation
- Scope: production, app-owned UI
- Reference: `/Users/ajanth/development/mac-app-boilerplate` at Luminare revision
  `25056d7ac24b9a45a4225ea36da90329ea16d9a1`
- Visual references: the supplied General and About screenshots
- First implementation slice: Settings shell plus General and About

## 1. Objective

Keep the local AppKit design-system migration and correct its visual result. Do not
replace it with feature-local styling or a collection of stock AppKit controls.

The target is the visual language demonstrated by `mac-app-boilerplate`:

- a quiet material window with restrained, neutral surfaces;
- a clearly divided sidebar and content pane;
- a fixed, centered page header;
- colored rounded icon tiles with white symbols;
- neutral sidebar selection rather than an accent-filled source-list selection;
- compact section labels and joined rounded row groups;
- consistent 32-point controls, subtle separators, semantic fills, and restrained
  accent use.

Implement that language independently with programmatic AppKit and Swift 5.8.
Do not add Luminare, SwiftUI, Interface Builder, or another UI framework. Do not
copy Luminare source. If source is adapted rather than independently implemented,
include the required BSD-3-Clause attribution in the same change.

The Components tab in the reference app is not a product requirement and must not
be recreated.

## 2. Existing baseline

The Settings navigation migration is complete. It is not part of this plan.

Preserve the existing:

- dedicated top-level Settings routes and pages;
- lazy page construction, retained page reuse, scroll restoration, and focus;
- route-aware search, grouped results, stable shortcut destinations, and exception
  destinations;
- Controls inner-sidebar destinations;
- Appearance motion controls;
- About route inside Settings.

Do not reintroduce a shared scroll-linked document, rewrite search, convert pages
again, or use this visual migration to change product information architecture.
Page content and behavior stay where they are unless a small layout adjustment is
required to apply the shared visual system.

## 3. Hard exclusions

This migration must add no developer-facing UI.

- No Components tab.
- No component gallery, style gallery, appearance playground, inspector, or
  preview window.
- No constraint visualizer or runtime constraint-visualization preference.
- Do not set `NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints`.
- No debug-only Settings route, sidebar item, menu item, toolbar item, or button.
- No additions to `QAMenu` or other existing debug surfaces.
- No production API whose only purpose is rendering synthetic preview states.

Verify visual states in the real production surfaces and verify token/state logic
with unit tests. The absence of a debug gallery is intentional.

Also out of scope:

- switcher restyling;
- OS-owned menus, alerts, open/save panels, security prompts, and Sparkle UI;
- new settings or product features;
- broad animation work;
- unrelated control or window refactors.

## 4. Reference shell

### Window and panes

- Keep the current Settings content width required by ScryTab, with a 620-point
  default height and 520-point minimum height.
- Use a 230-point sidebar and a 50-point content header.
- Preserve the transparent titlebar, native traffic lights, dragging, resizing,
  frame persistence, and full-size content view.
- Preserve the supported system corner treatment: 12 points through macOS 25 and
  the supported macOS 26 treatment.
- Separate sidebar/content with a one-point semantic divider.
- Separate the page header/content with the same one-point divider.
- Allow content to scroll only below the fixed header.

The reference background is not an opaque gray window and not a decorative
gradient. Each major pane uses:

1. one retained `NSVisualEffectView`;
2. `.menu` material;
3. `.behindWindow` blending;
4. a uniform primary-accent multiply tint at 0.025 opacity in light appearance and
   0.10 in dark appearance.

Do not place an accent gradient over the window, sidebar, header, page background,
or section groups. Accent gradients are limited to small icon/illustrative
surfaces that explicitly require them.

Retain the existing application-interface System/Light/Dark behavior independently
from the switcher theme. On macOS 10.13, use the existing light fallback.

### Header

The reference header is centered in the content pane. It is not a leading-aligned
page title.

- Center the icon-and-title group horizontally.
- Header height: 50.
- Icon tile: 22 x 22, radius 6.
- Icon/title gap: 8.
- Title: system title-2 equivalent, approximately 17 points, medium weight.
- Keep the group vertically centered and truncate only when localized text cannot
  fit.

### Sidebar

- Horizontal inset: 12.
- Section gap: 24.
- Group-label to first-item gap: 4.
- Group label: 13-point medium, secondary color, with 6-point leading inset.
- Item minimum height: 30; use 32 where the current table requires a stable row
  height.
- Item content padding: 4.
- Selection radius: 12.
- Sidebar content becomes 50% opaque when the window is inactive, while the
  current selection remains legible.
- Do not show permanent scroll indicators; retain a fade mask only when the list
  actually overflows.

The selection is a neutral quaternary surface at approximately 70% opacity. Do not
delegate final selection drawing to the default focused `NSTableView` source-list
highlight, because that produces the wrong accent-heavy appearance.

Keep the existing search field and behavior. Style it as part of the sidebar
without making it the dominant visual element.

### Page icon tiles

Create one reusable production `SettingsPageIconView` and use it in both the
sidebar and header.

- Draw a rounded base-color tile, not a bare tinted SF Symbol.
- Use a restrained same-hue gradient within the tile.
- Draw the symbol in white at approximately 12 points and medium weight.
- Add only the subtle highlight/border needed for dark-mode edge definition.
- Do not turn the whole icon monochrome when its row is selected.

| Page | Symbol | Base color |
| --- | --- | --- |
| Appearance | `paintpalette.fill` | teal |
| Controls | `command` | indigo |
| General | `gearshape.fill` | green |
| Exceptions | `hand.raised.fill` | orange |
| About | `info.circle.fill` | neutral gray |

Preserve the current production page order and grouping. Do not add Quit or any
debug destination to the sidebar.

## 5. Production design system

Retain `src/kit/design-system/` as the owner of shared visual behavior. Do not
delete it in favor of raw controls and feature-local constants.

Keep the implementation small and production-driven:

```text
src/kit/design-system/
  tokens-and-appearance/
  surfaces/
  forms/
  controls/
  lists/
  presentation/
```

Only add or retain a primitive when a production surface uses it. Gallery-only
metrics, preview environments, and synthetic sample APIs do not belong in the
design system.

Existing `TableGroupView` call sites may remain temporarily as compatibility
facades, but their geometry and drawing must delegate to the shared tokens and
surface styles. Returning pages to the legacy `TableGroupView` appearance is not
an acceptable final state.

### Tokens

| Token | Value |
| --- | --- |
| Window radius | 12 through macOS 25; supported system treatment on 26 |
| Section radius | 12 |
| Joined outer row radius | 8 |
| Joined inner row radius | 4 |
| Sidebar selection radius | 12 |
| Sidebar icon radius | 6 |
| Form outer padding | 12 |
| Modal outer padding | 16 |
| Section gap | 16 |
| Header/footer gap | 4 |
| Row horizontal padding | 8 |
| Row vertical padding | 4 |
| Standard control minimum height | 32 |
| Standard/rich list row | 50-52 / 52-56 |

Typography:

- Header title: system 17 medium.
- Section header: system 13 medium, secondary.
- Row title: system 13 regular; medium only for emphasis.
- Supporting text: system 11-12 regular, secondary.
- Metrics: system 20-24 medium with monospaced digits where useful.
- Do not bundle an interface font.

Color roles:

```text
windowMaterial, windowAccentTint
surfacePlateau, surfaceFlat, surfaceHover, surfacePressed, surfaceSelected
borderSubtle, borderSelected
textPrimary, textSecondary, textDisabled
statusSuccess, statusWarning, statusDestructive
searchMatch, accentPrimary, accentSecondary
```

Feature pages must not choose local RGB or hex values for shared surfaces.
Page-icon base colors are the deliberate exception.

### Surface rules

- Plateau, light: white at 0.70 opacity, quaternary border, black shadow at 0.10
  opacity with 0.5 radius and 0.5 vertical offset.
- Plateau, dark: quinary fill, quaternary boundary, no shadow.
- Flat: quinary fill with quaternary hover/pressed fill and a subtle boundary.
- Selected controls: primary accent at approximately 0.15 opacity with a one-point
  accent border.
- Disabled content: 50% opacity using the same geometry.
- State precedence: disabled, pressed, selected, hovered, normal.
- Focus is an independent accessibility-visible ring, not a replacement fill.
- Increase Contrast strengthens boundaries.
- Reduce Transparency replaces ambiguous material/translucent fills with opaque
  semantic fills.

Use semantic/dynamic `NSColor` roles resolved against the effective appearance.
Refresh retained layer colors when appearance, accent, key-window state, or
accessibility display options change.

### Forms and controls

Sections are joined row groups, not a vertical collection of unrelated stock
controls.

- Form inset: 12.
- Space sections by 16.
- Place section labels 4 points above their groups.
- Use one outer 12-point section shape, one-point boundary, and one-point inset
  separators between rows.
- Rows have a 32-point minimum height and consistent 8-point horizontal content
  inset.
- Round only the exposed outer corners; inner joins use the joined-row radii.

Keep native controls where they carry important macOS behavior, but place them
inside design-system rows and remove conflicting stock chrome where needed.

- Keep `NSSwitch` on macOS 10.15+ and the existing older-system fallback.
- Use a shared custom surface for segmented choices; do not accept the default
  `NSSegmentedControl` appearance as visual parity.
- Use shared flat surfaces for action buttons, recorders, popup affordances, text
  fields, text editors, and color wells.
- Keep destructive actions semantic red and visually separated without turning
  an entire section into a warning card.
- Preserve keyboard interaction, first responder behavior, menus, IME behavior,
  accessibility labels, and tooltips.

## 6. Migration sequence

### Slice 1 - Reference calibration

1. Retain/repair the semantic tokens and production surface primitives.
2. Implement the material window, pane dividers, 230-point sidebar, neutral
   selection, centered header, and shared page icon tile.
3. Apply joined sections and row styling to General and About.
4. Compare those two real pages directly with the supplied reference screenshots
   in both light and dark appearances.
5. Correct shell color, contrast, spacing, icon treatment, and control chrome
   before touching the remaining pages.

Exit:

- The shell reads as the same design family as the reference at first glance.
- Header alignment, sidebar selection, icon tiles, section surfaces, and row rhythm
  match the reference.
- There is no broad gradient or accent wash.
- No debug UI or constraint visualization has been added.

### Slice 2 - Remaining Settings pages

Apply the calibrated system in this order:

1. Appearance
2. Exceptions
3. Controls

Preserve each page's current content, nested navigation, editors, and search/deep
link behavior. Reuse the production components established in Slice 1; do not
invent page-specific versions.

Exit:

- Every Settings page uses the same shell, section, row, control, list, and text
  treatments.
- No page falls back to legacy stock styling for convenience.
- Dynamic editors retain their current sizing, reuse, focus, and keyboard behavior.

### Slice 3 - Existing secondary surfaces

After Settings is visually accepted, apply the same established tokens to existing
Permissions, Feedback, and focused app-owned editors where they currently diverge.
Do not redesign their workflows and do not replace native system dialogs.

The switcher is not part of this slice and remains unchanged.

### Slice 4 - Cleanup

- Remove obsolete feature-local visual constants and superseded legacy drawing.
- Remove any leftover gallery, gallery metrics, preview-only APIs, constraint
  visualization, and debug entry points from the abandoned implementation.
- Keep the production design system, its specs, and its tests.
- Update localization only for changed production text; do not add debug strings.

## 7. Invariants

- Programmatic AppKit and Swift 5.8 only.
- Preserve the macOS 10.13 deployment target.
- Preserve public release APIs and the existing macOS 26 `NSGlassEffectView` path.
- Preserve localization, right-to-left layout, keyboard navigation, Full Keyboard
  Access, VoiceOver semantics, and accessibility display settings.
- Preserve all existing settings behavior, search behavior, deep links, and
  first-responder behavior.
- Use notifications/observer APIs for appearance and state changes; do not poll.
- Retain and update material views/layers in place rather than rebuilding view
  trees on appearance changes.
- Do not touch switcher summon, selection, cycling, allocation, or animation paths.
- Preserve bundle ID `com.perpro.scry-tab`, Team ID `QXD7GW8FHY`, Developer ID,
  entitlements, and signing behavior.
- Do not change license/Keychain behavior or introduce `SecKeychain*` or
  `kSecAccessControl`.

## 8. Verification

For each implementation slice:

1. Add or update co-located `*Specs.md` and `*Tests.swift` triads for changed
   design-system logic.
2. Run the spec/test consistency audit for every edited triad.
3. Run relevant unit tests and `npm run format:check`.
4. Copy and run the commands from `ai/build.sh`, including the local keychain
   unlock step.
5. Capture the real Settings General and About pages at the default window size in
   light and dark appearance and compare them with the supplied references.

Visual acceptance checklist:

- neutral `.menu` material with restrained uniform tint;
- no window, sidebar, header, page, or section gradient;
- clear one-point pane and header dividers;
- centered 50-point header;
- colored 22-point icon tiles in both sidebar and header;
- neutral rounded sidebar selection;
- 12-point page inset, 16-point section rhythm, and compact labels;
- joined 32-point rows with subtle boundaries;
- consistent control surfaces without mismatched stock AppKit chrome;
- active, inactive, disabled, focused, hovered, and pressed states;
- light/dark, Increase Contrast, Reduce Transparency, and Reduce Motion;
- long localized text, right-to-left layout, Full Keyboard Access, and VoiceOver;
- no new debug UI, debug route, debug menu item, debug window, or constraint
  visualizer.

## 9. Completion criteria

The migration is complete when:

- Settings visibly matches the supplied boilerplate design language while
  retaining ScryTab's existing pages and behavior;
- the production AppKit design system owns shared colors, geometry, surfaces, and
  control states;
- General and About match the reference shell and form treatment, and the remaining
  pages use the same calibrated components;
- no page relies on raw default AppKit styling where the reference uses a custom
  surface;
- the switcher and system-owned UI remain unchanged;
- no developer-facing UI or constraint visualization was introduced;
- supported macOS versions, accessibility, localization, signing, license, and
  Keychain invariants remain intact.
