import Foundation

enum AnimatedSelectionResolver {
    static func scaleToFit(contentSize: CGSize,
                           availableSize: CGSize,
                           maximumWidthRatio: CGFloat,
                           maximumHeightRatio: CGFloat) -> CGFloat {
        guard contentSize.width > 0, contentSize.height > 0,
              availableSize.width > 0, availableSize.height > 0,
              maximumWidthRatio > 0, maximumHeightRatio > 0 else { return 1 }
        let widthScale = availableSize.width * maximumWidthRatio / contentSize.width
        let heightScale = availableSize.height * maximumHeightRatio / contentSize.height
        return min(1, min(widthScale, heightScale))
    }

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
