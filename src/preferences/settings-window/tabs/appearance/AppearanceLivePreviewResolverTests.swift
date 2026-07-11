import XCTest

final class AppearanceLivePreviewResolverTests: XCTestCase {

    /// The preview holds each focused item for exactly one second.
    func testAdvancesOncePerSecond() {
        XCTAssertEqual(AppearanceLivePreviewResolver.advanceInterval, 1)
    }
}
