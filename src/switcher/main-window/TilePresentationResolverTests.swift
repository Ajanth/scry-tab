import XCTest

final class TilePresentationResolverTests: XCTestCase {
    /// A non-window title presentation overrides an app-icons profile without changing the profile.
    func testForcedTitlePresentationOverridesAppIconsProfile() {
        XCTAssertFalse(TilePresentationResolver.usesAppIconLayout(
            profileUsesAppIcons: true,
            presentationUsesAppIcons: false))
        XCTAssertTrue(TilePresentationResolver.usesAppIconLayout(
            profileUsesAppIcons: true,
            presentationUsesAppIcons: nil))
    }

    /// Title presentation highlights cover the complete title row instead of app-icon geometry.
    func testTitleHighlightCoversCompleteCell() {
        let frame = TilePresentationResolver.highlightFrame(
            usesAppIconLayout: false,
            frameSize: CGSize(width: 420, height: 38),
            iconHeight: 110,
            edgeInsets: 6,
            scale: 1)

        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 420, height: 38))
    }

    /// Forced title presentation keeps the title icon size even when app-icons minimum width is large.
    func testTitleIconIgnoresAppIconMinimumTileWidth() {
        let size = TilePresentationResolver.iconSize(
            usesAppIconLayout: false,
            baseIconSize: 24,
            minimumTileWidth: 160,
            edgeInsets: 7)

        XCTAssertEqual(size, CGSize(width: 24, height: 24))
    }

    /// Ordinary app-icons presentation preserves the established rounded minimum-tile geometry.
    func testAppIconGeometryPreservesRoundedMinimumSizing() {
        let size = TilePresentationResolver.iconSize(
            usesAppIconLayout: true,
            baseIconSize: 64,
            minimumTileWidth: 101.6,
            edgeInsets: 7)

        XCTAssertEqual(size, CGSize(width: 88, height: 88))
    }
}
