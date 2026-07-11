import Foundation
import XCTest

final class FocusSetSessionResolverTests: XCTestCase {

    // MARK: - A. Session-state boundaries

    /// Every picker-selectable scope maps losslessly to the shared Focus Set scope.
    func testPickerScopeMapsSelectableScopes() {
        let id = UUID()

        XCTAssertEqual(FocusSetPickerScope(scope: .allWindows), .allWindows)
        XCTAssertEqual(FocusSetPickerScope(scope: .set(id: id)), .set(id: id))
        XCTAssertEqual(FocusSetPickerScope(scope: .unassigned), .unassigned)
    }

    /// The ordinary-only `.none` scope cannot become a picker selection.
    func testPickerScopeRejectsOrdinaryScope() {
        XCTAssertNil(FocusSetPickerScope(scope: .none))
    }

    /// A Focus Sets child grid exposes its selected scope and inherent return-to-picker intent.
    func testFocusSetGridCarriesScopeAndReturnIntent() {
        let id = UUID()
        let state = FocusSetSessionState.focusSetGrid(.set(id: id))

        XCTAssertEqual(state.focusSetScope, .set(id: id))
        XCTAssertTrue(state.returnsToFocusSetPicker)
    }

    /// An ordinary grid has neither a Focus Set scope nor return-to-picker behavior.
    func testOrdinaryGridCarriesNeitherFocusSetScopeNorReturnIntent() {
        XCTAssertNil(FocusSetSessionState.ordinaryGrid.focusSetScope)
        XCTAssertFalse(FocusSetSessionState.ordinaryGrid.returnsToFocusSetPicker)
    }

    // MARK: - B. Open Focus Sets

    /// Opening Focus Sets from idle creates the first-level picker.
    func testOpenFocusSetsFromIdleShowsPicker() {
        XCTAssertEqual(
            resolve(.idle, .openFocusSets),
            decision(.picker, .showFocusSetPicker))
    }

    /// Reopening Focus Sets while its picker is visible refreshes the same picker phase.
    func testRepeatedOpenFocusSetsRefreshesPicker() {
        XCTAssertEqual(
            resolve(.picker, .openFocusSets),
            decision(.picker, .refreshFocusSetPicker))
    }

    /// Opening Focus Sets from its child grid returns to the still-owned picker session.
    func testOpenFocusSetsFromFocusSetGridReturnsToPicker() {
        XCTAssertEqual(
            resolve(.focusSetGrid(.set(id: UUID())), .openFocusSets),
            decision(.picker, .returnToFocusSetPicker))
    }

    /// Opening Focus Sets from an ordinary grid replaces that grid with the picker.
    func testOpenFocusSetsFromOrdinaryGridShowsPicker() {
        XCTAssertEqual(
            resolve(.ordinaryGrid, .openFocusSets),
            decision(.picker, .showFocusSetPicker))
    }

    // MARK: - C. Picker confirmation

    /// Confirming an available saved set opens its child grid and suppresses the opener release.
    func testConfirmAvailableSetShowsChildGridAndSuppressesRelease() {
        let scope = FocusSetPickerScope.set(id: UUID())
        let result = resolve(.picker, .confirm(scope: scope), scopes: [scope])

        XCTAssertEqual(
            result,
            decision(
                .focusSetGrid(scope),
                .showFocusSetGrid(scope: scope.focusSetScope),
                suppressFocusOnRelease: true))
        XCTAssertEqual(result.focusSetScope, scope.focusSetScope)
        XCTAssertTrue(result.returnsToFocusSetPicker)
    }

    /// Confirming All Windows remains a Focus Sets child flow even without a membership filter.
    func testConfirmAllWindowsKeepsReturnToPickerIntent() {
        let result = resolve(.picker, .confirm(scope: .allWindows), scopes: [.allWindows])

        XCTAssertEqual(
            result,
            decision(
                .focusSetGrid(.allWindows),
                .showFocusSetGrid(scope: .allWindows),
                suppressFocusOnRelease: true))
        XCTAssertTrue(result.returnsToFocusSetPicker)
    }

