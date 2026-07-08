import Foundation

enum AppearanceLivePreviewResolver {
    static let advanceInterval = TimeInterval(1)

    static func nextFocusedIndex(current: Int, count: Int) -> Int {
        AnimatedSelectionResolver.nextFocusedIndex(current: current, count: count)
    }

    static func shouldRun(isManuallyPaused: Bool,
                          isWindowVisible: Bool,
                          isSwitcherActive: Bool,
                          prefersReducedMotion: Bool) -> Bool {
        AnimatedSelectionResolver.shouldRun(
            isManuallyPaused: isManuallyPaused,
            isWindowVisible: isWindowVisible,
            prefersReducedMotion: prefersReducedMotion,
            shouldAdvance: !isSwitcherActive)
    }
}
