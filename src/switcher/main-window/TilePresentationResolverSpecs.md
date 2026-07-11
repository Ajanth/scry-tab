# TilePresentationResolver — Specs

## Summary

Resolves geometry for reusable non-window `TileView` presentation cells without reading or
mutating the active presentation source.

## Behavior & edge cases

- An explicit presentation style wins over the active style.
- Window-backed tiles omit the override and retain presentation-driven behavior.
- Titles use the complete cell highlight and the title icon size, even under an app-icons style.

## Test scenarios

- **testForcedTitlePresentationOverridesAppIconsProfile** — a forced title presentation overrides
  an app-icons style while an ordinary tile still follows the active style.
- **testTitleHighlightCoversCompleteCell** — title highlights cover the complete title row.
- **testTitleIconIgnoresAppIconMinimumTileWidth** — title icons do not inherit app-icons minimum
  tile sizing.
- **testAppIconGeometryPreservesRoundedMinimumSizing** — ordinary app-icons retain their established
  rounded minimum-tile geometry.