    /// Confirming Unassigned Windows carries that exact picker scope into the child grid.
    func testConfirmUnassignedCarriesUnassignedScope() {
        let result = resolve(.picker, .confirm(scope: .unassigned), scopes: [.unassigned])

        XCTAssertEqual(
            result,
            decision(
                .focusSetGrid(.unassigned),
                .showFocusSetGrid(scope: .unassigned),
                suppressFocusOnRelease: true))
    }

    /// A missing picker selection leaves the picker open and never suppresses a release.
    func testConfirmMissingScopeKeepsPicker() {
        XCTAssertEqual(
            resolve(.picker, .confirm(scope: nil), scopes: [.allWindows]),
            decision(.picker, .noOp))
    }

    /// A deleted or stale picker row cannot open a child grid or suppress a release.
    func testConfirmStaleScopeKeepsPicker() {
        let staleScope = FocusSetPickerScope.set(id: UUID())

        XCTAssertEqual(
            resolve(.picker, .confirm(scope: staleScope), scopes: [.allWindows]),
            decision(.picker, .noOp))
    }

    /// Confirmation from any non-picker phase is ignored even when the scope is otherwise valid.
    func testConfirmOutsidePickerDoesNothing() {
        let scope = FocusSetPickerScope.set(id: UUID())

        XCTAssertEqual(
            resolve(.ordinaryGrid, .confirm(scope: scope), scopes: [scope]),
            decision(.ordinaryGrid, .noOp))
    }

    // MARK: - D. Escape and dismissal

    /// Escape remains with the search layer while search reports that it consumed the key.
    func testConsumedEscapeLeavesFocusSetGridUntouched() {
        let state = FocusSetSessionState.focusSetGrid(.set(id: UUID()))

        XCTAssertEqual(
            resolve(state, .escape(searchConsumesEscape: true)),
            decision(state, .noOp))
    }

    /// Escape returns from a Focus Sets child grid only after search no longer consumes it.
    func testUnconsumedEscapeFromFocusSetGridReturnsToPicker() {
        XCTAssertEqual(
            resolve(.focusSetGrid(.set(id: UUID())), .escape(searchConsumesEscape: false)),
            decision(.picker, .returnToFocusSetPicker))
    }

    /// Escape from the picker dismisses the complete Focus Sets flow.
    func testUnconsumedEscapeFromPickerDismissesSwitcher() {
        XCTAssertEqual(
            resolve(.picker, .escape(searchConsumesEscape: false)),
            decision(.idle, .dismissSwitcherUi))
    }

    /// Escape from an ordinary grid follows its ordinary dismissal path.
    func testUnconsumedEscapeFromOrdinaryGridDismissesSwitcher() {
        XCTAssertEqual(
            resolve(.ordinaryGrid, .escape(searchConsumesEscape: false)),
            decision(.idle, .dismissSwitcherUi))
    }

    /// Escape from idle cannot create or dismiss a session.
    func testUnconsumedEscapeFromIdleDoesNothing() {
        XCTAssertEqual(
            resolve(.idle, .escape(searchConsumesEscape: false)),
            decision(.idle, .noOp))
    }

    /// Outside dismissal from the picker tears down the entire Focus Sets flow.
    func testOutsideDismissalFromPickerDismissesSwitcher() {
        XCTAssertEqual(
            resolve(.picker, .dismiss),
            decision(.idle, .dismissSwitcherUi))
    }

    /// A normal child-grid dismissal ends the session rather than returning to the picker.
    func testNormalDismissalFromFocusSetGridDismissesSwitcher() {
        XCTAssertEqual(
            resolve(.focusSetGrid(.set(id: UUID())), .dismiss),
            decision(.idle, .dismissSwitcherUi))
    }

    /// A normal ordinary-grid dismissal also ends the switcher session.
    func testNormalDismissalFromOrdinaryGridDismissesSwitcher() {
        XCTAssertEqual(
            resolve(.ordinaryGrid, .dismiss),
            decision(.idle, .dismissSwitcherUi))
    }

    /// Dismissal from idle is a harmless no-op.
    func testDismissWhenIdleDoesNothing() {
        XCTAssertEqual(
            resolve(.idle, .dismiss),
            decision(.idle, .noOp))
    }

    // MARK: - E. Ordinary entry points

