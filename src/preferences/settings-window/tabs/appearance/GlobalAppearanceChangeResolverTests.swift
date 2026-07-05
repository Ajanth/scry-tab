import XCTest

final class GlobalAppearanceChangeResolverTests: XCTestCase {

    /// Clicking the current global value does not request confirmation even when matching overrides exist.
    func testNoOpClickSkipsWhenOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "1", newValue: "1", hasExplicitOverrides: true, rememberedOverrideChoice: true)
        XCTAssertEqual(decision, .skip)
    }

    /// A control action with no readable new value does not request confirmation.
    func testMissingNewValueSkips() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "1", newValue: nil, hasExplicitOverrides: true, rememberedOverrideChoice: true)
        XCTAssertEqual(decision, .skip)
    }

    /// A changed global value with no matching overrides applies without a dialog.
    func testChangedValueAppliesWithoutConfirmationWhenNoOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "0", newValue: "1", hasExplicitOverrides: false, rememberedOverrideChoice: nil)
        XCTAssertEqual(decision, .applyWithoutConfirmation)
    }

    /// A changed global value with matching explicit overrides requests confirmation.
    func testChangedValueConfirmsWhenOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "0", newValue: "1", hasExplicitOverrides: true, rememberedOverrideChoice: nil)
        XCTAssertEqual(decision, .confirmOverrideReset)
    }

    /// A readable new value counts as a change when no previous value was available.
    func testPreviouslyMissingValueStillCountsAsChange() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: nil, newValue: "1", hasExplicitOverrides: true, rememberedOverrideChoice: nil)
        XCTAssertEqual(decision, .confirmOverrideReset)
    }

    /// A changed value with matching overrides and a remembered "remove" choice replays that removal without a dialog.
    func testRememberedChoiceReplaysRemovalWhenOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "0", newValue: "1", hasExplicitOverrides: true, rememberedOverrideChoice: true)
        XCTAssertEqual(decision, .applyRememberedOverrideChoice(removesOverrides: true))
    }

    /// A changed value with matching overrides and a remembered "keep" choice replays keeping them without a dialog.
    func testRememberedChoiceReplaysKeepWhenOverridesExist() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "0", newValue: "1", hasExplicitOverrides: true, rememberedOverrideChoice: false)
        XCTAssertEqual(decision, .applyRememberedOverrideChoice(removesOverrides: false))
    }

    /// A remembered choice has no effect without matching overrides; the change still applies without a dialog.
    func testRememberedChoiceIgnoredWithoutOverrides() {
        let decision = GlobalAppearanceChangeResolver.decide(
            previousValue: "0", newValue: "1", hasExplicitOverrides: false, rememberedOverrideChoice: true)
        XCTAssertEqual(decision, .applyWithoutConfirmation)
    }
}
