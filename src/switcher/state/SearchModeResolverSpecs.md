# SearchModeResolver — Specs

> **Line coverage:** `SearchModeResolver.swift` 100% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

The in-switcher **Search** feature lets the user filter the window list by typing. `SearchModeResolver`
is the pure decision kernel for its state machine, extracted from `TilesView` (same pattern as
`SelectionResolver`). It decides *what should happen*; `TilesView` and `ShortcutAction` carry out the
AppKit side effects (make the search field first responder, place the caret, refresh the UI, toggle
the Edit menu, call `App.cycleSelection`).

### The three modes

- **`.off`** — no search field interaction; the switcher behaves normally.
- **`.editing`** — the search field is the first responder and editable; typing filters the list.
- **`.locked`** — the query is frozen and the field is read-only; focus moves to the selected
  tile so arrow keys navigate results while the filter stays put.

### How you enter search (this decides Escape's behavior)

- **Started in search** — the session began in search because the triggering shortcut uses the
  `.searchOnRelease` style. Search *is* the session.
- **Toggled mid-session** — a normal session where the user pressed the search shortcut to turn search on.

## Behavior & edge cases

- **Escape is contextual** (the headline interaction): if search was *toggled mid-session*, Escape
  exits search back to the normal switcher (a second Escape then closes it). If the session *started
  in search*, Escape closes the whole switcher immediately — there's no "normal switcher" to fall back to.
- **Refresh only from `.off`**: entering editing refreshes the UI only when coming from `.off`
  (`enterEditing(refreshUi:)` carries the original `wasOff` flag); re-entering from `.locked` does not.
- **Key routing precedence** (while editing): IME-composing or an open context menu wins first (never
  steal composing keystrokes) → arrows drive selection → Tab is swallowed → the cancel/lockSearch/focus
  shortcuts pass to the shortcut pipeline → everything else (typed text, **cmd+A/C/V/X**) goes to the
  `NSSearchField`, which handles select-all/copy/paste/cut natively. ScryTab does not intercept those.
- **Field editability** tracks mode exactly: editable iff `.editing`.
- **Not modeled here** (stays in `TilesView` as side effects): caret placement, first-responder
  changes, `forceDoNothingOnRelease`, hover clearing, key-repeat-timer stops, the Edit-menu toggle, and
  `endSearchSession` teardown (which unconditionally resets to `.off` and is distinct from `disable`).

---

## Test scenarios

Mirrors `SearchModeResolverTests.swift` 1:1.

### A. Session entry
- **testEntryStartedInSearchBeginsEditing** — `startMode(startInSearch: true)` → `.editing`.
- **testEntryNormalSessionStartsOff** — `startMode(startInSearch: false)` → `.off`.

### B. Toggle route (search shortcut)
- **testToggleFromOffEntersEditing** — `.off` → `.enterEditing`.
- **testToggleFromEditingDisables** — `.editing` → `.disable`.
- **testToggleFromLockedReEntersEditing** — `.locked` → `.enterEditing`.

### C. Enter editing
- **testEnterFromOffEntersEditingAndRefreshes** — `.off` → `enterEditing(refreshUi: true)`.
- **testEnterFromLockedEntersEditingWithoutRefresh** — `.locked` → `enterEditing(refreshUi: false)`.
- **testEnterWhenAlreadyEditingJustPlacesCaret** — `.editing` → `placeCaretOnly`.

### D. Disable
- **testDisableFromEditingExitsToOff** — `.editing` → `.exitToOff`.
- **testDisableFromLockedExitsToOff** — `.locked` → `.exitToOff`.
- **testDisableWhenAlreadyOffIsNoOp** — `.off` → `.noOp`.

### E. Lock / unlock
- **testLockFromEditingLocksResults** — `.editing` → `.lockResults`.
- **testLockFromLockedUnlocksToEditing** — `.locked` → `.unlockToEditing`.
- **testLockFromOffIsNoOp** — `.off` → `.noOp`.

### F. Escape depends on how search was entered
- **testEscapeEditingToggledMidSessionExitsSearch** — editing + mid-session → `.exitSearch`.
- **testEscapeLockedToggledMidSessionExitsSearch** — locked + mid-session → `.exitSearch`.
- **testEscapeEditingStartedInSearchClosesSwitcher** — editing + started-in-search → `.closeSwitcher`.
- **testEscapeLockedStartedInSearchClosesSwitcher** — locked + started-in-search → `.closeSwitcher`.
- **testEscapeOffToggledMidSessionClosesSwitcher** — off → `.closeSwitcher`.
- **testEscapeOffStartedInSearchClosesSwitcher** — off → `.closeSwitcher`.

### G. Key routing: navigation & tab
- **testKeyLeftArrowCyclesLeft** — left arrow → `cycleSelection(.left)`.
- **testKeyRightArrowCyclesRight** — right arrow → `cycleSelection(.right)`.
- **testKeyUpArrowCyclesUp** — up arrow → `cycleSelection(.up)`.
- **testKeyDownArrowCyclesDown** — down arrow → `cycleSelection(.down)`.
- **testKeyTabIsSwallowed** — Tab → `.handled`.

### H. Key routing: shortcut pass-through
- **testKeyCancelPassesToShortcuts** — cancel shortcut → `.passToShortcuts`.
- **testKeyLockSearchPassesToShortcuts** — lock-search shortcut → `.passToShortcuts`.
- **testKeyFocusPassesToShortcuts** — focus shortcut → `.passToShortcuts`.
- **testKeyArrowWinsOverMatchingShortcut** — an arrow also bound as a shortcut still cycles (arrow precedence).

### I. Key routing: text editing passes to the field
- **testKeyPlainTextPassesToField** — typed characters and cmd+A/C/V/X (none of arrow/tab/shortcut) → `.passToField` (NSSearchField handles editing natively).

### J. IME composing / open context menu beat everything
- **testKeyMarkedTextBeatsArrow** — composing → `.passToField` even for an arrow.
- **testKeyOpenMenuBeatsTab** — open menu → `.passToField` even for Tab.
- **testKeyMarkedTextBeatsShortcut** — composing → `.passToField` even for a matching shortcut.

### K. Search-field editability
- **testFieldEditableOnlyWhenEditing** — editable iff `.editing` (off/locked are read-only).
