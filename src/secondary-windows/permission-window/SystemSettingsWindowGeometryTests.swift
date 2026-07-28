import XCTest

final class SystemSettingsWindowGeometryTests: XCTestCase {
    /// Known CG frame on a matching screen flips Y into AppKit coords and keeps that screen’s visibleFrame.
    func testConvertsMatchingScreenWithYFlipped() {
        let screen = SystemSettingsScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 877),
            cgBounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let cgFrame = CGRect(x: 100, y: 50, width: 800, height: 600)
        let result = SystemSettingsWindowGeometry.appKitGeometry(from: cgFrame, screens: [screen])
        XCTAssertEqual(result.frame, CGRect(x: 100, y: 250, width: 800, height: 600))
        XCTAssertEqual(result.visibleFrame, screen.visibleFrame)
    }

    /// When multiple screens intersect, convert on the one with the largest intersection area.
    func testPicksLargestIntersectionScreen() {
        let left = SystemSettingsScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 780),
            cgBounds: CGRect(x: 0, y: 0, width: 1000, height: 800))
        let right = SystemSettingsScreenDescriptor(
            frame: CGRect(x: 1000, y: 0, width: 1200, height: 900),
            visibleFrame: CGRect(x: 1000, y: 0, width: 1200, height: 880),
            cgBounds: CGRect(x: 1000, y: 0, width: 1200, height: 900))
        let cgFrame = CGRect(x: 950, y: 100, width: 400, height: 500)
        let result = SystemSettingsWindowGeometry.appKitGeometry(from: cgFrame, screens: [left, right])
        XCTAssertEqual(result.frame, CGRect(x: 950, y: 300, width: 400, height: 500))
        XCTAssertEqual(result.visibleFrame, right.visibleFrame)
    }

    /// No intersection still converts via the first descriptor (not raw CG).
    func testFallsBackToFirstScreenWhenNoneIntersect() {
        let primary = SystemSettingsScreenDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 23, width: 1440, height: 877),
            cgBounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let secondary = SystemSettingsScreenDescriptor(
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055),
            cgBounds: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        let cgFrame = CGRect(x: -500, y: -400, width: 200, height: 150)
        let result = SystemSettingsWindowGeometry.appKitGeometry(from: cgFrame, screens: [primary, secondary])
        XCTAssertEqual(result.frame, CGRect(x: -500, y: 1150, width: 200, height: 150))
        XCTAssertEqual(result.visibleFrame, primary.visibleFrame)
        XCTAssertNotEqual(result.frame, cgFrame)
    }

    /// Empty screens list → zero frame and visibleFrame.
    func testReturnsZeroWhenScreensEmpty() {
        let result = SystemSettingsWindowGeometry.appKitGeometry(
            from: CGRect(x: 10, y: 20, width: 300, height: 200),
            screens: [])
        XCTAssertEqual(result.frame, .zero)
        XCTAssertEqual(result.visibleFrame, .zero)
    }

    /// width ≤ 320 or height ≤ 240 → ineligible.
    func testEligibilityRejectsSmallFrames() {
        XCTAssertFalse(SystemSettingsWindowGeometry.isEligibleSettingsWindowFrame(
            CGRect(x: 0, y: 0, width: 320, height: 500)))
        XCTAssertFalse(SystemSettingsWindowGeometry.isEligibleSettingsWindowFrame(
            CGRect(x: 0, y: 0, width: 500, height: 240)))
        XCTAssertFalse(SystemSettingsWindowGeometry.isEligibleSettingsWindowFrame(
            CGRect(x: 0, y: 0, width: 200, height: 100)))
    }

    /// width > 320 and height > 240 → eligible.
    func testEligibilityAcceptsLargeFrames() {
        XCTAssertTrue(SystemSettingsWindowGeometry.isEligibleSettingsWindowFrame(
            CGRect(x: 0, y: 0, width: 321, height: 241)))
        XCTAssertTrue(SystemSettingsWindowGeometry.isEligibleSettingsWindowFrame(
            CGRect(x: 10, y: 20, width: 800, height: 600)))
    }
}
