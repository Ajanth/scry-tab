import XCTest

final class AppearancePreviewStateResolverTests: XCTestCase {
    /// Light theme remains light regardless of the current system appearance.
    func testLightThemeAlwaysResolvesLight() {
        XCTAssertFalse(AppearancePreviewStateResolver.resolvedIsDark(theme: .light, systemIsDark: false))
        XCTAssertFalse(AppearancePreviewStateResolver.resolvedIsDark(theme: .light, systemIsDark: true))
    }

    /// Dark theme remains dark regardless of the current system appearance.
    func testDarkThemeAlwaysResolvesDark() {
        XCTAssertTrue(AppearancePreviewStateResolver.resolvedIsDark(theme: .dark, systemIsDark: false))
        XCTAssertTrue(AppearancePreviewStateResolver.resolvedIsDark(theme: .dark, systemIsDark: true))
    }

    /// System theme follows both light and dark system appearance snapshots.
    func testSystemThemeFollowsSystemAppearance() {
        XCTAssertFalse(AppearancePreviewStateResolver.resolvedIsDark(theme: .system, systemIsDark: false))
        XCTAssertTrue(AppearancePreviewStateResolver.resolvedIsDark(theme: .system, systemIsDark: true))
    }

    /// Updating one appearance field preserves every other explicit settings snapshot.
    func testAppearanceSnapshotUpdatesOneFieldAtATime() {
        let snapshot = AppearancePreviewAppearanceSnapshot(
            style: .appIcons,
            size: .small,
            theme: .system,
            systemIsDark: false)
        let updated = snapshot.updating(
            style: .titles,
            size: .large,
            systemIsDark: true)
        XCTAssertEqual(
            updated,
            AppearancePreviewAppearanceSnapshot(
                style: .titles,
                size: .large,
                theme: .system,
                systemIsDark: true))
    }

    /// App Icons starts focused on the second demo item when it exists.
    func testAppIconsStartsOnMiddleItem() {
        XCTAssertEqual(
            AppearancePreviewStateResolver.initialFocusedIndex(style: .appIcons, itemCount: 3),
            1)
    }

    /// Titles starts focused on the first demo row.
    func testTitlesStartsOnFirstItem() {
        XCTAssertEqual(
            AppearancePreviewStateResolver.initialFocusedIndex(style: .titles, itemCount: 3),
            0)
    }

    /// An empty preview resolves focus to zero without indexing an item.
    func testEmptyPreviewUsesSafeFocus() {
        XCTAssertEqual(
            AppearancePreviewStateResolver.initialFocusedIndex(style: .appIcons, itemCount: 0),
            0)
    }

    /// Controls initial binding pauses every style preview.
    func testNoPlayingIndexPausesEveryPreview() {
        XCTAssertEqual(
            AppearancePreviewStateResolver.pausedStates(previewCount: 2, playingIndex: nil),
            [true, true])
    }

    /// Selecting a style runs only its matching preview.
    func testPlayingIndexRunsOnlySelectedPreview() {
        XCTAssertEqual(
            AppearancePreviewStateResolver.pausedStates(previewCount: 2, playingIndex: 1),
            [true, false])
    }

    /// An out-of-range selection cannot accidentally start a preview.
    func testInvalidPlayingIndexPausesEveryPreview() {
        XCTAssertEqual(
            AppearancePreviewStateResolver.pausedStates(previewCount: 2, playingIndex: 4),
            [true, true])
    }

    /// Right-to-left previews reverse status symbol order to match mirrored geometry.
    func testRightToLeftReversesStatusSymbolOrder() {
        XCTAssertEqual(
            AppearancePreviewStateResolver.orderedStatusSymbols(
                ["fullscreen", "space"],
                layoutDirection: .rightToLeft),
            ["space", "fullscreen"])
        XCTAssertEqual(
            AppearancePreviewStateResolver.orderedStatusSymbols(
                ["fullscreen", "space"],
                layoutDirection: .leftToRight),
            ["fullscreen", "space"])
    }
}
