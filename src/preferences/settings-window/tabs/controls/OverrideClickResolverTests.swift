import XCTest

/// Pins the override state-machine semantics that the per-shortcut Appearance section relies on.
/// Selecting the global value removes an override; selecting a non-global value writes one.
///
/// `OverrideClickResolver.decide` is the pure decision kernel: given the click's new index,
/// the override's set/unset state, the stored override value (if any), the current global
/// index, and a function that maps an index to its persisted string value, it returns either
/// `.skip`, `.remove`, or `.write(value:)`.
final class OverrideClickResolverTests: XCTestCase {

    private let identity: (Int) -> String = { String($0) }

    // MARK: - Rule 1: clicking the displayed value is a no-op

    /// Override is UNSET, segment displays the global. User clicks the same value.
    func testNoOpWhenClickingDisplayedGlobal() {
        let decision = OverrideClickResolver.decide(
            newIndex: 1,
            hasOverride: false,
            storedOverrideValue: "0",
            globalIndex: 1,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .skip)
    }

    /// Override is SET, segment displays the override value. User clicks the same value.
    func testNoOpWhenClickingDisplayedOverride() {
        let decision = OverrideClickResolver.decide(
            newIndex: 2,
            hasOverride: true,
            storedOverrideValue: "2",
            globalIndex: 0,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .skip)
    }

    /// The registered default for an override key can differ from the global value. Clicking the
    /// currently-displayed value (= the global) must still be a no-op even though the new value
    /// differs from `UserDefaults[key]` (which holds the registered default when no override is
    /// set). The resolver derives the displayed value from `hasOverride` + globalIndex, NOT from
    /// UserDefaults.
    func testNoOpWhenRegisteredDefaultDiffersFromGlobal() {
        let decision = OverrideClickResolver.decide(
            newIndex: 3,                    // user clicks Auto (currently displayed)
            hasOverride: false,
            storedOverrideValue: "1",       // registered default = Medium (= UserDefaults value)
            globalIndex: 3,                 // global = Auto = displayed
            valueAtIndex: identity)
        XCTAssertEqual(decision, .skip,
            "regression: previously `controlWasChanged` compared against UserDefaults (= registered " +
            "default) and incorrectly wrote an override when default != global.")
    }

    // MARK: - Rule 2: clicking a different value writes the override

    /// Override is UNSET, displayed = global. User clicks a different value.
    func testWriteOverrideOnClickAwayFromGlobal() {
        let decision = OverrideClickResolver.decide(
            newIndex: 2,
            hasOverride: false,
            storedOverrideValue: "0",
            globalIndex: 0,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .write(value: "2"))
    }

    /// Override is SET, displayed = override value. User clicks a different value — the override
    /// is updated to the new value (still SET).
    func testWriteOverrideOnClickAwayFromExistingOverride() {
        let decision = OverrideClickResolver.decide(
            newIndex: 0,
            hasOverride: true,
            storedOverrideValue: "3",
            globalIndex: 1,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .write(value: "0"))
    }

    /// Regression for the user-reported scenario: Override is UNSET, global = Focus (0), segment
    /// displays Focus. User clicks Hold (1). The override must be SET to Hold even though the
    /// registered default for `shortcutStyleOverride` happens to be Hold too.
    func testWritesOverrideWhenClickValueEqualsRegisteredDefault() {
        let decision = OverrideClickResolver.decide(
            newIndex: 1,                    // user clicks Hold
            hasOverride: false,
            storedOverrideValue: "1",       // registered default = Hold (same as new value)
            globalIndex: 0,                 // global = Focus (≠ Hold)
            valueAtIndex: identity)
        XCTAssertEqual(decision, .write(value: "1"),
            "regression: previously `controlWasChanged` saw `newValue == UserDefaults[key]` " +
            "(both equal the registered default) and skipped the write, leaving the override unset.")
    }

    // MARK: - Rule 3: selecting the global value removes the override

    /// Override and global coincide. Clicking that value removes the redundant override.
    func testClickingGlobalClearsMatchingOverride() {
        let decision = OverrideClickResolver.decide(
            newIndex: 1,
            hasOverride: true,
            storedOverrideValue: "1",
            globalIndex: 1,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .remove)
    }

    /// Override differs from global. Selecting the global value resumes inheritance.
    func testClickingGlobalClearsDifferentOverride() {
        let decision = OverrideClickResolver.decide(
            newIndex: 1,
            hasOverride: true,
            storedOverrideValue: "3",
            globalIndex: 1,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .remove)
    }

    // MARK: - Encoding & defensive handling

    /// The resolver doesn't assume the persisted value is the index — it asks `valueAtIndex` to
    /// produce the string. Verifies switching encoders works.
    func testValueAtIndexEncoderIsHonored() {
        let decision = OverrideClickResolver.decide(
            newIndex: 2,
            hasOverride: false,
            storedOverrideValue: nil,
            globalIndex: 0,
            valueAtIndex: { ["small", "medium", "large", "auto"][$0] })
        XCTAssertEqual(decision, .write(value: "large"))
    }

    /// When the stored override value is malformed (not a valid Int string), the resolver
    /// treats the override as "displayed = -1" — so any positive newIndex will write. This
    /// guards against corrupted UserDefaults entries not silently turning all clicks into
    /// no-ops.
    func testStoredOverrideMalformedFallsThroughToWrite() {
        let decision = OverrideClickResolver.decide(
            newIndex: 0,
            hasOverride: true,
            storedOverrideValue: "not-a-number",
            globalIndex: 1,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .write(value: "0"))
    }

    /// When override is UNSET and no stored value exists (nil), the resolver should still use
    /// the global as the displayed value. Verifies nil handling doesn't accidentally fall through
    /// to writing when clicking the displayed (= global) value.
    func testNilStoredOverrideWithMatchingGlobalIsSkip() {
        let decision = OverrideClickResolver.decide(
            newIndex: 2,
            hasOverride: false,
            storedOverrideValue: nil,
            globalIndex: 2,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .skip)
    }

    /// A nil stored value with an existing override still clears safely when global is selected.
    func testHasOverrideTrueWithNilStoredClearsWhenGlobalClicked() {
        let decision = OverrideClickResolver.decide(
            newIndex: 0,
            hasOverride: true,
            storedOverrideValue: nil,
            globalIndex: 0,
            valueAtIndex: identity)
        XCTAssertEqual(decision, .remove)
    }
}
