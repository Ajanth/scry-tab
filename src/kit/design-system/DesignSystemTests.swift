import Cocoa
import XCTest

final class DesignSystemTests: XCTestCase {
    func testComponentStatePrecedence() {
        XCTAssertEqual(DesignComponentState(isEnabled: false, isPressed: true, isSelected: true, isHovered: true).resolvedKind, .disabled)
        XCTAssertEqual(DesignComponentState(isPressed: true, isSelected: true, isHovered: true).resolvedKind, .pressed)
        XCTAssertEqual(DesignComponentState(isSelected: true, isHovered: true).resolvedKind, .selected)
        XCTAssertEqual(DesignComponentState(isHovered: true).resolvedKind, .hovered)
        XCTAssertEqual(DesignComponentState().resolvedKind, .normal)
    }

    func testReduceMotionRemovesSpatialOffsetAndShortensDurations() {
        XCTAssertEqual(DesignMotion.distance(.overlayOffset, reduceMotion: true), 0)
        XCTAssertEqual(DesignMotion.duration(.normal, reduceMotion: true), 0.05)
        XCTAssertEqual(DesignMotion.duration(.normal, reduceMotion: false), 0.2)
    }

    func testIncreaseContrastStrengthensNormalBorder() {
        let normal = DesignSystemEnvironment(colorScheme: .light, accessibility: DesignAccessibilityOptions(increaseContrast: false, reduceTransparency: false, reduceMotion: false))
        let highContrast = DesignSystemEnvironment(colorScheme: .light, accessibility: DesignAccessibilityOptions(increaseContrast: true, reduceTransparency: false, reduceMotion: false))
        let normalStyle = DesignSurfaceStyle.resolve(role: .flat, state: DesignComponentState(), environment: normal)
        let highContrastStyle = DesignSurfaceStyle.resolve(role: .flat, state: DesignComponentState(), environment: highContrast)
        XCTAssertEqual(normalStyle.borderWidth, 1)
        XCTAssertEqual(highContrastStyle.borderWidth, 1.5)
    }

    func testWindowTintUsesMultiplyBlendMode() {
        let surface = MaterialSurfaceView(role: .window)
        XCTAssertEqual(surface.tintCompositingFilterForTests as? String, "multiplyBlendMode")
    }

    func testFocusedStateAddsIndependentOutline() {
        let environment = DesignSystemEnvironment(colorScheme: .light, accessibility: DesignAccessibilityOptions(increaseContrast: false, reduceTransparency: false, reduceMotion: false))
        let focused = DesignComponentState(isHovered: true, isFocused: true)
        let style = DesignSurfaceStyle.resolve(role: .selection, state: focused, environment: environment)
        XCTAssertEqual(focused.resolvedKind, .hovered)
        XCTAssertEqual(style.focusRingRole, .accentPrimary)
        XCTAssertEqual(style.focusRingWidth, DesignMetric.focusRingWidth)
    }

    func testSidebarShellMetricsMatchSpecification() {
        XCTAssertEqual(DesignMetric.sidebarGroupGap, 24)
        XCTAssertEqual(DesignMetric.sidebarGroupLabelToItemsGap, 4)
        XCTAssertEqual(DesignMetric.sidebarIconRadius, 6)
    }

    func testWindowRoleHasGradientButNoBorderLayer() {
        let surface = MaterialSurfaceView(role: .window)
        XCTAssertNotNil(surface.layerIdentity.gradientLayer)
        XCTAssertNil(surface.layerIdentity.borderLayer)
    }

    func testIconRoleHasGradientAndBorderLayers() {
        let surface = MaterialSurfaceView(role: .icon)
        XCTAssertNotNil(surface.layerIdentity.gradientLayer)
        XCTAssertNotNil(surface.layerIdentity.borderLayer)
    }

    func testAccessibilityUpdateRetainsLayerIdentities() {
        let surface = MaterialSurfaceView(role: .icon)
        let before = surface.layerIdentity
        surface.accessibilityDisplayOptionsDidChange(DesignAccessibilityOptions(increaseContrast: true, reduceTransparency: true, reduceMotion: true))
        XCTAssertEqual(surface.layerIdentity, before)
    }

    func testDirectAppearanceRefreshRetainsLayerIdentities() {
        let surface = MaterialSurfaceView(role: .window)
        let before = surface.layerIdentity
        surface.refreshAppearance()
        XCTAssertEqual(surface.layerIdentity, before)
    }

    func testRoleChangeUpdatesOptionalLayerPresence() {
        let surface = MaterialSurfaceView(role: .window)
        XCTAssertNotNil(surface.layerIdentity.gradientLayer)
        XCTAssertNil(surface.layerIdentity.borderLayer)
        surface.role = .icon
        XCTAssertNotNil(surface.layerIdentity.gradientLayer)
        XCTAssertNotNil(surface.layerIdentity.borderLayer)
        surface.role = .flat
        XCTAssertNil(surface.layerIdentity.gradientLayer)
        XCTAssertNotNil(surface.layerIdentity.borderLayer)
    }
}
