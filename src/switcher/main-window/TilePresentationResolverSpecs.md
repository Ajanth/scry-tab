# TilePresentationResolver — Specs

## Summary

Resolves geometry for reusable non-window `TileView` presentation cells without reading or
mutating the selected profile.

## Behavior & edge cases

- An explicit presentation style wins over the profile style.
- Window-backed tiles omit the override and retain profile-driven behavior.
- Titles use the complete cell highlight and the title icon size, even under an app-icons profile.

## Test scenarios

- **testForcedTitlePresentationOverridesAppIconsProfile** — a forced title presentation overrides
  an app-icons profile while an ordinary tile still follows that profile.
- **testTitleHighlightCoversCompleteCell** — title highlights cover the complete title row.
- **testTitleIconIgnoresAppIconMinimumTileWidth** — title icons do not inherit app-icons minimum
  tile sizing.
- **testAppIconGeometryPreservesRoundedMinimumSizing** — ordinary app-icons retain their established
  rounded minimum-tile geometry.
