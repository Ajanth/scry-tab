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
- **Escape**: while the switcher is active (e.g. Option held), Escape fires the cancel shortcut; when the
  switcher is closed, Escape does nothing (ScryTab doesn't swallow it).
- **Open Focus Sets**: the standalone global shortcut has a dedicated Carbon ID after the numbered
  press/release IDs and dispatches only on key-down.

## Test scenarios

Mirrors `KeyboardEventsTests.swift` 1:1.

- **testOpenFocusSetsShortcutUsesDedicatedHotkeyIdAndFiresOnlyOnKeyDown** — the static shortcut uses
  `2 * maxShortcutCount` and ignores its key-up event.
- **testPickerTextKeyPassesToSearchField** — ordinary picker text input, including Space, bypasses
  shortcut dispatch.
- **testPickerVimKeyRunsRegisteredLocalShortcut** — an unmodified registered Vim key bypasses the
  picker search field and dispatches its existing local cycle action; its key-up passes through
  without a second action.
- **testPickerModifiedVimKeysPassToSearchField** — shifted and Command-modified Vim letters retain
  native picker search-field handling.
- **testPickerModifierChangeWithoutEventBypassesShortcuts** — eventless modifier changes bypass
  shortcut dispatch while the picker is key, preventing Shift-only shortcuts from firing during
  typed search.
- **testHidEscapeBypassesFocusSetPicker** — the HID Escape interception leaves the picker’s native
  Escape and IME-composition behavior intact.
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

## Adjacent: `NSEvent.ModifierFlags.cleaned()` (defined in `ATShortcut.swift`, exercised here)

AppKit's local event monitors occasionally emit modifier flags with extra bits (function-key bit, raw `0x120`-style garbage). `cleaned()` is the intersection that strips them before the matcher sees them. Tested here as the closest existing home until an `ATShortcutTests.swift` lands.

- **testCleanedKeepsValidModifierBits** — `[.command, .shift, .option, .control, .capsLock]` survives cleaning.
- **testCleanedDropsFunctionAndUnknownBits** — `.function` and stray bits like `0x120` are dropped.
- **testCleanedEmptyIsEmpty** — empty flags stay empty.