    /// An ordinary shortcut or gesture replaces a visible picker with an unfiltered ordinary grid.
    func testOrdinaryShortcutOrGestureFromPickerReplacesItWithOrdinaryGrid() {
        let result = resolve(.picker, .ordinaryShortcutOrGesture)

        XCTAssertEqual(result, decision(.ordinaryGrid, .showOrdinaryGrid))
        XCTAssertNil(result.focusSetScope)
        XCTAssertFalse(result.returnsToFocusSetPicker)
    }

    /// An ordinary shortcut or gesture clears a Focus Sets child grid before showing the ordinary grid.
    func testOrdinaryShortcutOrGestureFromFocusSetGridClearsScopeAndReturnIntent() {
        let result = resolve(.focusSetGrid(.set(id: UUID())), .ordinaryShortcutOrGesture)

        XCTAssertEqual(result, decision(.ordinaryGrid, .showOrdinaryGrid))
        XCTAssertNil(result.focusSetScope)
        XCTAssertFalse(result.returnsToFocusSetPicker)
    }

    /// An ordinary shortcut or gesture from idle starts its normal unfiltered grid.
    func testOrdinaryShortcutOrGestureFromIdleShowsOrdinaryGrid() {
        XCTAssertEqual(
            resolve(.idle, .ordinaryShortcutOrGesture),
            decision(.ordinaryGrid, .showOrdinaryGrid))
    }

    /// Repeating an ordinary entry point remains in the ordinary unfiltered-grid state.
    func testOrdinaryShortcutOrGestureWithinOrdinaryGridRemainsOrdinary() {
        XCTAssertEqual(
            resolve(.ordinaryGrid, .ordinaryShortcutOrGesture),
            decision(.ordinaryGrid, .showOrdinaryGrid))
    }

    // MARK: - F. Scope invalidation

    /// Removing the active child scope returns safely to the picker instead of retaining stale state.
    func testRemovedActiveScopeReturnsChildGridToPicker() {
        let staleScope = FocusSetPickerScope.set(id: UUID())

        XCTAssertEqual(
            resolve(.focusSetGrid(staleScope), .availableScopesChanged, scopes: [.allWindows]),
            decision(.picker, .returnToFocusSetPicker))
    }

    /// Losing the final Unassigned candidate removes its picker scope and returns the child grid.
    func testUnavailableUnassignedScopeReturnsChildGridToPicker() {
        XCTAssertEqual(
            resolve(.focusSetGrid(.unassigned), .availableScopesChanged, scopes: [.allWindows]),
            decision(.picker, .returnToFocusSetPicker))
    }

    /// A still-available child scope remains active when the picker scope snapshot changes.
    func testAvailableActiveScopeKeepsChildGridOpen() {
        let scope = FocusSetPickerScope.set(id: UUID())

        XCTAssertEqual(
            resolve(.focusSetGrid(scope), .availableScopesChanged, scopes: [scope, .allWindows]),
            decision(.focusSetGrid(scope), .noOp))
    }

    /// Scope updates cannot change a picker or ordinary session without an explicit user action.
    func testScopeChangeOutsideFocusSetGridDoesNothing() {
        XCTAssertEqual(
            resolve(.picker, .availableScopesChanged, scopes: [.allWindows]),
            decision(.picker, .noOp))
        XCTAssertEqual(
            resolve(.ordinaryGrid, .availableScopesChanged, scopes: [.allWindows]),
            decision(.ordinaryGrid, .noOp))
    }

    private func resolve(_ state: FocusSetSessionState,
                         _ event: FocusSetSessionEvent,
                         scopes: Set<FocusSetPickerScope> = []) -> FocusSetSessionDecision {
        FocusSetSessionResolver.resolve(
            FocusSetSessionInput(
                state: state,
                event: event,
                availableScopes: scopes))
    }

    private func decision(_ state: FocusSetSessionState,
                          _ action: FocusSetSessionAction,
                          suppressFocusOnRelease: Bool = false) -> FocusSetSessionDecision {
        FocusSetSessionDecision(
            nextState: state,
            action: action,
            suppressFocusOnRelease: suppressFocusOnRelease)
    }
}
