import XCTest

final class DesignSystemTests: XCTestCase {
    func testMaterialTintAlphaUsesLightAndDarkValues() {
        XCTAssertEqual(DesignSystem.materialTintAlpha(NSAppearance(named: .aqua)), 0.025, accuracy: 0.0001)
        if #available(macOS 10.14, *) {
            XCTAssertEqual(DesignSystem.materialTintAlpha(NSAppearance(named: .darkAqua)), 0.10, accuracy: 0.0001)
        }
    }

    func testSettingsPageIconDescriptorsFollowPageIdentity() {
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .appearance).symbolValue, "􀝥")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .controls).symbolValue, "􀆔")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .general).symbolValue, "􀣋")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .exceptions).symbolValue, "􀉻")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .about).symbolValue, "􀅴")
    }

    func testStandardGeometryTokensMatchMigrationPlan() {
        XCTAssertEqual(DesignSystem.Metrics.windowRadius, 12)
        XCTAssertEqual(DesignSystem.Metrics.sectionRadius, 12)
        XCTAssertEqual(DesignSystem.Metrics.joinedOuterRowRadius, 8)
        XCTAssertEqual(DesignSystem.Metrics.sidebarSelectionRadius, 12)
        XCTAssertEqual(DesignSystem.Metrics.sidebarIconRadius, 6)
        XCTAssertEqual(DesignSystem.Metrics.standardControlMinHeight, 32)
    }
}
