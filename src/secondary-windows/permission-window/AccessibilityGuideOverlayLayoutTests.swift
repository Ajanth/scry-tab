import XCTest

final class AccessibilityGuideOverlayLayoutTests: XCTestCase {
    private let gap = CGFloat(12)
    private let panelSize = CGSize(width: 320, height: 220)
    /// Must match `AccessibilityGuideOverlayLayout.verticalCenterFraction`.
    private let verticalCenterFraction = CGFloat(0.58)

    private func placement(settings: CGRect, visible: CGRect, size: CGSize? = nil) -> AccessibilityGuideOverlayLayout.Placement {
        AccessibilityGuideOverlayLayout.placement(
            panelSize: size ?? panelSize,
            settingsFrame: settings,
            visibleFrame: visible,
            gap: gap)
    }

    /// Panel parks on the trailing (right) edge with a gap when there is room, vertically biased above center.
    func testPrefersTrailingEdgeBesideSettings() {
        let settings = CGRect(x: 200, y: 100, width: 800, height: 600)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let p = placement(settings: settings, visible: visible)
        let expectedMidY = settings.minY + settings.height * verticalCenterFraction
        XCTAssertEqual(p.edge, .trailing)
        XCTAssertEqual(p.frame.minX, settings.maxX + gap, accuracy: 0.001)
        XCTAssertEqual(p.frame.midY, expectedMidY, accuracy: 0.001)
        XCTAssertGreaterThan(p.frame.midY, settings.midY)
        XCTAssertEqual(p.frame.size, panelSize)
        XCTAssertFalse(p.frame.intersects(settings))
    }

    /// When the trailing side has no room, the panel flips to the leading edge and stays clear of the window.
    func testFallsBackToLeadingEdgeWhenTrailingBlocked() {
        let settings = CGRect(x: 620, y: 100, width: 800, height: 600)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let p = placement(settings: settings, visible: visible)
        XCTAssertEqual(p.edge, .leading)
        XCTAssertEqual(p.frame.maxX, settings.minX - gap, accuracy: 0.001)
        XCTAssertFalse(p.frame.intersects(settings))
    }

    /// With no room on either side, the panel picks the roomier side and clamps inside the visible frame.
    func testClampsIntoVisibleFrameWhenNoEdgeFits() {
        let settings = CGRect(x: 100, y: 60, width: 1240, height: 700)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let p = placement(settings: settings, visible: visible)
        XCTAssertGreaterThanOrEqual(p.frame.minX, visible.minX + gap - 0.001)
        XCTAssertLessThanOrEqual(p.frame.maxX, visible.maxX - gap + 0.001)
        XCTAssertGreaterThanOrEqual(p.frame.minY, visible.minY + gap - 0.001)
        XCTAssertLessThanOrEqual(p.frame.maxY, visible.maxY - gap + 0.001)
    }

    /// A settings window near the top of the screen still keeps the panel on-screen vertically.
    func testClampsVerticallyIntoVisibleFrame() {
        let settings = CGRect(x: 200, y: 780, width: 800, height: 600)
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let p = placement(settings: settings, visible: visible)
        XCTAssertLessThanOrEqual(p.frame.maxY, visible.maxY - gap + 0.001)
        XCTAssertGreaterThanOrEqual(p.frame.minY, visible.minY + gap - 0.001)
    }
}
