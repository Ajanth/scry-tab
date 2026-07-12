import Carbon.HIToolbox.Events
import Foundation
import XCTest

final class FocusSetSessionResolverTests: XCTestCase {
    /// A direct session exposes only its saved set's membership scope.
    func testDirectGridCarriesSavedSetScope() {
        let identifier = UUID()

        XCTAssertEqual(FocusSetSessionState.directFocusSetGrid(identifier).focusSetScope, .set(id: identifier))
        XCTAssertEqual(FocusSetSessionState.ordinaryGrid.focusSetScope, .none)
    }

    /// Repeating the active set's direct binding advances the current scoped selection.
    func testRepeatedDirectShortcutCyclesScopedGrid() {
        let identifier = UUID()
        let state = FocusSetSessionState.directFocusSetGrid(identifier)

        XCTAssertEqual(
            resolve(state, .directFocusSetShortcut(identifier), identifiers: [identifier]),
            decision(state, .cycleFocusSetSelection))
    }

    /// A configured direct shortcut opens the standard grid with only that saved set's membership scope.
    func testDirectShortcutShowsScopedGrid() {
        let identifier = UUID()

        XCTAssertEqual(
            resolve(.idle, .directFocusSetShortcut(identifier), identifiers: [identifier]),
            decision(.directFocusSetGrid(identifier), .showDirectFocusSetGrid))
    }

    /// A stale direct shortcut cannot fall back to another configured Focus Set.
    func testStaleDirectShortcutDoesNotSelectAnotherSet() {
        let staleIdentifier = UUID()
        let retainedIdentifier = UUID()

        XCTAssertEqual(
            resolve(.idle, .directFocusSetShortcut(staleIdentifier), identifiers: [retainedIdentifier]),
            decision(.idle, .noOp))
    }

    /// Removing the saved set backing an active direct session dismisses it safely.
    func testDeletedActiveDirectSetDismissesSwitcher() {
        let identifier = UUID()
        let state = FocusSetSessionState.directFocusSetGrid(identifier)

        XCTAssertEqual(
            resolve(state, .availableFocusSetsChanged, identifiers: []),
            decision(.idle, .dismissSwitcherUi))
        XCTAssertEqual(
            resolve(state, .directFocusSetShortcut(identifier), identifiers: []),
            decision(.idle, .dismissSwitcherUi))
    }

    /// Direct shortcut release resolves only the exact active set from the Focus Sets setting.
    func testDirectShortcutReleaseRequiresExactActiveSetAndFocusSetsBehavior() {
        let identifier = UUID()

        XCTAssertEqual(FocusSetSessionResolver.directFocusSetReleaseAction(
            state: .directFocusSetGrid(identifier),
            shortcutIdentifier: identifier,
            forceDoNothingOnRelease: false,
            shortcutStyle: .focusOnRelease), .focus)
        XCTAssertEqual(FocusSetSessionResolver.directFocusSetReleaseAction(
            state: .directFocusSetGrid(identifier),
            shortcutIdentifier: UUID(),
            forceDoNothingOnRelease: false,
            shortcutStyle: .focusOnRelease), .none)
        XCTAssertEqual(FocusSetSessionResolver.directFocusSetReleaseAction(
            state: .directFocusSetGrid(identifier),
            shortcutIdentifier: identifier,
            forceDoNothingOnRelease: true,
            shortcutStyle: .focusOnRelease), .none)
        XCTAssertEqual(FocusSetSessionResolver.directFocusSetReleaseAction(
            state: .directFocusSetGrid(identifier),
            shortcutIdentifier: identifier,
            forceDoNothingOnRelease: false,
            shortcutStyle: .doNothingOnRelease), .none)
        XCTAssertEqual(FocusSetSessionResolver.directFocusSetReleaseAction(
            state: .directFocusSetGrid(identifier),
            shortcutIdentifier: identifier,
            forceDoNothingOnRelease: false,
            shortcutStyle: .searchOnRelease), .search)
    }

    /// A chord ignores partial releases and reports its latest direct owner once.
    func testDirectShortcutChordLifecycleWaitsForFinalModifierRelease() {
        let firstIdentifier = UUID()
        let secondIdentifier = UUID()
        let command = CarbonModifierFlags(cmdKey)
        let shift = CarbonModifierFlags(shiftKey)
        let firstPress = ShortcutChordLifecycleResolver.resolve(
            nil,
            .press(owner: .directFocusSet(firstIdentifier), holdModifiers: command | shift))
        let repeatedPress = ShortcutChordLifecycleResolver.resolve(
            firstPress.nextState,
            .press(owner: .directFocusSet(firstIdentifier), holdModifiers: command | shift))
        let partialRelease = ShortcutChordLifecycleResolver.resolve(
            repeatedPress.nextState,
            .modifiersChanged(command))
        let replacementPress = ShortcutChordLifecycleResolver.resolve(
            partialRelease.nextState,
            .press(owner: .directFocusSet(secondIdentifier), holdModifiers: command))
        let release = ShortcutChordLifecycleResolver.resolve(
            replacementPress.nextState,
            .modifiersChanged(0))
        let duplicateRelease = ShortcutChordLifecycleResolver.resolve(
            release.nextState,
            .modifiersChanged(0))

        XCTAssertEqual(firstPress.action, .none)
        XCTAssertEqual(repeatedPress.action, .none)
        XCTAssertEqual(partialRelease.action, .none)
        XCTAssertEqual(replacementPress.action, .none)
        XCTAssertEqual(release.action, .release(.directFocusSet(secondIdentifier)))
        XCTAssertEqual(duplicateRelease.action, .none)
    }

    /// Escape and an ordinary entry leave a direct grid without a return phase.
    func testDirectGridUsesOrdinaryExitAndReplacementBehavior() {
        let state = FocusSetSessionState.directFocusSetGrid(UUID())

        XCTAssertEqual(
            resolve(state, .escape),
            decision(.idle, .dismissSwitcherUi))
        XCTAssertEqual(
            resolve(state, .ordinaryShortcutOrGesture),
            decision(.ordinaryGrid, .showOrdinaryGrid))
    }

    private func resolve(_ state: FocusSetSessionState,
                         _ event: FocusSetSessionEvent,
                         identifiers: Set<UUID> = []) -> FocusSetSessionDecision {
        FocusSetSessionResolver.resolve(
            FocusSetSessionInput(
                state: state,
                event: event,
                availableFocusSetIdentifiers: identifiers))
    }

    private func decision(_ state: FocusSetSessionState,
                          _ action: FocusSetSessionAction) -> FocusSetSessionDecision {
        FocusSetSessionDecision(nextState: state, action: action)
    }
}
