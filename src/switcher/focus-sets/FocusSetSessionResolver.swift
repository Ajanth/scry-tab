import Foundation

/// A scope that can appear as a selectable Focus Sets picker row. `.none` is intentionally excluded
/// because it belongs only to ordinary switcher sessions.
enum FocusSetPickerScope: Equatable, Hashable {
    case allWindows
    case set(id: UUID)
    case unassigned

    init?(scope: FocusSetScope) {
        switch scope {
            case .none: return nil
            case .allWindows: self = .allWindows
            case let .set(id): self = .set(id: id)
            case .unassigned: self = .unassigned
        }
    }

    var focusSetScope: FocusSetScope {
        switch self {
            case .allWindows: return .allWindows
            case let .set(id): return .set(id: id)
            case .unassigned: return .unassigned
        }
    }
}

/// Session state as seen by Focus Sets orchestration. Picker child grids return to the picker,
/// direct grids carry one saved-set scope without picker ownership, and ordinary grids have none.
enum FocusSetSessionState: Equatable {
    case idle
    case picker
    case focusSetGrid(FocusSetPickerScope)
    case directFocusSetGrid(UUID)
    case ordinaryGrid

    var focusSetScope: FocusSetScope? {
        switch self {
            case let .focusSetGrid(scope): return scope.focusSetScope
            case let .directFocusSetGrid(identifier): return .set(id: identifier)
            case .idle, .picker, .ordinaryGrid: return nil
        }
    }

    var returnsToFocusSetPicker: Bool {
        if case .focusSetGrid(_) = self { return true }
        return false
    }

    var directFocusSetIdentifier: UUID? {
        guard case let .directFocusSetGrid(identifier) = self else { return nil }
        return identifier
    }
}

/// Facts supplied by App after search routing and picker-scope snapshotting.
enum FocusSetSessionEvent: Equatable {
    case openFocusSets
    case directFocusSetShortcut(UUID)
    case confirm(scope: FocusSetPickerScope?)
    case escape(searchConsumesEscape: Bool)
    case dismiss
    case ordinaryShortcutOrGesture
    case availableScopesChanged
}

/// Complete immutable input to one Focus Sets session transition.
struct FocusSetSessionInput: Equatable {
    let state: FocusSetSessionState
    let event: FocusSetSessionEvent
    let availableScopes: Set<FocusSetPickerScope>

    init(state: FocusSetSessionState,
         event: FocusSetSessionEvent,
         availableScopes: Set<FocusSetPickerScope> = []) {
        self.state = state
        self.event = event
        self.availableScopes = availableScopes
    }
}

/// App-facing work for the transition. The App layer owns all panel and session side effects.
enum FocusSetSessionAction: Equatable {
    case noOp
    case showFocusSetPicker
    case refreshFocusSetPicker
    case showFocusSetGrid(scope: FocusSetScope)
    case cycleFocusSetSelection
    case returnToFocusSetPicker
    case showOrdinaryGrid
    case dismissSwitcherUi
}

/// The next state plus the App operation required to reach it. A `true`
/// `suppressFocusOnRelease` asks the caller to set its existing release guard; `false` never asks
/// it to clear an already-set guard.
struct FocusSetSessionDecision: Equatable {
    let nextState: FocusSetSessionState
    let action: FocusSetSessionAction
    let suppressFocusOnRelease: Bool

    init(nextState: FocusSetSessionState,
         action: FocusSetSessionAction,
         suppressFocusOnRelease: Bool = false) {
        self.nextState = nextState
        self.action = action
        self.suppressFocusOnRelease = suppressFocusOnRelease
    }

    var focusSetScope: FocusSetScope? {
        nextState.focusSetScope
    }

    var returnsToFocusSetPicker: Bool {
        nextState.returnsToFocusSetPicker
    }
}

/// Pure Phase 3 transition kernel. It does not route search keys, mutate a `SwitcherSession`, or
/// create panels; App translates `FocusSetSessionDecision` into those effects.
enum FocusSetSessionResolver {
    static func shouldReplaceFocusSetFlow(state: FocusSetSessionState,
                                          activeShortcutIndex: Int,
                                          incomingShortcutIndex: Int) -> Bool {
        switch state {
            case .idle, .picker: return true
            case .focusSetGrid, .directFocusSetGrid: return activeShortcutIndex != incomingShortcutIndex
            case .ordinaryGrid: return false
        }
    }

