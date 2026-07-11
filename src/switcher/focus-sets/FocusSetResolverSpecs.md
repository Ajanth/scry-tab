# FocusSetResolver — Specs

## Summary

`FocusSetsConfiguration`, `FocusSet`, and `FocusSetRule` are Foundation-only Codable values for
the separate Focus Sets persistence layer. A Focus Set can carry an optional direct-shortcut key
equivalent, and `FocusSetShortcutBindingResolver` maps it to an action identifier containing the
exact stable set UUID. `FocusSetResolver` compiles application bundle identifiers into one
immutable snapshot and decides whether an app belongs to a requested scope.

V3 compares non-empty bundle identifiers exactly. Rule display names are presentation-only and
`titleContains` remains stored but deliberately inert. There is no process, window, AppKit,
Accessibility, or preference dependency.

## Behavior & edge cases

- **`.none` and `.allWindows`** always pass, including apps without a stable bundle identifier.
- **`.set(id:)`** passes only an app whose exact non-empty bundle identifier occurs in that set.
  Unknown, empty, and missing identifiers do not match a selected set.
- **`.unassigned`** is the inverse of the union of all valid saved app membership. Apps without a
  stable bundle identifier cannot be assigned to a saved set, so they are unassigned.
- Rules in one set use OR semantics. Overlap between separate sets is intentional.
- Empty sets and stale set identifiers safely produce no selected membership.
- Empty persisted rule identifiers are ignored by the resolver, protecting matching before the
  persistence store can reject malformed rules.
- Direct shortcut bindings exist only for non-empty saved values. Their action identifier decodes
  to the exact saved UUID, so a stale deleted identifier cannot alias a retained set.

---

## Test scenarios

### A. Model persistence
- **testConfigurationDefaultsToCurrentVersionAndEmptyValues** — a default configuration uses the current version with no saved sets.
- **testConfigurationRoundTripsThroughJSONForPersistence** — every model field survives JSON encoding and decoding.
- **testConfigurationEncodingContainsOnlyStableFocusSetFields** — encoded configuration contains only stable Focus Set fields.

### B. Unconstrained scopes
- **testNoScopeIncludesAppsWithAndWithoutBundleIdentifiers** — `.none` passes identified, missing, and empty bundle identifiers.
- **testAllWindowsIncludesAppsWithAndWithoutBundleIdentifiers** — `.allWindows` passes identified, missing, and empty bundle identifiers.

### C. Selected Focus Set membership
- **testSetScopeIncludesAllWindowsFromSelectedApp** — a selected app's exact identifier passes for every app-membership check.
- **testSetScopeMatchesOnlyExactBundleIdentifiers** — matching is case-sensitive and never uses prefixes or suffixes.
- **testSetScopeRejectsMissingBundleIdentifiers** — selected sets reject nil and empty bundle identifiers.
- **testRulesWithinASetUseOrSemantics** — any valid rule in a selected set can include an app.
- **testCachedApplicationNameDoesNotAffectMembership** — cached display names never substitute for a bundle identifier.
- **testTitleContainsDoesNotNarrowV1AppMembership** — stored title fragments do not affect V1 matching.

### D. Unassigned and overlap
- **testUnassignedExcludesAppsInEverySavedFocusSet** — apps in any saved set are excluded while unrelated identified apps pass.
- **testUnassignedIncludesAppsWithoutBundleIdentifiers** — missing and empty identifiers count as unassigned.
- **testOverlappingSetsIncludeSharedAppsInEachScope** — a shared app passes in each selected overlapping set and is not unassigned.

### E. Invalid and empty membership
- **testEmptySetProducesNoSelectedMembership** — an empty set matches no selected apps and leaves identified apps unassigned.
- **testUnknownSetProducesNoMembership** — a stale set identifier does not fall back to another saved set.
- **testBlankRuleBundleIdentifierIsIgnored** — a blank persisted rule identifier creates no assigned membership.
- **testResolverRetainsItsCompiledSnapshot** — previously compiled resolver facts remain independent of a later configuration snapshot.

### F. Direct shortcut bindings
- **testShortcutBindingsResolveSavedIdentifiersAndSkipMissingValues** — binding resolution emits only configured shortcuts with exact stable action identifiers.
- **testShortcutActionIdentifierPreservesExactStableIdentifier** — action identifiers decode only their embedded UUID and malformed values cannot alias another set.
