import Foundation

enum AccessibilitySettingsGuideTracking {
    /// ~6s at 150ms ticks — allow System Settings to launch before first sighting.
    static let missThresholdBeforePresent = 40
    /// ~1.5s at 150ms ticks — end after Settings was seen then disappears.
    static let missThresholdAfterPresent = 10

    enum TickResult: Equatable {
        case awaitSettings(missCount: Int)
        case trackSettings
        case hideOverlay(missCount: Int)
        case endSession
    }

    static func tick(
        settingsPresent: Bool,
        didPresentOverlay: Bool,
        consecutiveMisses: Int
    ) -> TickResult {
        if settingsPresent {
            return .trackSettings
        }
        let nextMisses = consecutiveMisses + 1
        let threshold = didPresentOverlay ? missThresholdAfterPresent : missThresholdBeforePresent
        if nextMisses >= threshold {
            return .endSession
        }
        if didPresentOverlay {
            return .hideOverlay(missCount: nextMisses)
        }
        return .awaitSettings(missCount: nextMisses)
    }
}
