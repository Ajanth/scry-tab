# FocusSetPickerResolver — Specs

## Summary

`FocusSetPickerResolver` is a Foundation-only picker-state kernel. It snapshots a
`FocusSetsConfiguration`, profile-scoped candidate counts, and caller-provided built-in display
names, then exposes stable Focus Sets picker items without accessing AppKit, localization storage,
preferences, or live window state.

`FocusSetPickerItemName` retains semantic built-in names (`allWindows` and `unassignedWindows`)
instead of localized text. The UI translates those semantics, while the resolver uses the injected
names only to search built-in entries.

## Behavior & edge cases

- Every snapshot starts with an `All Windows` item, then retains unique saved Focus Sets in their
  persisted configuration order, and finally appends `Unassigned Windows` only when its supplied
  profile-scoped count is positive.
- `availableScopes` is derived from the same unfiltered snapshot rows that the picker renders.
  `isScopeAvailable` lets an active child grid validate only its scope: All Windows and configured
  saved sets remain available, while Unassigned requires a visible candidate.
- Each item carries an opaque stable identifier, its `FocusSetScope`, a semantic or saved
  presentation name, and a non-negative candidate count. Missing and invalid negative count facts
  become zero.
- A malformed duplicate saved identifier retains only its first configured item, so each picker
  identifier maps to one deterministic scope.
- Query matching is case- and diacritic-insensitive substring matching over saved names and
  caller-provided built-in names. An empty query preserves the full snapshot.
- Selection-index clamping safely handles no selection, negative indexes, too-large indexes, and
  empty visible lists. Previous/next navigation cycles within a non-empty visible list.
- Confirmation requires the exact stable identifier to occur in the currently visible query
  results. A filtered-out, stale, or deleted Focus Set identifier returns no item or scope and
  never falls through to another set's index.

---

## Test scenarios

### A. Picker item snapshots
- **testEmptyConfigurationContainsOnlyAllWindows** — an empty configuration still exposes the
  unfiltered All Windows item and its count.
- **testItemsKeepAllWindowsThenSavedSetsInConfigurationOrder** — All Windows precedes saved sets,
  whose persisted order, scopes, semantic names, identifiers, and counts remain intact.
- **testUnassignedWindowsAppearsOnlyWithPositiveProfileScopedCount** — Unassigned Windows appears
  last only when the profile-scoped input count is positive, and absent rows do not become
  available scopes.
- **testActiveScopeAvailabilityMatchesPickerRows** — active-grid validation follows the same row
  rules: All Windows and configured sets remain available, while Unassigned requires a candidate.
- **testItemsUseSafeZeroCountsWhenCountFactsAreMissingOrNegative** — missing and invalid negative
  count facts safely become zero and cannot make Unassigned Windows appear.
- **testDuplicateSetIdentifiersKeepFirstConfiguredItem** — malformed repeated set identifiers keep
  the first configured presentation, ensuring a one-to-one stable selection identifier.
- **testResolverRetainsItsConfigurationOrderSnapshot** — a resolver's item order remains fixed
  after another configuration snapshot is built.

### B. Filtering
- **testFilterMatchesSavedSetNamesCaseAndDiacriticInsensitively** — saved set names use
  case- and diacritic-insensitive substring search.
- **testFilterMatchesInjectedBuiltInNamesCaseAndDiacriticInsensitively** — caller-provided
  localized built-in names use the same matching rules without loading localization in the core.
- **testEmptyFilterKeepsEveryPickerItem** — an empty query returns every item in stable snapshot
  order.

### C. Selection navigation
- **testSelectionIndexClampsToVisibleItemBounds** — selection indexes clamp safely to visible
  bounds and return no selection when there are no visible items.
- **testNavigationCyclesWithinVisibleItemBounds** — previous/next navigation wraps at either edge
  and establishes an edge selection when none exists.

### D. Confirmation safety
- **testConfirmationRequiresAnExactCurrentlyVisibleIdentifier** — confirmation succeeds only for
  an exact stable identifier that is still visible under the active query.
- **testStaleSetIdentifierNeverConfirmsAReplacementSet** — a deleted identifier never selects a
  replacement item that happens to occupy a similar position.
