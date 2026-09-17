import XCTest

final class MenubarVisibilityPreferenceTests: XCTestCase {
    func testKeyStaysStableBecauseRenamingItOrphansTheStoredSetting() {
        XCTAssertEqual(MenubarVisibilityPreference.key, "showMenubarIcon")
    }

    func testDefaultShowsTheMenuBarIcon() {
        XCTAssertEqual(Bool(MenubarVisibilityPreference.defaultValue), true)
    }

    func testDefaultIsALiteralTheStringBackedReaderCanParse() {
        XCTAssertTrue(["true", "false"].contains(MenubarVisibilityPreference.defaultValue))
    }
}
