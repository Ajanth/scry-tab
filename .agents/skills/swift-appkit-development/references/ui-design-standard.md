# macOS UI Contract

The checked-in design system is mandatory app chrome, not a visual reference. Its material wrapper and `surface*` palette define the project's liquid-glass-like appearance. New and modified UI must reuse them exactly.

## Canonical Implementation

- `src/kit/design-system/tokens-and-appearance/DesignSystem.swift`
- `src/kit/design-system/controls/DesignSystemControls.swift`
- `src/kit/design-system/surfaces/DesignSystemSurfaces.swift`
- `src/preferences/settings-window/TableGroupView.swift`
- `src/preferences/settings-window/LabelAndControl.swift`
- `src/preferences/settings-window/tabs/appearance/AppearanceTab.swift`
- `src/preferences/settings-window/tabs/controls/ControlsTab.swift`

Inspect design-system files as the authority and the settings tabs for composition and interaction; do not copy feature-local values from a screen. If required behavior is missing, extend the shared primitive and its tests first. Never implement an app-chrome exception inside a feature.

## Required Surface Hierarchy

| Layer | Required implementation |
| --- | --- |
| Window background | `DesignSystemWindowContentView` / `DesignSystemMaterialView` with `windowAccentTint` |
| Grouped panel | `TableGroupView`, established sidebar container, or `DesignSystemControlStyler.styleSurface`; `surfacePlateau` + `borderSubtle` |
| Field or flat control | Existing design-system control/styler; `surfaceFlat` + `borderSubtle` |
| Interaction | `surfaceHover`, `surfacePressed`, `surfaceSelected`, `borderSelected`, and `focusAccent` |
| Text and status | Existing text and status roles or AppKit semantic text colors |

- Do not instantiate a new visual-effect material, substitute newer OS-specific Liquid Glass APIs, create an alternate tint, add gradients, or place translucent white overlays over dark surfaces.
- Do not add feature-local RGB, grayscale, alpha, panel fills, borders, corner radii, spacing scales, shadows, or control chrome. Deliberate content colors inside artwork or previews are the only exception; their container remains design-system chrome.
- Resolve layer colors through `DesignSystem.resolvedCGColor` or `semanticCGColor` using the owning view's `effectiveAppearance`.
- Refresh cached colors on appearance changes and accessibility display-option changes. Reduce Transparency must use the established opaque fallback.

## Composition and Controls

- Keep the compact System Settings hierarchy: quiet window material, grouped plateau sections, flat controls, short primary labels, and secondary explanations.
- Build settings pages with `TableGroupSetView`, sections with `TableGroupView`, and standard rows with `LabelAndControl`.
- Use existing buttons, switches, segmented controls, pop-ups, fields, search fields, dividers, and tool rows. Do not reproduce their drawing or joined-row behavior.
- Do not add decorative cards, nested grouped surfaces, oversized headings, ornamental color, or marketing-style layouts.
- Use `DesignSystem.Metrics` and existing table metrics. Preserve established widths, alignment, density, and 32-point minimum control height.
- Use Auto Layout and intrinsic sizing. Support wrapped localized text without clipping or overlap.

## Native Behavior and Acceptance

- Preserve AppKit target/action, menus, editing, responder chain, keyboard traversal, focus, enabled state, and accessibility semantics.
- Provide tooltips and accessibility labels for icon-only controls. Never rely on hover or color alone.
- Verify normal, hover, pressed, selected, focused, disabled, key/non-key window, light, dark, Reduce Transparency, and Increase Contrast states where applicable.
- Register settings labels, values, help, and destinations with settings search and keep control state synchronized with preferences.
- Treat any deviation from the shared surface hierarchy, palette, metrics, control behavior, or macOS interaction model as a defect.
- Without explicit authorization to launch the app, verify structure and stable properties in code/tests and report visual QA as unverified.
