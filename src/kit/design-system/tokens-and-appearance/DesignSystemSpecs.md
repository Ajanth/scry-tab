# DesignSystem — Specs

## Summary

Owns shared AppKit visual tokens used by production surfaces.

## Behavior & edge cases

- Window material tint is restrained and appearance-aware.
- Settings page icons resolve to the production page order and deliberate base colors.
- Standard metrics expose the shared row, section, icon, and selection geometry.
- Shared editable text fields keep the flat surface treatment while restoring deliberate horizontal padding.
- Shared Settings action buttons draw through the app-owned flat surface with deliberate horizontal padding instead of stock button chrome.
- Shared Settings popup buttons draw through the app-owned flat surface instead of stock popup chrome.
- Shared Settings search fields use the flat bordered sidebar surface, app-owned padding, and app-owned focus chrome instead of the stock rounded bezel and exterior ring.
- Dark-mode Settings surfaces use opaque matte grays instead of translucent white overlays so cards and controls stay dense against the window background.
- Selection and focus emphasize different states: selection stays neutral while focus uses the stronger accent treatment.
- Template images in segmented controls use semantic text colors and retain their source aspect ratio.

## Test scenarios

Mirrors `DesignSystemTests.swift` 1:1.

- **testMaterialTintAlphaUsesLightAndDarkValues** — material tint alpha is 0.025 in Aqua and 0.10 in Dark Aqua.
- **testSettingsPageIconDescriptorsFollowPageIdentity** — each Settings page maps to its expected symbol.
- **testStandardGeometryTokensMatchMigrationPlan** — shared geometry tokens match the migration slice values.
- **testControlGeometryTokensMatchMigrationPlan** — shared controls use the standard height and compact flat-control radius.
- **testTextFieldUsesFlatSurfaceAndHorizontalPadding** — editable text fields keep the shared flat control chrome while preserving deliberate horizontal content padding.
- **testFlatButtonUsesAppOwnedSurfaceAndDestructiveAccent** — Settings action buttons use the app-owned flat control surface and preserve destructive semantics through the shared primitive.
- **testFlatButtonIntrinsicContentIncludesHorizontalPadding** — Settings action buttons reserve app-owned horizontal padding so long titles do not sit against the border.
- **testPopupButtonUsesAppOwnedSurface** — Settings popup buttons keep native menu behavior while drawing through the app-owned flat surface.
- **testSearchFieldUsesFlatSurfaceWithoutStockBezel** — sidebar search styling strips the stock rounded bezel and exterior focus ring, then replaces them with the shared flat field treatment and padded layout.
- **testSegmentedControlUsesAppOwnedSurface** — segmented choices keep `NSSegmentedControl` behavior while drawing through the app-owned design-system surface.
- **testSegmentedControlImageContentPreservesAspectRatio** — narrow symbols such as minus remain narrow instead of stretching into a square.
- **testSegmentedControlImageContentUsesSemanticTint** — enabled and disabled template images use the matching semantic text role.
- **testDarkModeSurfacesUseOpaqueMattePalette** — dark-mode Settings surfaces are fully opaque and step upward in brightness from plateau to flat to selected.
- **testWindowContentViewLayersMaterialBehindInsetContent** — secondary window content keeps the design-system material behind titlebar-inset content.
