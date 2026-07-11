import Foundation
import XCTest

final class FocusSetPickerResolverTests: XCTestCase {
    private let builtInNames = FocusSetPickerBuiltInNames(
        allWindows: "All Windows",
        unassignedWindows: "Unassigned Windows")

    // MARK: - A. Picker item snapshots

    /// An empty configuration still provides the unfiltered All Windows entry.
    func testEmptyConfigurationContainsOnlyAllWindows() {
        let items = makeResolver(counts: [.allWindows: 4]).visibleItems()

        XCTAssertEqual(items.map(\.identifier), [.allWindows])
        XCTAssertEqual(items.map(\.scope), [.allWindows])
        XCTAssertEqual(items.map(\.name), [.allWindows])
        XCTAssertEqual(items.map(\.candidateCount), [4])
    }

    /// All Windows precedes saved sets, whose persisted configuration order remains unchanged.
    func testItemsKeepAllWindowsThenSavedSetsInConfigurationOrder() {
        let firstID = UUID()
        let secondID = UUID()
        let resolver = makeResolver(
            sets: [focusSet(secondID, "Second"), focusSet(firstID, "First")],
            counts: [
                .allWindows: 9,
                .set(id: secondID): 3,
                .set(id: firstID): 1
            ])
        let items = resolver.visibleItems()

        XCTAssertEqual(items.map(\.identifier), [.allWindows, .focusSet(secondID), .focusSet(firstID)])
        XCTAssertEqual(items.map(\.scope), [.allWindows, .set(id: secondID), .set(id: firstID)])
        XCTAssertEqual(items.map(\.name), [.allWindows, .savedFocusSet("Second"), .savedFocusSet("First")])
        XCTAssertEqual(items.map(\.candidateCount), [9, 3, 1])
    }

    /// Unassigned Windows is appended only when the supplied policy snapshot has candidates.
    func testUnassignedWindowsAppearsOnlyWithPositivePolicyScopedCount() {
        let setID = UUID()
        let sets = [focusSet(setID, "Writing")]
        let absent = makeResolver(
            sets: sets,
            counts: [.allWindows: 2, .set(id: setID): 2, .unassigned: 0])
        let present = makeResolver(
            sets: sets,
            counts: [.allWindows: 3, .set(id: setID): 2, .unassigned: 1])

        XCTAssertEqual(absent.visibleItems().map(\.identifier), [.allWindows, .focusSet(setID)])
        XCTAssertEqual(absent.availableScopes, [.allWindows, .set(id: setID)])
        XCTAssertEqual(
            present.visibleItems().map(\.identifier),
            [.allWindows, .focusSet(setID), .unassignedWindows])
        XCTAssertEqual(present.availableScopes, [.allWindows, .set(id: setID), .unassigned])
        XCTAssertEqual(present.visibleItems().last?.scope, .unassigned)
        XCTAssertEqual(present.visibleItems().last?.name, .unassignedWindows)
        XCTAssertEqual(present.visibleItems().last?.candidateCount, 1)
    }

    /// Active-grid availability uses the exact row rules without building a full picker snapshot.
    func testActiveScopeAvailabilityMatchesPickerRows() {
        let setID = UUID()
        let configuration = FocusSetsConfiguration(sets: [focusSet(setID, "Writing")])

        XCTAssertTrue(FocusSetPickerResolver.isScopeAvailable(
            .allWindows,
            configuration: configuration,
            hasUnassignedCandidates: false))
        XCTAssertTrue(FocusSetPickerResolver.isScopeAvailable(
            .set(id: setID),
            configuration: configuration,
            hasUnassignedCandidates: false))
        XCTAssertFalse(FocusSetPickerResolver.isScopeAvailable(
            .unassigned,
            configuration: configuration,
            hasUnassignedCandidates: false))
        XCTAssertTrue(FocusSetPickerResolver.isScopeAvailable(
            .unassigned,
            configuration: configuration,
            hasUnassignedCandidates: true))
        XCTAssertFalse(FocusSetPickerResolver.isScopeAvailable(
            .set(id: UUID()),
            configuration: configuration,
            hasUnassignedCandidates: true))
        XCTAssertFalse(FocusSetPickerResolver.isScopeAvailable(
            .none,
            configuration: configuration,
            hasUnassignedCandidates: true))
    }

