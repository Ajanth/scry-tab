# KeyboardEvents (sequencing) — Specs

> **Line coverage:** `KeyboardEventsTestable.swift` 65% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

Global hotkey handling has to make sense of a *stream* of key-down / key-up / modifier events that the
OS doesn't always deliver cleanly. `KeyboardEventsTestable` is the state machine that interprets those
sequences — deciding when to summon the switcher, cycle, act on a window, or dismiss — and stays robust
when events are missing or arrive out of order. The suite feeds it canned event sequences and asserts
the resulting actions.

## Behavior & edge cases

- The common flows (hold modifier → press next-window key → release) resolve to the expected
  summon/cycle/focus actions.
- **Missing events**: when an expected event is dropped, the machine recovers where it safely can
  ("save the day") and otherwise degrades predictably ("can not save the day").
- **Out-of-order events** are tolerated.
- In-switcher shortcuts (close window) act on the selection.
- Release behavior depends on style: `doNothingOnRelease` doesn't focus; the search-on-release path does
  **not** focus the window on release (it enters search instead).
- Switching directly from one shortcut slot to another is handled.
- **Escape**: the permanent HID tap listens only for modifier changes and can never block input. A separate
  absorbing HID tap exists only for an active switcher session with an Escape binding. If macOS disables
  that tap or its installation fails, it fails open for the rest of the session and retries only in the next
  session without changing the app's Accessibility permission state.
- Dynamic direct Focus Set IDs remain stable while configured and are never reused after deletion,
  so a delayed stale Carbon event cannot target a different set.
- Direct Focus Set bindings dispatch only on non-modifier key-down. Their shared chord lifecycle
  watches the same modifier path as Controls and applies release behavior only after the final
  bound modifier is released.
- While a direct Focus Set chord is held, local controls accept its modifiers just as they accept
  a numbered shortcut's held modifiers, so Search and Escape remain available.
- Focus Sets use their own persisted release setting, never a numbered shortcut override or the
  ordinary global shortcut setting.

## Test scenarios

Mirrors `KeyboardEventsTests.swift` 1:1.

- **testDynamicFocusSetHotkeyIdsAreStableAndNeverReusedAfterDeletion** — dynamic IDs remain stable
  across reconciliation and a deleted ID is not assigned to a later Focus Set.
- **testDirectFocusSetShortcutFiresOnlyOnKeyDown** — a direct Focus Set binding ignores its Carbon
  key-up, preserving repeated press-key cycling while modifiers remain held.
- **testFocusSetsPresentationUsesDedicatedReleaseBehavior** — Focus Sets resolves Focus, Hold, and
  Search from its dedicated setting rather than the numbered-shortcut base setting.
- **testDirectFocusSetChordReleaseWaitsForFinalModifier** — a direct Focus Set chord stays armed
  while a bound modifier remains held, then reports its exact release once.
- **testDirectFocusSetChordKeepsLocalShortcutsActive** — local Search and Cancel continue to match
  while a direct Focus Set chord’s modifiers are held.
- **testEscapeTapStaysInactiveOutsideSwitcherSession** — an Escape binding alone never installs
  the absorbing tap while the switcher is inactive.
- **testEscapeTapDoesNotInstallForSessionWithoutEscapeBinding** — starting a session without an
  Escape binding leaves the absorbing tap uninstalled.
- **testEscapeTapInstallsForSessionWithEscapeBinding** — starting a session with an Escape binding
  installs the absorbing tap.
- **testEscapeTapReconfigurationStartsAndStopsTapDuringSession** — adding or removing the Escape
  binding during a session installs or removes the tap immediately.
- **testDisabledEscapeTapFailsOpenForRemainderOfSession** — a timeout or user-input disable removes
  the tap and configuration changes cannot reinstall it during the same session.
- **testEscapeTapSessionEndResetsFailedState** — ending the session resets a failed tap lifecycle.
- **testEscapeTapRetriesInstallationInNextSession** — the session after a failure can install a
  fresh Escape tap.
- **testCurrentEscapeTapCallbackTokenIsAccepted** — queued work from the current nonzero tap token
  is accepted, while the reserved zero token is never accepted.
- **testReplacedEscapeTapCallbackTokenIsRejectedWithinSession** — queued work from a tap replaced
  during the same session cannot affect its replacement.
- **testPriorSessionEscapeTapCallbackTokenIsRejected** — queued work from a prior session cannot
  affect the current session.
- **testAdmittedUnconfiguredProcessDoesNotRestoreNativeSymbolicHotkeys** — an admitted process that
  did not finish keyboard configuration leaves native symbolic hotkeys unchanged at shutdown.
- **testAdmittedConfiguredProcessRestoresNativeSymbolicHotkeys** — an admitted process restores
  native symbolic hotkeys after keyboard configuration completes.
- **testRejectedDuplicateDoesNotRestoreNativeSymbolicHotkeys** — a rejected duplicate never changes
  native symbolic hotkeys while terminating.
- **testMostCommonSequence** — the canonical hold-modifier → next-window → release flow.
- **testSecondMostCommonSequence** — the second-most-common hold-modifier flow resolves correctly.
- **testSecondMostCommonSequenceVariation** — a variation of that flow resolves correctly.
- **testSequenceWithMissingEventAndWeCanSaveTheDay** — a dropped event the machine can recover from.
- **testSequenceWithMissingEventAndWeCanNotSaveTheDay** — a dropped event it can't recover from → predictable degradation.
- **testOutOfOrderEvents** — events arriving out of order are handled.
- **testCloseWindowShortcut** — the close-window shortcut acts on the selection mid-session.
- **testOnReleaseDoNothing** — `doNothingOnRelease` style: releasing the modifier doesn't focus.
- **testOnReleaseToggleSearchModeDoesNotFocus** — search-on-release: releasing enters search, doesn't focus the window.
- **testTransitionFromOneShortcutToAnother** — switching slots mid-stream is handled.
- **testEscapeFiresCancelShortcutWhileSwitcherActiveWithOptionHeld** — Escape → cancel while active.
- **testEscapeDoesNothingWhenSwitcherIsClosed** — Escape is a no-op when the switcher is closed.

### Adjacent: `NSEvent.ModifierFlags.cleaned()` (defined in `ATShortcut.swift`, exercised here)

AppKit's local event monitors occasionally emit modifier flags with extra bits (function-key bit, raw `0x120`-style garbage). `cleaned()` is the intersection that strips them before the matcher sees them. Tested here as the closest existing home until an `ATShortcutTests.swift` lands.

- **testCleanedKeepsValidModifierBits** — `[.command, .shift, .option, .control, .capsLock]` survives cleaning.
- **testCleanedDropsFunctionAndUnknownBits** — `.function` and stray bits like `0x120` are dropped.
- **testCleanedEmptyIsEmpty** — empty flags stay empty.