    static func shouldFocusDirectSelectionOnRelease(state: FocusSetSessionState,
                                                    shortcutIdentifier: UUID,
                                                    forceDoNothingOnRelease: Bool,
                                                    profileFocusesOnRelease: Bool,
                                                    profileHoldModifierIsReleased: Bool) -> Bool {
        state.directFocusSetIdentifier == shortcutIdentifier
            && !forceDoNothingOnRelease
            && profileFocusesOnRelease
            && profileHoldModifierIsReleased
    }

    static func resolve(_ input: FocusSetSessionInput) -> FocusSetSessionDecision {
        switch input.event {
            case .openFocusSets: return openFocusSets(from: input.state)
            case let .directFocusSetShortcut(identifier):
                return directFocusSetShortcut(identifier, from: input.state, availableScopes: input.availableScopes)
            case let .confirm(scope): return confirm(scope, from: input.state, availableScopes: input.availableScopes)
            case let .escape(searchConsumesEscape): return escape(from: input.state, searchConsumesEscape: searchConsumesEscape)
            case .dismiss: return dismiss(input.state)
            case .ordinaryShortcutOrGesture: return showOrdinaryGrid()
            case .availableScopesChanged: return validateActiveScope(input.state, availableScopes: input.availableScopes)
        }
    }

    private static func openFocusSets(from state: FocusSetSessionState) -> FocusSetSessionDecision {
        switch state {
            case .idle, .ordinaryGrid: return decision(.picker, .showFocusSetPicker)
            case .picker: return decision(.picker, .refreshFocusSetPicker)
            case .focusSetGrid: return decision(.picker, .returnToFocusSetPicker)
            case .directFocusSetGrid: return decision(.picker, .showFocusSetPicker)
        }
    }

    private static func directFocusSetShortcut(_ identifier: UUID,
                                               from state: FocusSetSessionState,
                                               availableScopes: Set<FocusSetPickerScope>) -> FocusSetSessionDecision {
        let scope = FocusSetPickerScope.set(id: identifier)
        guard availableScopes.contains(scope) else {
            guard state.directFocusSetIdentifier == identifier else { return unchanged(state) }
            return decision(.idle, .dismissSwitcherUi)
        }
        guard state.directFocusSetIdentifier != identifier else {
            return decision(state, .cycleFocusSetSelection)
        }
        return decision(.directFocusSetGrid(identifier), .showFocusSetGrid(scope: .set(id: identifier)))
    }

    private static func confirm(_ scope: FocusSetPickerScope?,
                                from state: FocusSetSessionState,
                                availableScopes: Set<FocusSetPickerScope>) -> FocusSetSessionDecision {
        guard case .picker = state, let scope, availableScopes.contains(scope) else { return unchanged(state) }
        return decision(.focusSetGrid(scope), .showFocusSetGrid(scope: scope.focusSetScope), suppressFocusOnRelease: true)
    }

    private static func escape(from state: FocusSetSessionState,
                               searchConsumesEscape: Bool) -> FocusSetSessionDecision {
        guard !searchConsumesEscape else { return unchanged(state) }
        switch state {
            case .idle: return unchanged(state)
            case .picker, .directFocusSetGrid, .ordinaryGrid: return decision(.idle, .dismissSwitcherUi)
            case .focusSetGrid: return decision(.picker, .returnToFocusSetPicker)
        }
    }

    private static func dismiss(_ state: FocusSetSessionState) -> FocusSetSessionDecision {
        guard state != .idle else { return unchanged(state) }
        return decision(.idle, .dismissSwitcherUi)
    }

    private static func showOrdinaryGrid() -> FocusSetSessionDecision {
        decision(.ordinaryGrid, .showOrdinaryGrid)
    }

    private static func validateActiveScope(_ state: FocusSetSessionState,
                                            availableScopes: Set<FocusSetPickerScope>) -> FocusSetSessionDecision {
        switch state {
            case let .focusSetGrid(scope):
                guard !availableScopes.contains(scope) else { return unchanged(state) }
                return decision(.picker, .returnToFocusSetPicker)
            case let .directFocusSetGrid(identifier):
                guard !availableScopes.contains(.set(id: identifier)) else { return unchanged(state) }
                return decision(.idle, .dismissSwitcherUi)
            case .idle, .picker, .ordinaryGrid:
                return unchanged(state)
        }
    }

    private static func unchanged(_ state: FocusSetSessionState) -> FocusSetSessionDecision {
        decision(state, .noOp)
    }

    private static func decision(_ state: FocusSetSessionState,
                                 _ action: FocusSetSessionAction,
                                 suppressFocusOnRelease: Bool = false) -> FocusSetSessionDecision {
        FocusSetSessionDecision(
            nextState: state,
            action: action,
            suppressFocusOnRelease: suppressFocusOnRelease)
    }
}
