import Cocoa
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

    func testControlGeometryTokensMatchMigrationPlan() {
        XCTAssertEqual(DesignSystem.Metrics.standardControlMinHeight, 32)
        XCTAssertEqual(DesignSystem.Metrics.controlRadius, 6)
    }

    func testSegmentedControlUsesAppOwnedSurface() {
        let control = DesignSystemSegmentedControl(labels: ["One", "Two"], trackingMode: .selectOne, target: nil, action: nil)
        let appKitControl: NSSegmentedControl = control
        XCTAssertEqual(appKitControl.segmentCount, 2)
        XCTAssertTrue(control.drawsAppOwnedSurface)
    }

    func testWindowContentViewLayersMaterialBehindInsetContent() {
        let content = NSView()
        let wrapper = DesignSystemWindowContentView(content: content, topPadding: 10)
        XCTAssertTrue(wrapper.subviews.first is DesignSystemMaterialView)
        XCTAssertTrue(wrapper.subviews.last === content)
        XCTAssertTrue(wrapper.constraints.contains {
            guard let first = $0.firstItem as? NSView, let second = $0.secondItem as? NSView else { return false }
            return first === content && second === wrapper && $0.firstAttribute == .top && $0.secondAttribute == .top && $0.constant == 10
        })
    }
}
