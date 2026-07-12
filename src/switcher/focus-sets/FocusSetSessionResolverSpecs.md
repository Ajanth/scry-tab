# FocusSetSessionResolver — Specs

## Summary

`FocusSetSessionResolver` is the Foundation-only lifecycle kernel for direct saved Focus Set
shortcuts. It accepts immutable session state, a routed event, and the configured Focus Set UUIDs,
then returns the next state and App operation. It owns no AppKit state, panels, search routing,
presentation-source selection, or window filtering.

## Behavior and safety

- A direct shortcut opens the ordinary switcher grid scoped to its exact saved set. Repeating that
  shortcut cycles its scoped selection.
- A stale shortcut never falls back to another saved set. Removing the set that owns the active
  direct session dismisses the switcher safely.
- A direct shortcut's non-modifier press opens or cycles its set. The shared chord lifecycle waits
  for every bound modifier to be released, then resolves the Focus Sets-global Focus, Hold, or
  Search action only for that exact active set.
- Escape dismisses a direct session after search has declined to consume it. An ordinary shortcut
  or gesture replaces the scoped grid with the ordinary unfiltered grid.

---

## Test scenarios

Mirrors `FocusSetSessionResolverTests.swift` 1:1.

- **testDirectGridCarriesSavedSetScope** — a direct grid exposes its saved-set membership scope,
  while an ordinary grid has none.
- **testRepeatedDirectShortcutCyclesScopedGrid** — repeating the active direct shortcut cycles
  its current scoped selection.
- **testDirectShortcutShowsScopedGrid** — a configured direct shortcut opens the standard grid
  scoped to that exact saved set.
- **testStaleDirectShortcutDoesNotSelectAnotherSet** — a stale UUID is a no-op even when another
  saved set remains configured.
- **testDeletedActiveDirectSetDismissesSwitcher** — removing the active set or invoking its stale
  binding dismisses safely.
- **testDirectShortcutReleaseRequiresExactActiveSetAndFocusSetsBehavior** — release resolves
  Focus, Hold, or Search only for the exact active direct set and only when suppression is off.
- **testDirectShortcutChordLifecycleWaitsForFinalModifierRelease** — repeated press-key events
  retain the chord, partial modifier release is inert, a newer direct binding replaces a stale
  owner, and the final release fires once.
- **testDirectGridUsesOrdinaryExitAndReplacementBehavior** — Escape dismisses and an explicit
  ordinary entry replaces a direct grid without a return phase.
