import XCTest

final class AnimatedSelectionResolverTests: XCTestCase {

    /// Advancing from a middle index moves to the next one.
    func testCyclesToNextIndex() {
        XCTAssertEqual(AnimatedSelectionResolver.nextFocusedIndex(current: 1, count: 5), 2)
    }

    /// Advancing from the last index wraps around to zero.
    func testWrapsFromLastIndexToFirst() {
        XCTAssertEqual(AnimatedSelectionResolver.nextFocusedIndex(current: 4, count: 5), 0)
    }

    /// A single item always advances to itself.
    func testHandlesSingleItem() {
        XCTAssertEqual(AnimatedSelectionResolver.nextFocusedIndex(current: 0, count: 1), 0)
    }

    /// Zero items resolves to index zero instead of dividing by zero.
    func testHandlesZeroItemsWithoutCrashing() {
        XCTAssertEqual(AnimatedSelectionResolver.nextFocusedIndex(current: 0, count: 0), 0)
    }

    /// An out-of-range current index is normalized before advancing.
    func testNormalizesOutOfRangeCurrentIndex() {
        XCTAssertEqual(AnimatedSelectionResolver.nextFocusedIndex(current: 9, count: 3), 1)
    }

    /// All four conditions favorable resolves to running.
    func testRunsWhenNothingBlocksIt() {
        XCTAssertTrue(AnimatedSelectionResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: true, prefersReducedMotion: false, shouldAdvance: true))
    }

    /// A manual pause stops the loop regardless of the other conditions.
    func testManualPauseStopsIt() {
        XCTAssertFalse(AnimatedSelectionResolver.shouldRun(
            isManuallyPaused: true, isWindowVisible: true, prefersReducedMotion: false, shouldAdvance: true))
    }

    /// A not-visible host window stops the loop.
    func testHiddenWindowStopsIt() {
        XCTAssertFalse(AnimatedSelectionResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: false, prefersReducedMotion: false, shouldAdvance: true))
    }

    /// Reduce Motion stops the loop regardless of the other conditions.
    func testReducedMotionStopsIt() {
        XCTAssertFalse(AnimatedSelectionResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: true, prefersReducedMotion: true, shouldAdvance: true))
    }

    /// A caller-supplied shouldAdvance gate of false stops the loop.
    func testShouldAdvanceFalseStopsIt() {
        XCTAssertFalse(AnimatedSelectionResolver.shouldRun(
            isManuallyPaused: false, isWindowVisible: true, prefersReducedMotion: false, shouldAdvance: false))
    }
}