    /// Missing and invalid negative count facts become safe zero-count picker values.
    func testItemsUseSafeZeroCountsWhenCountFactsAreMissingOrNegative() {
        let setID = UUID()
        let items = makeResolver(
            sets: [focusSet(setID, "Writing")],
            counts: [.allWindows: -1, .unassigned: -2])
            .visibleItems()

        XCTAssertEqual(items.map(\.candidateCount), [0, 0])
        XCTAssertEqual(items.map(\.identifier), [.allWindows, .focusSet(setID)])
    }

    /// The first configured item wins when malformed input repeats an identifier.
    func testDuplicateSetIdentifiersKeepFirstConfiguredItem() {
        let setID = UUID()
        let items = makeResolver(
            sets: [focusSet(setID, "First"), focusSet(setID, "Duplicate")],
            counts: [.set(id: setID): 2])
            .visibleItems()

        XCTAssertEqual(items.map(\.identifier), [.allWindows, .focusSet(setID)])
        XCTAssertEqual(items.map(\.name), [.allWindows, .savedFocusSet("First")])
    }

    /// A resolver retains its ordered configuration snapshot after a replacement snapshot is built.
    func testResolverRetainsItsConfigurationOrderSnapshot() {
        let firstID = UUID()
        let secondID = UUID()
        let snapshot = makeResolver(sets: [focusSet(firstID, "First"), focusSet(secondID, "Second")])
        let replacement = makeResolver(sets: [focusSet(secondID, "Second"), focusSet(firstID, "First")])

        XCTAssertEqual(snapshot.visibleItems().map(\.identifier), [.allWindows, .focusSet(firstID), .focusSet(secondID)])
        XCTAssertEqual(replacement.visibleItems().map(\.identifier), [.allWindows, .focusSet(secondID), .focusSet(firstID)])
    }

    // MARK: - B. Filtering

    /// Saved names use case- and diacritic-insensitive substring matching.
    func testFilterMatchesSavedSetNamesCaseAndDiacriticInsensitively() {
        let setID = UUID()
        let resolver = makeResolver(sets: [focusSet(setID, "Résumé")])

        XCTAssertEqual(resolver.visibleItems(matching: "RESUME").map(\.identifier), [.focusSet(setID)])
        XCTAssertEqual(resolver.visibleItems(matching: "sum").map(\.identifier), [.focusSet(setID)])
        XCTAssertEqual(resolver.visibleItems(matching: "missing"), [])
    }

    /// Injected localized built-in names participate in the same case- and diacritic-insensitive search.
    func testFilterMatchesInjectedBuiltInNamesCaseAndDiacriticInsensitively() {
        let names = FocusSetPickerBuiltInNames(
            allWindows: "Toutes les fenêtres",
            unassignedWindows: "Fenêtres sans ensemble")
        let resolver = makeResolver(
            counts: [.unassigned: 1],
            builtInNames: names)

        XCTAssertEqual(
            resolver.visibleItems(matching: "FENETRES").map(\.identifier),
            [.allWindows, .unassignedWindows])
        XCTAssertEqual(resolver.visibleItems(matching: "ENSEMBLE").map(\.identifier), [.unassignedWindows])
    }

    /// An empty query preserves every item in its stable snapshot order.
    func testEmptyFilterKeepsEveryPickerItem() {
        let setID = UUID()
        let resolver = makeResolver(
            sets: [focusSet(setID, "Writing")],
            counts: [.unassigned: 1])

        XCTAssertEqual(
            resolver.visibleItems(matching: "").map(\.identifier),
            [.allWindows, .focusSet(setID), .unassignedWindows])
    }

    // MARK: - C. Selection navigation

    /// Selection indexes clamp to the nearest visible item and disappear for an empty list.
    func testSelectionIndexClampsToVisibleItemBounds() {
        XCTAssertEqual(FocusSetPickerResolver.clampedSelectionIndex(nil, itemCount: 3), 0)
        XCTAssertEqual(FocusSetPickerResolver.clampedSelectionIndex(-1, itemCount: 3), 0)
        XCTAssertEqual(FocusSetPickerResolver.clampedSelectionIndex(1, itemCount: 3), 1)
        XCTAssertEqual(FocusSetPickerResolver.clampedSelectionIndex(5, itemCount: 3), 2)
        XCTAssertNil(FocusSetPickerResolver.clampedSelectionIndex(0, itemCount: 0))
    }

