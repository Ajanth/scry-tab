import XCTest

final class AnimatedSelectionResolverTests: XCTestCase {

    /// Content already inside the configured width share keeps its real size.
    func testScaleToFitDoesNotUpscaleForWidth() {
        let scale = AnimatedSelectionResolver.scaleToFit(
            contentSize: CGSize(width: 200, height: 50),
            availableSize: CGSize(width: 400, height: 300),
            maximumWidthRatio: 0.9,
            maximumHeightRatio: 0.9)
        XCTAssertEqual(scale, 1)
    }

    /// Content already inside the configured height share keeps its real size.
    func testScaleToFitDoesNotUpscaleForHeight() {
        let scale = AnimatedSelectionResolver.scaleToFit(
            contentSize: CGSize(width: 50, height: 200),
            availableSize: CGSize(width: 400, height: 300),
            maximumWidthRatio: 0.9,
            maximumHeightRatio: 0.9)
        XCTAssertEqual(scale, 1)
    }

    /// Oversized content shrinks to the tighter configured parent bound.
    func testScaleToFitShrinksOversizedContent() {
        let scale = AnimatedSelectionResolver.scaleToFit(
            contentSize: CGSize(width: 400, height: 200),
            availableSize: CGSize(width: 300, height: 180),
            maximumWidthRatio: 0.9,
            maximumHeightRatio: 0.9)
        XCTAssertEqual(scale, 0.675)
    }

    /// Unlaid-out content keeps its neutral scale instead of producing an invalid transform.
    func testScaleToFitHandlesEmptyContent() {
        let scale = AnimatedSelectionResolver.scaleToFit(
            contentSize: .zero,
            availableSize: CGSize(width: 400, height: 300),
            maximumWidthRatio: 0.9,
            maximumHeightRatio: 0.9)
        XCTAssertEqual(scale, 1)
    }

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
