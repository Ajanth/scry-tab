# FocusSetSessionResolver — Specs

## Summary

`FocusSetSessionResolver` is the Foundation-only Phase 3 lifecycle kernel for the Focus Sets
picker and its child grid. It accepts immutable session state, a routed event, and the current
picker-scope snapshot, then returns the next state and the App operation that realizes it. It owns
no panels, global state, search-mode logic, shortcut-profile selection, or window filtering.

## State and integration contract

- `FocusSetPickerScope` represents only selectable picker rows: All Windows, a saved set, or
  Unassigned Windows. It converts to `FocusSetScope`, but deliberately rejects `.none`.
- `FocusSetSessionState.focusSetGrid` always contains a picker scope and therefore always exposes a
  Focus Set scope plus `returnsToFocusSetPicker == true`.
- `FocusSetSessionState.ordinaryGrid` has no Focus Set scope and never returns to the picker.
- `FocusSetSessionInput` supplies the current state, one event, and the immutable set of scopes
  available in the current picker snapshot.
- `FocusSetSessionDecision.action` maps to orchestration operations such as showing or refreshing
  the picker, showing the child grid, returning to the picker, showing an ordinary grid, or
  dismissing switcher UI.
- `FocusSetSessionDecision.suppressFocusOnRelease` is a separate one-way signal. It is `true` only
  after an accepted picker confirmation so App can set its existing release guard without this
  resolver owning hold-key behavior.

## Behavior and safety

- Open Focus Sets moves idle or ordinary-grid state to the picker. Repeating it refreshes a visible
  picker and returns a Focus Sets child grid to that picker.
- Confirming a currently available picker scope opens the child grid with return-to-picker intent.
  Missing, stale, or out-of-phase confirmations are no-ops.
- Search decides first whether Escape is consumed. A consumed Escape changes no session state;
  otherwise Escape returns a Focus Sets child grid to the picker, dismisses the picker, and follows
  ordinary dismissal from an ordinary grid.
- Generic dismissal tears down every active state. This is intentionally distinct from Escape from a
  Focus Sets child grid, which returns to the picker.
- An ordinary shortcut or gesture always yields `ordinaryGrid`, clearing both Focus Set scope and
  return-to-picker intent.
- When the available-scope snapshot changes, a child grid whose current scope no longer exists
  returns safely to the picker. No stale scope can be confirmed or retained as an active child grid.
- A direct Focus Set shortcut creates a scoped grid with no picker-return intent. Its exact UUID
  must still exist in the current snapshot; stale invocations never fall back to another set, and
  deletion of its active set dismisses the direct session.

---

## Test scenarios

### A. Session-state boundaries
- **testPickerScopeMapsSelectableScopes** — every selectable picker scope converts losslessly to the shared scope.
- **testPickerScopeRejectsOrdinaryScope** — ordinary-only `.none` cannot become a picker selection.
- **testFocusSetGridCarriesScopeAndReturnIntent** — a Focus Sets child grid exposes scope and inherent return intent.
- **testOrdinaryGridCarriesNeitherFocusSetScopeNorReturnIntent** — an ordinary grid has neither Focus Set state nor return behavior.

### B. Open Focus Sets
- **testOpenFocusSetsFromIdleShowsPicker** — idle opens the first-level picker.
- **testRepeatedOpenFocusSetsRefreshesPicker** — repeated Focus Sets open refreshes the picker phase.
- **testOpenFocusSetsFromFocusSetGridReturnsToPicker** — repeated Focus Sets open returns its child grid to the picker.
- **testOpenFocusSetsFromOrdinaryGridShowsPicker** — Focus Sets open replaces an ordinary grid with the picker.

### C. Picker confirmation
- **testConfirmAvailableSetShowsChildGridAndSuppressesRelease** — an available saved set opens a child grid and sets the release-suppression output.
- **testConfirmAllWindowsKeepsReturnToPickerIntent** — All Windows remains a Focus Sets child flow with return intent.
- **testConfirmUnassignedCarriesUnassignedScope** — Unassigned Windows carries its exact scope into the child grid.
- **testConfirmMissingScopeKeepsPicker** — a missing selection leaves the picker visible without release suppression.
- **testConfirmStaleScopeKeepsPicker** — a stale picker row cannot open a grid or suppress a release.
- **testConfirmOutsidePickerDoesNothing** — confirmation is ignored outside the picker phase.

### D. Escape and dismissal
- **testConsumedEscapeLeavesFocusSetGridUntouched** — search-consumed Escape leaves the child grid unchanged.
- **testUnconsumedEscapeFromFocusSetGridReturnsToPicker** — post-search Escape returns a child grid to the picker.
- **testUnconsumedEscapeFromPickerDismissesSwitcher** — Escape from the picker dismisses the complete flow.
- **testUnconsumedEscapeFromOrdinaryGridDismissesSwitcher** — Escape from an ordinary grid follows ordinary dismissal.
- **testUnconsumedEscapeFromIdleDoesNothing** — idle Escape has no lifecycle effect.
- **testOutsideDismissalFromPickerDismissesSwitcher** — picker outside dismissal tears down the flow.
- **testNormalDismissalFromFocusSetGridDismissesSwitcher** — normal child-grid dismissal ends the session rather than returning.
- **testNormalDismissalFromOrdinaryGridDismissesSwitcher** — normal ordinary-grid dismissal ends the session.
- **testDismissWhenIdleDoesNothing** — idle dismissal is harmless.

### E. Ordinary entry points
- **testOrdinaryShortcutOrGestureFromPickerReplacesItWithOrdinaryGrid** — an ordinary entry replaces the picker with an unfiltered grid.
- **testOrdinaryShortcutOrGestureFromFocusSetGridClearsScopeAndReturnIntent** — an ordinary entry clears a child grid's scope and return intent.
- **testOrdinaryShortcutOrGestureFromIdleShowsOrdinaryGrid** — an ordinary entry from idle starts its normal grid.
- **testOrdinaryShortcutOrGestureWithinOrdinaryGridRemainsOrdinary** — repeated ordinary entry remains ordinary and unfiltered.

### F. Scope invalidation
- **testRemovedActiveScopeReturnsChildGridToPicker** — deleting the active scope safely returns the child grid to the picker.
- **testUnavailableUnassignedScopeReturnsChildGridToPicker** — a zero-candidate Unassigned row
  removed from the availability snapshot returns its child grid to the picker.
- **testAvailableActiveScopeKeepsChildGridOpen** — a still-available scope preserves the child grid.
- **testScopeChangeOutsideFocusSetGridDoesNothing** — scope snapshots do not mutate picker or ordinary state without user action.

### G. Direct Focus Set shortcuts
- **testDirectShortcutShowsScopedGridWithoutPickerReturnIntent** — a configured direct binding opens the ordinary grid with that set scope and no picker return behavior.
- **testStaleDirectShortcutDoesNotSelectAnotherSet** — a stale UUID is a no-op even when another saved set remains available.
- **testDeletedActiveDirectSetDismissesSwitcher** — deleting an active direct set or invoking its stale binding dismisses safely.
- **testOpenFocusSetsFromDirectGridShowsPicker** — explicitly opening the browser from a direct grid starts the picker as a new flow.
- **testDirectGridUsesOrdinaryExitAndReplacementBehavior** — Escape dismisses and an ordinary shortcut replaces a direct grid without picker state.
- **testDirectShortcutReleaseRequiresExactActiveSetAndProfilePermission** — release focuses only the exact active direct set when the selected profile allows focus-on-release and suppression is off.