    /// Arrow-style movement wraps at either edge and chooses a sensible edge without selection.
    func testNavigationCyclesWithinVisibleItemBounds() {
        XCTAssertEqual(
            FocusSetPickerResolver.cycledSelectionIndex(0, direction: .previous, itemCount: 3),
            2)
        XCTAssertEqual(
            FocusSetPickerResolver.cycledSelectionIndex(2, direction: .next, itemCount: 3),
            0)
        XCTAssertEqual(
            FocusSetPickerResolver.cycledSelectionIndex(nil, direction: .previous, itemCount: 3),
            2)
        XCTAssertEqual(
            FocusSetPickerResolver.cycledSelectionIndex(nil, direction: .next, itemCount: 3),
            0)
        XCTAssertNil(FocusSetPickerResolver.cycledSelectionIndex(0, direction: .next, itemCount: 0))
    }

    // MARK: - D. Confirmation safety

    /// Confirmation resolves only an exact selected identifier that remains visible under the query.
    func testConfirmationRequiresAnExactCurrentlyVisibleIdentifier() {
        let alphaID = UUID()
        let betaID = UUID()
        let resolver = makeResolver(sets: [focusSet(alphaID, "Alpha"), focusSet(betaID, "Beta")])

        XCTAssertEqual(
            resolver.confirmedScope(selectedIdentifier: .focusSet(alphaID), matching: "alpha"),
            .set(id: alphaID))
        XCTAssertNil(resolver.confirmedScope(selectedIdentifier: .focusSet(betaID), matching: "alpha"))
        XCTAssertEqual(resolver.confirmedScope(selectedIdentifier: .allWindows), .allWindows)
    }

    /// A deleted set identifier cannot fall through to a replacement item's index or scope.
    func testStaleSetIdentifierNeverConfirmsAReplacementSet() {
        let deletedID = UUID()
        let replacementID = UUID()
        let resolver = makeResolver(sets: [focusSet(replacementID, "Replacement")])

        XCTAssertNil(resolver.confirmedItem(selectedIdentifier: .focusSet(deletedID)))
        XCTAssertNil(resolver.confirmedScope(selectedIdentifier: .focusSet(deletedID)))
        XCTAssertEqual(
            resolver.confirmedScope(selectedIdentifier: .focusSet(replacementID)),
            .set(id: replacementID))
    }

    // MARK: - E. Presentation ownership and input

    /// Removing an unowned picker is a no-op, while one owned removal restores ordinary state once.
    func testPanelRemovalRestoresOrdinaryStateExactlyOnce() {
        let firstRemoval = FocusSetPickerPresentationPolicy.remove(.owned)
        let repeatedRemoval = FocusSetPickerPresentationPolicy.remove(firstRemoval.nextOwnership)

        XCTAssertEqual(
            firstRemoval,
            FocusSetPickerPanelRemovalDecision(
                nextOwnership: .unowned,
                shouldRestoreOrdinaryState: true))
        XCTAssertEqual(
            repeatedRemoval,
            FocusSetPickerPanelRemovalDecision(
                nextOwnership: .unowned,
                shouldRestoreOrdinaryState: false))
    }

    /// Picker rows stay out of key-view traversal so the shared search field owns keyboard input.
    func testPickerRowsStayOutOfKeyViewTraversal() {
        XCTAssertFalse(FocusSetPickerPresentationPolicy.rowsParticipateInKeyViewLoop)
    }

    private func makeResolver(sets: [FocusSet] = [],
                              counts: [FocusSetScope: Int] = [:],
                              builtInNames: FocusSetPickerBuiltInNames? = nil) -> FocusSetPickerResolver {
        FocusSetPickerResolver(
            configuration: FocusSetsConfiguration(sets: sets),
            candidateCounts: counts,
            builtInNames: builtInNames ?? self.builtInNames)
    }

    private func focusSet(_ id: UUID, _ name: String) -> FocusSet {
        FocusSet(id: id, name: name, rules: [])
    }
}
