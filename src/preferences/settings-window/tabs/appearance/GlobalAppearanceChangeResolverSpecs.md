# GlobalAppearanceChangeResolver - Specs

## Summary

Shared Appearance controls normally write their new value before their extra action runs. The global controls use a
narrow action wrapper to capture the persisted value immediately before delegating that write.
`GlobalAppearanceChangeResolver.decide` compares the old and new values with whether the corresponding per-shortcut
setting has explicit overrides, then decides whether to do nothing, accept the change without a dialog, replay a
remembered override-reset choice, or ask whether to remove those overrides.

The confirmation dialog has a "do not ask again" suppression checkbox. When the user checks it, the dialog's own
button choice (remove overrides vs. keep them) is persisted and passed back in as `rememberedOverrideChoice`, so
later changes to any of the 4 global appearance controls replay that same choice without prompting again.

Only user control actions call this resolver. Programmatic and imported preference changes do not enter this flow.

## Test scenarios

### No-op actions
- **testNoOpClickSkipsWhenOverridesExist** - Clicking the current global value does not request confirmation even when matching overrides exist.
- **testMissingNewValueSkips** - A control action with no readable new value does not request confirmation.

### Changed values
- **testChangedValueAppliesWithoutConfirmationWhenNoOverridesExist** - A changed global value with no matching overrides applies without a dialog.
- **testChangedValueConfirmsWhenOverridesExist** - A changed global value with matching explicit overrides requests confirmation.
- **testPreviouslyMissingValueStillCountsAsChange** - A readable new value counts as a change when no previous value was available.

### Remembered override-reset choice
- **testRememberedChoiceReplaysRemovalWhenOverridesExist** - A changed value with matching overrides and a remembered "remove" choice replays that removal without a dialog.
- **testRememberedChoiceReplaysKeepWhenOverridesExist** - A changed value with matching overrides and a remembered "keep" choice replays keeping them without a dialog.
- **testRememberedChoiceIgnoredWithoutOverrides** - A remembered choice has no effect without matching overrides; the change still applies without a dialog.
