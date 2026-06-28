# SettingsSearchFocus — Specs

## Summary

Resolves control-granularity search routing for migrated Settings pages.

- `SettingsFocusRegistry` maps a stable anchor identifier (the `SettingsSearchDescriptor.id`)
  to the live `NSView` for the matching control, retaining it weakly so window teardown can't
  create a dangling reference.
- `SettingsRowView.registerFocusAnchor` links a row to a descriptor id and records the optional
  focal control to keyboard-focus on navigation.
- `SettingsWindow.navigate(to:focusing:)` carries a one-shot anchor id through `navigate(to:)`;
  `resolvePendingFocusAnchor` consumes it after the destination page is shown by scrolling the
  anchor into view, applying a temporary selection-tinted pulse, and making the focal control
  first responder when one was declared.

## Behavior & edge cases

- Anchor identifiers live in a single flat namespace keyed by the descriptor id, which is
  globally unique (`"<page>-<control>"`).
- The registry stores weak references; resolving an id after the window closes returns nil and
  the navigation no-ops rather than crashing.
- `unregisterPrefix` removes every anchor whose id begins with the supplied prefix; pages call
  it on cleanup and on rebuild so a rebuilt page never publishes stale anchors for removed rows.
- `pendingFocusID` is one-shot: `resolvePendingFocusAnchor` nils it after consuming so a later
  plain navigation does not re-highlight a previously focused control.
- When the anchor view has no window (page not yet built, or already torn down) the focus
  resolution is a no-op.
- A plain `navigate(to:)` call (no `focusing:` argument) leaves `pendingFocusID` untouched so
  search-result focus never fires from a sidebar-only navigation; the id is only seeded by
  `navigate(to:focusing:)`.

## Test scenarios

Mirrors `SettingsSearchFocusTests.swift` 1:1.

- **testRegistryRetainsLiveViewAndReleasesOnTeardown** — a registered id resolves to the live
  view; after the view is released the same id resolves to nil.
- **testUnregisterPrefixRemovesOnlyMatchingAnchors** — unregistering a page prefix clears that
  page's anchors but leaves unrelated anchors intact.
- **testRowRegisterFocusAnchorStoresMetadataAndPublishesRow** — `registerFocusAnchor` stores the
  anchor id and focal control on the row and publishes the row into the registry under that id.
- **testPhase3MigratedDescriptorAnchorsUseRegisteredIds** — Controls and Exceptions search
  descriptors share anchor ids with their migrated pages.
- **testRegisterReplacesPriorAnchorViewForSameId** — re-registering an id swaps the resolved
  view to the new one so a rebuilt page never publishes stale anchors.
- **testClearRemovesEveryAnchor** — `clear` empties the registry entirely.
