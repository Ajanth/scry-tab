import XCTest

final class OnboardingTourResolverTests: XCTestCase {

    /// Back from Focus Sets remains on Focus Sets.
    func testBackFromFirstPageStaysOnFirstPage() {
        XCTAssertEqual(OnboardingTourResolver.back(from: .focusSets), .focusSets)
    }

    /// Back from Appearance and Controls moves to each previous page.
    func testBackFromLaterPagesMovesToPreviousPage() {
        XCTAssertEqual(OnboardingTourResolver.back(from: .appearance), .focusSets)
        XCTAssertEqual(OnboardingTourResolver.back(from: .controls), .appearance)
    }

    /// Next from Focus Sets and Appearance shows each following page.
    func testNextFromFirstAndMiddlePagesAdvances() {
        XCTAssertEqual(OnboardingTourResolver.next(from: .focusSets), .show(.appearance))
        XCTAssertEqual(OnboardingTourResolver.next(from: .appearance), .show(.controls))
    }

    /// Next from Controls finishes the tour.
    func testNextFromFinalPageFinishes() {
        XCTAssertEqual(OnboardingTourResolver.next(from: .controls), .finish)
    }

    /// An installation without a shown initial experience presents the tour.
    func testNewInstallPresentsAutomatically() {
        XCTAssertTrue(OnboardingTourResolver.shouldPresentAutomatically(initialExperienceShown: false))
    }

    /// An installation with a shown initial experience does not present the tour.
    func testExistingInstallDoesNotPresentAutomatically() {
        XCTAssertFalse(OnboardingTourResolver.shouldPresentAutomatically(initialExperienceShown: true))
    }

    /// A visible window with Reduce Motion off allows animation.
    func testVisibleWindowAnimates() {
        XCTAssertTrue(OnboardingTourResolver.shouldAnimate(windowVisible: true, reduceMotion: false))
    }

    /// A hidden window does not animate.
    func testHiddenWindowDoesNotAnimate() {
        XCTAssertFalse(OnboardingTourResolver.shouldAnimate(windowVisible: false, reduceMotion: false))
    }

    /// Reduce Motion prevents animation for a visible window.
    func testReduceMotionDoesNotAnimate() {
        XCTAssertFalse(OnboardingTourResolver.shouldAnimate(windowVisible: true, reduceMotion: true))
    }

    /// Focus Set autoplay advances through each remaining tab without wrapping.
    func testFocusSetAutoplayAdvancesWithoutWrapping() {
        XCTAssertEqual(OnboardingTourResolver.nextAutoplayIndex(after: 0, count: 3), 1)
        XCTAssertEqual(OnboardingTourResolver.nextAutoplayIndex(after: 1, count: 3), 2)
        XCTAssertNil(OnboardingTourResolver.nextAutoplayIndex(after: 2, count: 3))
    }

    /// Invalid or empty Focus Set autoplay input stops instead of selecting an invalid tab.
    func testFocusSetAutoplayRejectsInvalidIndexes() {
        XCTAssertNil(OnboardingTourResolver.nextAutoplayIndex(after: -1, count: 3))
        XCTAssertNil(OnboardingTourResolver.nextAutoplayIndex(after: 0, count: 0))
        XCTAssertNil(OnboardingTourResolver.nextAutoplayIndex(after: 3, count: 3))
    }

    /// Skip opens no Settings destination, Done opens Appearance, and Explore Focus Sets opens Focus Sets.
    func testTourCompletionsResolveSettingsDestinations() {
        XCTAssertNil(OnboardingTourResolver.settingsRoute(for: .skip))
        XCTAssertEqual(OnboardingTourResolver.settingsRoute(for: .openAppearance), .appearance)
        XCTAssertEqual(OnboardingTourResolver.settingsRoute(for: .exploreFocusSets), .focusSets)
    }
}
