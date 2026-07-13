# DesignSystem — Specs

## Summary

Owns shared AppKit visual tokens used by production surfaces.

## Behavior & edge cases

- Window material tint is restrained and appearance-aware.
- Settings page icons resolve to the production page order and deliberate base colors.
- Standard metrics expose the shared row, section, icon, selection, and focus geometry.
- Shared editable text fields keep the flat surface treatment while restoring deliberate horizontal padding.
- Shared Settings action buttons draw through the app-owned flat surface with deliberate horizontal padding instead of stock button chrome.
- Shared Settings disclosure sections center their action within the content width, use the shared compact chevron geometry and title gap, reveal their content in place, and skip animation when Reduce Motion is enabled.
- Shared Settings popup buttons draw through the app-owned flat surface instead of stock popup chrome, expand while their native menu is open, and spring back after dismissal when Reduce Motion is off.
- Shared Settings search fields use the flat bordered sidebar surface, app-owned padding, and app-owned focus chrome instead of the stock rounded bezel and exterior ring.
- The switcher search treatment is reusable without duplicating its immediate query delivery, stock rounded bezel, platform control size, or single-line behavior.
- Shared flat surface views give read-only widgets the same appearance-aware control chrome without imitating editable controls.
- Shared Settings chip selects compose app-owned flat choice buttons, clamp selection to valid choices, keep peer chip widths stable across selection changes, and use the same quiet selected-value indicator as segmented controls.
- Dark-mode Settings surfaces use opaque matte grays instead of translucent white overlays so cards and controls stay dense against the window background.
- Selection and focus emphasize different states: selection uses neutral fill and border while focus uses the stronger system-accent treatment only for the active responder.
- Shared segmented controls place their quiet selected outline immediately for initial and programmatic state changes. Native mouse and keyboard choices move it between segments with a no-bounce position spring, without animating its size; it uses the neutral 1-point selected border and respects Reduce Motion.
- Preview-choice cards use the same quiet selected fill and border as other shared controls; their blue focus ring appears only while the card is the active responder.
- Template images in segmented controls use semantic text colors and retain their source aspect ratio.

## Test scenarios

Mirrors `DesignSystemTests.swift` 1:1.

- **testMaterialTintAlphaUsesLightAndDarkValues** — material tint alpha is 0.025 in Aqua and 0.10 in Dark Aqua.
- **testSettingsPageIconDescriptorsFollowPageIdentity** — each Settings page maps to its expected symbol.
- **testStandardGeometryTokensMatchMigrationPlan** — shared geometry tokens match the migration slice values.
- **testControlGeometryTokensMatchMigrationPlan** — shared controls use the standard height, compact flat-control radius, quiet selection-indicator width, switcher-standard focus-indicator width, and one disclosure-caret geometry and title gap.
- **testFlatButtonUsesAppOwnedSurfaceAndDestructiveAccent** — Settings action buttons use the app-owned flat control surface and preserve destructive semantics through the shared primitive.
- **testFlatButtonIntrinsicContentIncludesHorizontalPadding** — Settings action buttons reserve app-owned horizontal padding so long titles do not sit against the border.
- **testDisclosureSectionTogglesItsContentAndTitle** — disclosure sections start collapsed with the shared compact trailing down-chevron and title gap while preserving standard right padding; they reveal content on demand while keeping a fixed button width, their title, upward caret, and VoiceOver expanded state synchronized.
- **testPopupButtonUsesAppOwnedSurface** — Settings popup buttons keep native menu behavior while drawing through the app-owned flat surface and are layer-backed for compositor-only press feedback.
- **testTextFieldUsesFlatSurfaceAndHorizontalPadding** — editable text fields keep the shared flat control chrome while preserving deliberate horizontal content padding.
- **testSearchFieldUsesFlatSurfaceWithoutStockBezel** — sidebar search styling strips the stock rounded bezel and exterior focus ring, then replaces them with the shared flat field treatment and padded layout.
- **testMainSearchFieldUsesSwitcherChrome** — shared switcher-search styling retains immediate query delivery, the native rounded bezel, and single-line editing.
- **testFlatSurfaceViewUsesSharedControlChrome** — read-only widgets use the shared flat surface, border, and control radius.
- **testSegmentedControlUsesAppOwnedSurface** — segmented choices keep `NSSegmentedControl` behavior while drawing through the app-owned design-system surface.
- **testSegmentedControlUsesQuietCompositorSelectionIndicator** — select-one segments update one layer-backed neutral selection outline after native actions so it follows the selected segment without resizing or redrawing their chrome.
- **testSegmentedControlDoesNotAnimateProgrammaticSelection** — initial and programmatic segment changes immediately place the selection outline instead of animating it from a stale frame.
- **testSegmentedControlImageContentPreservesAspectRatio** — narrow symbols such as minus remain narrow instead of stretching into a square.
- **testSegmentedControlImageContentUsesSemanticTint** — enabled and disabled template images use the matching semantic text role.
- **testChipSelectUsesAppOwnedChoiceButtons** — chip choices are composed from app-owned flat buttons and expose stable selected choice state.
- **testChipSelectUsesQuietCompositorSelectionIndicator** — chip choices share the segmented control's layer-backed neutral selection outline so selected values move without resizing or control-specific chrome.
- **testChipSelectClampsSelectionToAvailableChoices** — invalid selected indexes clamp into the available chip range.
- **testChipSelectKeepsStableEqualWidthsAcrossSelectionChanges** — peer chip widths stay fixed when the selected choice changes, so the row does not reflow.
- **testDarkModeSurfacesUseOpaqueMattePalette** — dark-mode Settings surfaces are fully opaque and step upward in brightness from plateau to flat to selected, while selected borders remain neutral and weaker than focus accents.
- **testWindowContentViewLayersMaterialBehindInsetContent** — secondary window content keeps the design-system material behind titlebar-inset content.
