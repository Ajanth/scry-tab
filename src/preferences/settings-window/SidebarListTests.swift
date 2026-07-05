import XCTest
import Cocoa

/// Coverage for `SidebarListRow`'s recycled row content updates.
final class SidebarListTests: XCTestCase {

    private func descendantViews(_ view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap { descendantViews($0) }
    }

    private func hasConstraint(_ view: NSView,
                               first: NSView,
                               firstAttribute: NSLayoutConstraint.Attribute,
                               second: NSView,
                               secondAttribute: NSLayoutConstraint.Attribute,
                               constant: CGFloat) -> Bool {
        view.constraints.contains {
            guard let firstItem = $0.firstItem as? NSView, let secondItem = $0.secondItem as? NSView else { return false }
            return firstItem === first
                && secondItem === second
                && $0.firstAttribute == firstAttribute
                && $0.secondAttribute == secondAttribute
                && $0.constant == constant
        }
    }

    func testRepeatedContentUpdatesDoNotAccumulateViews() {
        let row = SidebarListRow()
        row.setContent("Shortcut 2", "")
        let baselineViewCount = descendantViews(row).count
        row.setContent("Shortcut 3", "Option + Tab")
        row.setContent("Shortcut 4", "Option + `")
        XCTAssertEqual(descendantViews(row).count, baselineViewCount)
    }

    func testHighlightBackgroundUsesVerticalInset() throws {
        let row = SidebarListRow()
        let background = try XCTUnwrap(descendantViews(row).first {
            $0.identifier?.rawValue == "sidebarRowBackground"
        })
        XCTAssertTrue(hasConstraint(row,
                                    first: background,
                                    firstAttribute: .top,
                                    second: row,
                                    secondAttribute: .top,
                                    constant: SidebarListRow.highlightVerticalInset))
        XCTAssertTrue(hasConstraint(row,
                                    first: background,
                                    firstAttribute: .bottom,
                                    second: row,
                                    secondAttribute: .bottom,
                                    constant: -SidebarListRow.highlightVerticalInset))
    }
}
