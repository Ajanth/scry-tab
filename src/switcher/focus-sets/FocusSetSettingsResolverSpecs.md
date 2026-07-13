# FocusSetSettingsResolver — Specs

## Summary

`FocusSetSettingsResolver` is a Foundation-only adapter between the live selectable-application
inventory and persisted `FocusSetRule` values. It exposes an opaque stable identity for selection
state while picker rows carry only presentation names, selection, and availability for settings UI.
It also resolves Focus Set deletion, reordering, and selection after model changes.

## Behavior & edge cases

- A picker row represents one non-blank stable application identity. The first live option and the
  first saved rule for an identity win deterministically.
- Saved rules are selected. A live match updates their presentation name and marks them available;
  an unmatched saved rule remains selected with its cached name and `isAvailable == false`.
- Selected rows precede unselected available rows. Each group uses localized-standard name ordering,
  with the stable identity as a deterministic tie-breaker.
- Picker search trims its query and matches presentation names case- and diacritic-insensitively.
- Blank stable identities never produce rows or rewritten rules. A selected identity unknown to
  both the live inventory and saved rules cannot produce a user-presentable rule.
- Rewritten rules use the current live presentation name when possible, otherwise retain the saved
  cached name. They are app-only rules: `titleContains` is always `nil`.
- Included-application totals count unique non-blank stable identities rather than rule records.
- Deletion requires an existing stable Focus Set UUID, preserves configuration metadata and the
  order of every other set, and cannot leave the removed UUID in a subsequent direct shortcut
  binding snapshot.
- A saved Focus Set can move by a nonzero offset only when its destination exists; an unknown set,
  zero offset, or out-of-range destination leaves the saved order unchanged.
- Applying an editor draft replaces name, application rules, and optional shortcut in one immutable
  configuration decision. If the user approved replacing another Focus Set's shortcut, that
  conflicting binding is cleared in the same decision without changing its membership.
- Category-search registration keeps manager and Behavior terms associated with their own segments
  and clears every registration when the tab closes.

---

## Test scenarios

### A. Application selection rows
- **testPickerRowsPlaceSelectedAppsBeforeOtherAvailableApps** — selected applications precede other available applications while both groups remain alphabetical.
- **testPickerRowsKeepUnavailableSavedApplicationsSelected** — a selected saved application remains editable when it is no longer available live.
- **testPickerRowsDeduplicateIdentitiesAndIgnoreBlankIdentifiers** — duplicate identities retain the first live name while blank live and saved identities disappear.
- **testPickerRowsOmitFallbackBundleIdentifierAsPresentationName** — a cached fallback that is only the stable identity cannot become a picker label.
- **testPickerRowsUseDeterministicLocalizedStandardOrder** — localized-standard names and stable identities make the picker order reproducible.
- **testPickerRowsFilterNamesCaseAndDiacriticInsensitively** — picker search trims its query and matches presentation names regardless of case or diacritics.
- **testIncludedApplicationCountDeduplicatesRulesAndIgnoresBlankIdentifiers** — included-app totals count each valid stable identity once.

### B. Rule conversion
- **testRulesUseLiveNameAndRemainAppOnly** — a live presentation-name change refreshes the cached name and emits an app-only rule.
- **testRulesRetainSavedNameForSelectedUnavailableApplication** — a selected unavailable application retains its previously saved presentation name.
- **testRulesDropDeselectedApplications** — deselecting an existing application removes only that app from the rewritten rules.

### C. Focus Set deletion
- **testDeletingFocusSetRemovesOnlyRequestedStableIdentifier** — deletion removes only the requested stable UUID and no direct binding can target it.
- **testDeletingFocusSetRejectsUnknownStableIdentifier** — an unknown stable UUID cannot produce a deletion configuration.

### D. Focus Set reordering
- **testMovedFocusSetsSwapsAdjacentSets** — moving a saved Focus Set swaps it with the adjacent destination.
- **testMovedFocusSetsRejectsMissingOrInvalidDestinations** — unknown, zero-offset, and out-of-range moves preserve the saved order.

### E. Focus Set selection
- **testSelectedFocusSetIdentifierKeepsExistingSet** — an existing selection remains selected instead of falling back to the first set.
- **testSelectedFocusSetIdentifierFallsBackToFirstRemainingSet** — deleting the selected set selects the first remaining set.
- **testSelectedFocusSetIdentifierClearsAfterDeletingLastSet** — deleting the final set produces no selection.

### F. Transactional editor decisions
- **testSavingFocusSetCommitsCompleteDraftAtomically** — Apply replaces name, applications, and shortcut together while preserving metadata and ordering.
- **testSavingFocusSetUnassignsConflictingDirectBindingWithoutChangingMembership** — an approved direct-shortcut conflict is cleared on the other set without changing its rules.

### G. Category search registration
- **testCategorySearchRegistrationHighlightsMatchingSegmentAndClearsOnCleanup** — Behavior and Focus Sets terms select their matching segment, then teardown clears the registration.
