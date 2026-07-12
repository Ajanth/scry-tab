import Foundation

enum FocusSetSessionState: Equatable {
    case idle
    case directFocusSetGrid(UUID)
    case ordinaryGrid

    var focusSetScope: FocusSetScope {
        guard case let .directFocusSetGrid(identifier) = self else { return .none }
        return .set(id: identifier)
    }

    var directFocusSetIdentifier: UUID? {
        guard case let .directFocusSetGrid(identifier) = self else { return nil }
        return identifier
    }
}

enum FocusSetSessionEvent: Equatable {
    case directFocusSetShortcut(UUID)
    case escape
    case ordinaryShortcutOrGesture
    case availableFocusSetsChanged
}

struct FocusSetSessionInput: Equatable {
    let state: FocusSetSessionState
    let event: FocusSetSessionEvent
    let availableFocusSetIdentifiers: Set<UUID>

    init(state: FocusSetSessionState,
         event: FocusSetSessionEvent,
         availableFocusSetIdentifiers: Set<UUID> = []) {
        self.state = state
        self.event = event
        self.availableFocusSetIdentifiers = availableFocusSetIdentifiers
    }
}

enum FocusSetSessionAction: Equatable {
    case noOp
    case showDirectFocusSetGrid
    case cycleFocusSetSelection
    case showOrdinaryGrid
    case dismissSwitcherUi
}

struct FocusSetSessionDecision: Equatable {
    let nextState: FocusSetSessionState
    let action: FocusSetSessionAction
}

enum FocusSetShortcutReleaseAction: Equatable {
    case none
    case focus
    case search
}

/// Pure lifecycle kernel for direct Focus Set shortcuts. It owns no AppKit state, panels,
/// presentation-source selection, or window filtering.
enum FocusSetSessionResolver {
    static func directFocusSetReleaseAction(state: FocusSetSessionState,
                                             shortcutIdentifier: UUID,
                                             forceDoNothingOnRelease: Bool,
                                             shortcutStyle: ShortcutStylePreference) -> FocusSetShortcutReleaseAction {
        guard state.directFocusSetIdentifier == shortcutIdentifier,
              !forceDoNothingOnRelease else { return .none }
        switch shortcutStyle {
        case .focusOnRelease: return .focus
        case .doNothingOnRelease: return .none
        case .searchOnRelease: return .search
        }
    }

    static func resolve(_ input: FocusSetSessionInput) -> FocusSetSessionDecision {
        switch input.event {
        case let .directFocusSetShortcut(identifier):
            return directFocusSetShortcut(identifier, from: input.state, availableFocusSetIdentifiers: input.availableFocusSetIdentifiers)
        case .escape:
            return dismiss(input.state)
        case .ordinaryShortcutOrGesture:
            return FocusSetSessionDecision(nextState: .ordinaryGrid, action: .showOrdinaryGrid)
        case .availableFocusSetsChanged:
            return validateActiveFocusSet(input.state, availableFocusSetIdentifiers: input.availableFocusSetIdentifiers)
        }
    }

    private static func directFocusSetShortcut(_ identifier: UUID,
                                               from state: FocusSetSessionState,
                                               availableFocusSetIdentifiers: Set<UUID>) -> FocusSetSessionDecision {
        guard availableFocusSetIdentifiers.contains(identifier) else {
            guard state.directFocusSetIdentifier == identifier else { return unchanged(state) }
            return FocusSetSessionDecision(nextState: .idle, action: .dismissSwitcherUi)
        }
        guard state.directFocusSetIdentifier != identifier else {
            return FocusSetSessionDecision(nextState: state, action: .cycleFocusSetSelection)
        }
        return FocusSetSessionDecision(nextState: .directFocusSetGrid(identifier), action: .showDirectFocusSetGrid)
    }

    private static func dismiss(_ state: FocusSetSessionState) -> FocusSetSessionDecision {
        guard state != .idle else { return unchanged(state) }
        return FocusSetSessionDecision(nextState: .idle, action: .dismissSwitcherUi)
    }

    private static func validateActiveFocusSet(_ state: FocusSetSessionState,
                                               availableFocusSetIdentifiers: Set<UUID>) -> FocusSetSessionDecision {
        guard let identifier = state.directFocusSetIdentifier else { return unchanged(state) }
        guard !availableFocusSetIdentifiers.contains(identifier) else { return unchanged(state) }
        return FocusSetSessionDecision(nextState: .idle, action: .dismissSwitcherUi)
    }

    private static func unchanged(_ state: FocusSetSessionState) -> FocusSetSessionDecision {
        FocusSetSessionDecision(nextState: state, action: .noOp)
    }
}
