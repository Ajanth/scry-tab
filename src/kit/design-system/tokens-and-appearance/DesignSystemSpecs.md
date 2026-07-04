# DesignSystem — Specs

## Summary

Owns shared AppKit visual tokens used by production surfaces.

## Behavior & edge cases

- Window material tint is restrained and appearance-aware.
- Settings page icons resolve to the production page order and deliberate base colors.
- Standard metrics expose the shared row, section, icon, and selection geometry.

## Test scenarios

Mirrors `DesignSystemTests.swift` 1:1.

- **testMaterialTintAlphaUsesLightAndDarkValues** — material tint alpha is 0.025 in Aqua and 0.10 in Dark Aqua.
- **testSettingsPageIconDescriptorsFollowPageIdentity** — each Settings page maps to its expected symbol.
- **testStandardGeometryTokensMatchMigrationPlan** — shared geometry tokens match the migration slice values.
- **testControlGeometryTokensMatchMigrationPlan** — shared controls use the standard height and compact flat-control radius.
- **testSegmentedControlUsesAppOwnedSurface** — segmented choices keep `NSSegmentedControl` behavior while drawing through the app-owned design-system surface.
- **testWindowContentViewLayersMaterialBehindInsetContent** — secondary window content keeps the design-system material behind titlebar-inset content.
