import XCTest

final class GlobalAppearanceChangeResolverTests: XCTestCase {

    /// Clicking the current global value does not request confirmation even when matching overrides exist.
    func testNoOpClickSkipsWhenOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "1", newValue: "1", hasExplicitOverrides: true)
        XCTAssertEqual(decision, .skip)
    }

    /// A control action with no readable new value does not request confirmation.
    func testMissingNewValueSkips() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "1", newValue: nil, hasExplicitOverrides: true)
        XCTAssertEqual(decision, .skip)
    }

    /// A changed global value with no matching overrides applies without a dialog.
    func testChangedValueAppliesWithoutConfirmationWhenNoOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "0", newValue: "1", hasExplicitOverrides: false)
        XCTAssertEqual(decision, .applyWithoutConfirmation)
    }

    /// A changed global value with matching explicit overrides requests confirmation.
    func testChangedValueConfirmsWhenOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "0", newValue: "1", hasExplicitOverrides: true)
        XCTAssertEqual(decision, .confirmOverrideReset)
    }

    /// A readable new value counts as a change when no previous value was available.
    func testPreviouslyMissingValueStillCountsAsChange() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: nil, newValue: "1", hasExplicitOverrides: true)
        XCTAssertEqual(decision, .confirmOverrideReset)
    }
}
