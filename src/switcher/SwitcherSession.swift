import Cocoa

enum SwitcherPresentationSource: Equatable {
    case shortcut(Int)
    case focusSets

    var shortcutIndex: Int? {
        guard case let .shortcut(index) = self else { return nil }
        return index
    }
}

/// Holds all state scoped to a single switcher invocation: from when the user
/// first triggers the shortcut to when the panel is dismissed.
///
/// `current` is non-nil iff the switcher panel is conceptually shown to the
/// user. Lifetime is owned by `App.showUiOrCycleSelection` (creates) and
/// `App.hideUi` (destroys).
final class SwitcherSession {
    static var current: SwitcherSession?
    static var isActive: Bool { current != nil }
    var presentationSource = SwitcherPresentationSource.shortcut(0)
    var isFirstSummon: Bool = true
    var forceDoNothingOnRelease: Bool = false
    var chordLifecycleState: ShortcutChordLifecycleState?

    var selectedIndex: Int = 0
    var hoveredIndex: Int?
    var selectedTarget: String?
    var searchQuery: String = ""

    /// `ordinaryGrid` preserves the legacy flow. Focus Sets transitions replace this state for the
    /// picker, its child grid, or a direct scoped grid, so normal shortcuts never inherit membership.
    var focusSetSessionState: FocusSetSessionState = .ordinaryGrid
    var focusSetPickerSelectedIdentifier: FocusSetPickerItemIdentifier?
    var focusSetPickerQuery: String = ""
    var focusSetPickerSnapshot: FocusSetPickerSnapshot?

    var focusSetScope: FocusSetScope { focusSetSessionState.focusSetScope ?? .none }
    var returnsToFocusSetPicker: Bool { focusSetSessionState.returnsToFocusSetPicker }
}
