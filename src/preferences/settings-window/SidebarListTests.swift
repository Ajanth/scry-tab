import XCTest
import Cocoa

/// Coverage for `SidebarListRow`'s recycled row content updates.
final class SidebarListTests: XCTestCase {

    private func descendantViews(_ view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap { descendantViews($0) }
    }

    func testRepeatedContentUpdatesDoNotAccumulateViews() {
        let row = SidebarListRow()
        row.setContent("Shortcut 2", "")
        let baselineViewCount = descendantViews(row).count
        row.setContent("Shortcut 3", "Option + Tab")
        row.setContent("Shortcut 4", "Option + `")
        XCTAssertEqual(descendantViews(row).count, baselineViewCount)
    }
}
