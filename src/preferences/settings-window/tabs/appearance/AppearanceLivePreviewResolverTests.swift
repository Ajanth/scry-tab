import XCTest

final class AppearanceLivePreviewResolverTests: XCTestCase {

    /// Advancing from a middle index moves to the next one.
    func testCyclesToNextIndex() {
        let next = AppearanceLivePreviewResolver.nextFocusedIndex(current: 1, count: 5)
        XCTAssertEqual(next, 2)
    }

    /// Advancing from the last index wraps around to zero.
    func testWrapsFromLastIndexToFirst() {
        let next = AppearanceLivePreviewResolver.nextFocusedIndex(current: 4, count: 5)
        XCTAssertEqual(next, 0)
    }

    /// A single tile always advances to itself.
    func testHandlesSingleTile() {
        let next = AppearanceLivePreviewResolver.nextFocusedIndex(current: 0, count: 1)
        XCTAssertEqual(next, 0)
    }

    /// Zero tiles resolves to index zero instead of dividing by zero.
    func testHandlesZeroTilesWithoutCrashing() {
        let next = AppearanceLivePreviewResolver.nextFocusedIndex(current: 0, count: 0)
        XCTAssertEqual(next, 0)
    }

    /// An out-of-range current index (e.g. a style switch shrank the tile count) is normalized before advancing.
    func testNormalizesOutOfRangeCurrentIndex() {
        let next = AppearanceLivePreviewResolver.nextFocusedIndex(current: 9, count: 3)
        XCTAssertEqual(next, 1)
    }

    /// All four conditions favorable resolves to running.
    func testRunsWhenNothingBlocksIt() {
        let shouldRun = AppearanceLivePreviewResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: true, isSwitcherActive: false, prefersReducedMotion: false)
        XCTAssertTrue(shouldRun)
    }

    /// A manual pause stops the loop regardless of the other conditions.
    func testManualPauseStopsIt() {
        let shouldRun = AppearanceLivePreviewResolver.shouldRun(
            isManuallyPaused: true, isWindowVisible: true, isSwitcherActive: false, prefersReducedMotion: false)
        XCTAssertFalse(shouldRun)
    }

    /// A not-visible Settings window stops the loop.
    func testHiddenWindowStopsIt() {
        let shouldRun = AppearanceLivePreviewResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: false, isSwitcherActive: false, prefersReducedMotion: false)
        XCTAssertFalse(shouldRun)
    }

    /// An active switcher session stops the loop.
    func testActiveSwitcherStopsIt() {
        let shouldRun = AppearanceLivePreviewResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: true, isSwitcherActive: true, prefersReducedMotion: false)
        XCTAssertFalse(shouldRun)
    }

    /// Reduce Motion stops the loop regardless of the other conditions.
    func testReducedMotionStopsIt() {
        let shouldRun = AppearanceLivePreviewResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: true, isSwitcherActive: false, prefersReducedMotion: true)
        XCTAssertFalse(shouldRun)
    }
}
