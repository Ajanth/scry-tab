# SettingsRoute — Specs

## Summary

Models Settings navigation independently from AppKit view construction.

- `SettingsRoute` identifies top-level Settings pages and nested destinations.
- `SettingsNavigationController` tracks the current route plus the previous non-search route so
  leaving search can restore the user's prior page.
- `SettingsPageShellMetadata` defines shell-only grouping, icon, and base color decisions without
  constructing AppKit views.
- `ApplicationInterfaceAppearancePreference` is Settings-owned and resolves independently from the
  switcher appearance theme.
- `SettingsSearchDescriptor` stores route-aware searchable metadata without retaining an `NSView`
  or page controller. Dynamic values are read through a provider at match time.

## Behavior & edge cases

- The Settings sidebar groups Appearance, Controls, General, and Exceptions under ScryTab, with
  About under Application.
- Page metadata supplies the fixed Phase 2 icon kind and semantic base color for each top-level
  page.
- Application-interface appearance resolves to system, light Aqua, or dark Aqua on macOS versions
  that support dark mode.
- On older systems without dark mode, every Settings application-interface choice resolves to light
  Aqua.
- Initializing navigation with a search route normalizes to Appearance because search needs a real
  non-search page to restore to.
- Navigating to a non-search route updates both the selected route and previous non-search route.
- Starting search preserves the route that was selected before search.
- Clearing search restores the previous non-search route.
- A controls deep link to a deleted shortcut normalizes to the Controls root route.
- A controls deep link to an existing shortcut preserves its requested pane.
- Search descriptors include dynamic provider values in their searchable strings.
- Descriptor matching returns only matching descriptors, ordered by strongest score.
- Descriptor matching can be grouped by page in caller-provided page order while preserving
  per-page score ordering.

## Test scenarios

Mirrors `SettingsRouteTests.swift` 1:1.

- **testShellGroupsProductPagesUnderScryTabAndAboutUnderApplication** — Phase 2 top-level sidebar grouping puts product pages under ScryTab and About under Application.
- **testShellMetadataDefinesPageIconsAndBaseColors** — each top-level page exposes the icon and base color required by the Settings shell.
- **testApplicationInterfaceAppearanceResolvesIndependentlyFromSwitcherTheme** — Settings appearance choices resolve without consulting the switcher theme.
- **testApplicationInterfaceAppearanceFallsBackToLightWithoutDarkMode** — macOS versions before dark mode use light Aqua for every Settings appearance choice.
- **testInitialSearchRouteNormalizesToAppearance** — a search route cannot be the initial restore route, so navigation starts on Appearance.
- **testNavigateUpdatesPreviousNonSearchRoute** — navigating to a normal page updates the selected and previous non-search routes.
- **testSearchPreservesPreviousNonSearchRoute** — starting search stores the route that was active before search.
- **testEmptySearchRestoresPreviousNonSearchRoute** — empty or whitespace search restores the previous non-search route.
- **testDeletedShortcutRouteFallsBackToControlsRoot** — a stale shortcut deep link normalizes to the Controls root route.
- **testExistingShortcutRouteKeepsPane** — a valid shortcut deep link keeps its stable ID and requested pane.
- **testDescriptorSearchableStringsIncludeDynamicValues** — descriptor searchable strings include title, subtitle, keywords, and current provider values.
- **testDescriptorMatcherReturnsSortedMatches** — descriptor matching filters non-matches and sorts matches by score.
- **testDescriptorMatcherGroupsMatchesByPageOrder** — grouped descriptor matching emits page buckets in caller-provided page order.
