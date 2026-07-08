import Foundation

enum AnimatedSelectionResolver {
    static func nextFocusedIndex(current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let normalizedCurrent = ((current % count) + count) % count
        return (normalizedCurrent + 1) % count
    }

    static func shouldRun(isManuallyPaused: Bool,
                          isWindowVisible: Bool,
                          prefersReducedMotion: Bool,
                          shouldAdvance: Bool) -> Bool {
        !isManuallyPaused && isWindowVisible && !prefersReducedMotion && shouldAdvance
    }
}
