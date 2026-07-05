import Foundation

enum AppearanceLivePreviewResolver {
    static func nextFocusedIndex(current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let normalizedCurrent = ((current % count) + count) % count
        return (normalizedCurrent + 1) % count
    }

    static func shouldRun(isManuallyPaused: Bool,
                          isWindowVisible: Bool,
                          isSwitcherActive: Bool,
                          prefersReducedMotion: Bool) -> Bool {
        !isManuallyPaused && isWindowVisible && !isSwitcherActive && !prefersReducedMotion
    }
}
