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

    func testHighlightBackgroundUsesHorizontalInset() throws {
        let row = SidebarListRow()
        let background = try XCTUnwrap(descendantViews(row).first {
            $0.identifier?.rawValue == "sidebarRowBackground"
        })
        XCTAssertTrue(hasConstraint(row,
                                    first: background,
                                    firstAttribute: .leading,
                                    second: row,
                                    secondAttribute: .leading,
                                    constant: SidebarListRow.highlightHorizontalInset))
        XCTAssertTrue(hasConstraint(row,
                                    first: background,
                                    firstAttribute: .trailing,
                                    second: row,
                                    secondAttribute: .trailing,
                                    constant: -SidebarListRow.highlightHorizontalInset))
    }

    func testFixedSidebarHeightDoesNotFollowEditorHeight() {
        let sidebar = NSView()
        let editor = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        editor.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(equalToConstant: 200).isActive = true
        editor.widthAnchor.constraint(equalToConstant: SettingsWindow.contentWidth - 201).isActive = true
        _ = makeSidebarEditorContainer(sidebar: sidebar, editor: editor, fixedSidebarHeight: 470, chrome: .plain)
        XCTAssertTrue(sidebar.constraints.contains {
            $0.firstAnchor == sidebar.heightAnchor
                && $0.secondAnchor == nil
                && $0.relation == .equal
                && $0.constant == 470
        })
        XCTAssertFalse(sidebar.constraints.contains {
            $0.firstAnchor == sidebar.heightAnchor
                && $0.secondAnchor == editor.heightAnchor
        })
    }

    func testSpacedLayoutUsesSectionGapWithoutDivider() throws {
        let sidebar = NSView()
        let editor = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        editor.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(equalToConstant: 196).isActive = true
        editor.widthAnchor.constraint(equalToConstant: SettingsWindow.contentWidth - 196 - DesignSystem.Metrics.sectionGap).isActive = true
        let container = makeSidebarEditorContainer(sidebar: sidebar, editor: editor, chrome: .plain, layout: .spaced)
        let content = try XCTUnwrap(container.subviews.first as? NSStackView)
        XCTAssertEqual(content.arrangedSubviews.count, 2)
        XCTAssertTrue(content.arrangedSubviews[0] === sidebar)
        XCTAssertTrue(content.arrangedSubviews[1] === editor)
        XCTAssertEqual(content.spacing, DesignSystem.Metrics.sectionGap)
    }
}
