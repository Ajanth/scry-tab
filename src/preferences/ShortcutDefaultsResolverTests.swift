import XCTest

final class ShortcutDefaultsResolverTests: XCTestCase {
    func testShortcutOneDefaultsToCommandTabAcrossAllApps() {
        let expected = ShortcutDefaultConfiguration(
            holdKeyEquivalent: "⌘", nextWindowKeyEquivalent: "⇥", appScope: .all)
        XCTAssertEqual(ShortcutDefaultsResolver.resolve(at: 0), expected)
    }

    func testShortcutTwoDefaultsToOptionTabForTheActiveApp() {
        let expected = ShortcutDefaultConfiguration(
            holdKeyEquivalent: "⌥", nextWindowKeyEquivalent: "⇥", appScope: .active)
        XCTAssertEqual(ShortcutDefaultsResolver.resolve(at: 1), expected)
    }

    func testUnusedShortcutsPreserveLegacyScopeDefaults() {
        let third = ShortcutDefaultConfiguration(
            holdKeyEquivalent: "⌥", nextWindowKeyEquivalent: "", appScope: .nonActive)
        let later = ShortcutDefaultConfiguration(
            holdKeyEquivalent: "⌥", nextWindowKeyEquivalent: "", appScope: .all)
        XCTAssertEqual(ShortcutDefaultsResolver.resolve(at: 2), third)
        XCTAssertEqual(ShortcutDefaultsResolver.resolve(at: 3), later)
    }
}
