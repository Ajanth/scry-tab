# AppearancePreviewLayoutResolver - Specs

## Summary

The settings-only appearance preview resolves final, pixel-aligned geometry from local snapshots of
the live switcher's Small, Medium, Large, and Auto App Icons and Titles visual metrics. Auto matches
the production three-item preview's Large resolution. The resolver uniformly applies host-only
scaling without reading live preferences or switcher state, and selects the live material,
panel-shadow, border, radius, typography, and status-symbol decisions for Tahoe and pre-Tahoe.

## Test scenarios

- **testAppIconsFramesFitBothHosts** - App Icons panel, tiles, and highlight remain inside the main Appearance and compact Controls hosts.
- **testTitlesFramesFitBothHosts** - Titles panel, rows, and highlight remain inside the main Appearance and compact Controls hosts.
- **testAppIconsHighlightMatchesLiveTileGeometry** - App Icons uses the live medium tile highlight geometry around the icon and edge insets.
- **testTitlesGeometryMatchesLiveMediumLayout** - Titles uses the live medium row geometry, panel padding, dense spacing, and full-row highlight.
- **testAppIconsCentersInBothHosts** - App Icons remains centered in both settings hosts after uniform production-geometry scaling.
- **testAppIconsAllSizesMatchProductionMetrics** - App Icons reproduces production icon, font, inset, and Tahoe radius metrics for every size.
- **testTitlesAllSizesMatchProductionMetrics** - Titles reproduces production icon, font, label, row, and status metrics for every size.
- **testLegacyAppIconsAllSizesMatchProductionMetrics** - Pre-Tahoe App Icons keeps production legacy insets and radii across every concrete size.
- **testResolvedFramesArePixelAligned** - Final panel, tile, icon, label, status, and highlight edges align to the supplied backing scale.
- **testTitlesMirrorsForRightToLeftLayout** - Titles mirrors icon, label, and status geometry in both settings hosts for right-to-left locales.
- **testAppIconsMirrorsTileOrderForRightToLeftLayout** - App Icons mirrors tile order while preserving each tile's centered icon and label geometry.
- **testHostResizePreservesFocusedLabelVisibility** - Resizing the host does not change which App Icons label is visible.
- **testTitlesToAppIconsShowsFocusedLabelImmediately** - Resolving App Icons after Titles immediately includes the focused label state.
- **testRepeatedStyleSwitchingDoesNotRetainHighlightGeometry** - Repeated App Icons and Titles resolution always restores the same style-specific highlight.
- **testTahoeVisualDecisionsMatchLiveSwitcher** - Tahoe selects clear glass only for App Icons and keeps live panel shadow and font-weight decisions.
- **testLegacyVisualDecisionsMatchLiveSwitcher** - Pre-Tahoe previews use the live frosted fallback, regular fonts, shadows, and legacy radii.
