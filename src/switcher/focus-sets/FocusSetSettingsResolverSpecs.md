# FocusSetSettingsResolver — Specs

## Summary

`FocusSetSettingsResolver` is a Foundation-only adapter between the live selectable-application
inventory and persisted `FocusSetRule` values. It exposes an opaque stable identity for selection
state while picker rows carry only presentation names, selection, and availability for settings UI.
It also reconciles the selected Focus Set identifier after model changes so settings never retains
a deleted selection.

## Behavior & edge cases

- A picker row represents one non-blank stable application identity. The first live option and the
  first saved rule for an identity win deterministically.
- Saved rules are selected. A live match updates their presentation name and marks them available;
  an unmatched saved rule remains selected with its cached name and `isAvailable == false`.
- Selected rows precede unselected available rows. Each group uses localized-standard name ordering,
  with the stable identity as a deterministic tie-breaker.
- Blank stable identities never produce rows or rewritten rules. A selected identity unknown to
  both the live inventory and saved rules cannot produce a user-presentable rule.
- Rewritten rules use the current live presentation name when possible, otherwise retain the saved
  cached name. They are app-only rules: `titleContains` is always `nil`.

---

## Test scenarios

### A. Application picker rows
- **testPickerRowsPlaceSelectedAppsBeforeOtherAvailableApps** — selected applications precede other available applications while both groups remain alphabetical.
- **testPickerRowsKeepUnavailableSavedApplicationsSelected** — a selected saved application remains editable when it is no longer available live.
- **testPickerRowsDeduplicateIdentitiesAndIgnoreBlankIdentifiers** — duplicate identities retain the first live name while blank live and saved identities disappear.
- **testPickerRowsOmitFallbackBundleIdentifierAsPresentationName** — a cached fallback that is only the stable identity cannot become a picker label.
- **testPickerRowsUseDeterministicLocalizedStandardOrder** — localized-standard names and stable identities make the picker order reproducible.

### B. Rule conversion
- **testRulesUseLiveNameAndRemainAppOnly** — a live presentation-name change refreshes the cached name and emits an app-only rule.
- **testRulesRetainSavedNameForSelectedUnavailableApplication** — a selected unavailable application retains its previously saved presentation name.
- **testRulesDropDeselectedApplications** — deselecting an existing application removes only that app from the rewritten rules.

### C. Focus Set selection
- **testSelectedFocusSetIdentifierKeepsExistingSet** — an existing selection remains selected instead of falling back to the first set.
- **testSelectedFocusSetIdentifierFallsBackToFirstRemainingSet** — deleting the selected set selects the first remaining set.
- **testSelectedFocusSetIdentifierClearsAfterDeletingLastSet** — deleting the final set produces no selection.
