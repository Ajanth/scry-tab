import Foundation

/// The search-mode state machine, extracted from `TilesView` as a pure decision kernel (same
/// pattern as `SelectionResolver`). It owns the transition + key-routing *decisions*; `TilesView`
/// and `ShortcutAction` translate the returned decisions into AppKit side effects (first responder,
/// caret, refresh, edit menu, `App.cycleSelection`). No globals, no AppKit, no async — so every
/// interaction is unit-testable. Behavior mirrors the original branch order exactly.

enum SearchMode {
    case off
    case editing
}

/// How search was entered this session — decides what Escape does.
enum SearchEntryStyle {
    case startedInSearch    // session began in search (the `.searchOnRelease` shortcut style)
    case toggledMidSession  // search turned on via the search shortcut during a normal session
}

/// Kernel-local direction (decoupled from the app-only `Direction` enum, which `TilesView` maps to).
enum CycleDirection: Equatable {
    case left, right, up, down
}

enum SearchToggleRoute: Equatable { case enterEditing, disable }

enum SearchModeDecision: Equatable {
    case noOp                          // nothing to do (e.g. disabling when already off)
    case enterEditing(refreshUi: Bool) // refresh only when coming from `.off` (the original `wasOff`)
    case exitToOff
    case placeCaretOnly                // already editing: just re-place the caret
}

enum SearchEscapeDecision: Equatable { case exitSearch, closeSwitcher }

enum SearchKeyDecision: Equatable {
    case cycleSelection(CycleDirection)
    case handled          // swallow (Tab)
    case passToShortcuts  // hand to the shortcut pipeline (cancel / focus)
    case passToField      // hand to the NSSearchField (text, cmd+A/C/V/X, IME, while a menu is open)
}

enum SearchModeResolver {
    static func startMode(startInSearch: Bool) -> SearchMode {
        startInSearch ? .editing : .off
    }

    /// Search shortcut: editing → turn off; off → enter editing.
    static func toggle(mode: SearchMode) -> SearchToggleRoute {
        mode == .editing ? .disable : .enterEditing
    }

    /// Already-editing short-circuits; otherwise enter, refreshing the UI only when coming from `.off`.
    static func enableEditing(mode: SearchMode) -> SearchModeDecision {
        if mode == .editing { return .placeCaretOnly }
        return .enterEditing(refreshUi: mode == .off)
    }

    static func disable(mode: SearchMode) -> SearchModeDecision {
        mode == .off ? .noOp : .exitToOff
    }

    /// Escape exits search only when it was toggled on mid-session. If the session *started* in
    /// search (`.searchOnRelease`), or search is off, Escape closes the whole switcher.
    static func escape(mode: SearchMode, entry: SearchEntryStyle) -> SearchEscapeDecision {
        (mode != .off && entry == .toggledMidSession) ? .exitSearch : .closeSwitcher
    }

    /// Key routing while the search field is being edited. IME/menu come first so composing
    /// keystrokes are never stolen; then arrows drive selection, Tab is swallowed, the
    /// pass-through shortcuts go to the shortcut pipeline, and everything else (typed text,
    /// cmd+A/C/V/X) goes to the field. Defaults express "no signal" so callers only spell out
    /// the facts that are true for this key-down.
    static func routeKey(hasMarkedText: Bool = false,    // IME composing
                         isMenuOpen: Bool = false,       // a context menu is open
                         arrow: CycleDirection? = nil,   // non-nil iff the key is an arrow
                         isTab: Bool = false,
                         matchesCancel: Bool = false,
                         matchesFocus: Bool = false) -> SearchKeyDecision {
        if hasMarkedText || isMenuOpen { return .passToField }
        if let arrow { return .cycleSelection(arrow) }
        if isTab { return .handled }
        if matchesCancel || matchesFocus { return .passToShortcuts }
        return .passToField
    }

    static func isFieldEditable(_ mode: SearchMode) -> Bool {
        mode == .editing
    }
}
