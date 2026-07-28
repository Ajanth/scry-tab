import XCTest

final class AccessibilitySettingsGuideTrackingTests: XCTestCase {
    /// settings present → trackSettings for any prior miss count and didPresent value.
    func testSettingsPresentTracksRegardlessOfMissesAndDidPresent() {
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: true, didPresentOverlay: false, consecutiveMisses: 0),
            .trackSettings)
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: true, didPresentOverlay: false, consecutiveMisses: 39),
            .trackSettings)
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: true, didPresentOverlay: true, consecutiveMisses: 9),
            .trackSettings)
    }

    /// absent, not yet presented, below threshold → awaitSettings with incremented count.
    func testAbsentNotPresentedBelowThresholdAwaits() {
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: false, didPresentOverlay: false, consecutiveMisses: 0),
            .awaitSettings(missCount: 1))
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: false, didPresentOverlay: false, consecutiveMisses: 38),
            .awaitSettings(missCount: 39))
    }

    /// absent, not yet presented, at threshold → endSession.
    func testAbsentNotPresentedAtThresholdEndsSession() {
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: false,
                didPresentOverlay: false,
                consecutiveMisses: AccessibilitySettingsGuideTracking.missThresholdBeforePresent - 1),
            .endSession)
    }

    /// absent, already presented, below threshold → hideOverlay with incremented count.
    func testAbsentAlreadyPresentedBelowThresholdHidesOverlay() {
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: false, didPresentOverlay: true, consecutiveMisses: 0),
            .hideOverlay(missCount: 1))
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: false, didPresentOverlay: true, consecutiveMisses: 8),
            .hideOverlay(missCount: 9))
    }

    /// absent, already presented, at threshold → endSession.
    func testAbsentAlreadyPresentedAtThresholdEndsSession() {
        XCTAssertEqual(
            AccessibilitySettingsGuideTracking.tick(
                settingsPresent: false,
                didPresentOverlay: true,
                consecutiveMisses: AccessibilitySettingsGuideTracking.missThresholdAfterPresent - 1),
            .endSession)
    }
}
