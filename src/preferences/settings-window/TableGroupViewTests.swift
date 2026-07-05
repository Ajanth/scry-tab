import Cocoa
import XCTest

final class TableGroupViewTests: XCTestCase {
    func testSectionContainerUsesSectionRadiusWhileRowsKeepJoinedRowRadius() {
        let table = TableGroupView(width: 320)
        let rowInfo = table.addRow(leftText: "Language", rightViews: [NSView()])
        XCTAssertEqual(table.tableStackViews.first?.layer?.cornerRadius, DesignSystem.Metrics.sectionRadius)
        XCTAssertEqual(rowInfo.view.layer?.cornerRadius, DesignSystem.Metrics.joinedOuterRowRadius)
    }

    func testTitledGroupsUseSecondaryHeaderStyleAndInset() {
        let table = TableGroupView(title: "Multiple screens", subTitle: "Choose a destination", width: 320)
        XCTAssertEqual(table.titleLabel.textColor, .secondaryLabelColor)
        XCTAssertEqual(table.subTitleLabel.textColor, .secondaryLabelColor)
        XCTAssertTrue(hasConstraint(table.titleStackView, first: table.titleLabel, firstAttribute: .leading, second: table.titleStackView, secondAttribute: .leading, constant: TableGroupView.sectionHeaderInset))
        XCTAssertTrue(hasConstraint(table.titleStackView, first: table.subTitleLabel, firstAttribute: .leading, second: table.titleStackView, secondAttribute: .leading, constant: TableGroupView.sectionHeaderInset))
    }

    func testRowsUseSeparateHorizontalAndVerticalInsets() throws {
        let table = TableGroupView(width: 320)
        let rowInfo = table.addRow(leftText: "Language", rightViews: [NSView()])
        let rowView = try XCTUnwrap(rowInfo.view as? NSStackView)
        let mainRow = try XCTUnwrap(rowView.arrangedSubviews.first as? NSStackView)
        XCTAssertTrue(hasConstraint(rowView, first: mainRow, firstAttribute: .top, second: rowView, secondAttribute: .top, constant: TableGroupView.rowVerticalPadding))
        XCTAssertTrue(hasConstraint(rowView, first: mainRow, firstAttribute: .leading, second: rowView, secondAttribute: .leading, constant: TableGroupView.rowHorizontalPadding))
        XCTAssertTrue(hasConstraint(rowView, first: mainRow, firstAttribute: .trailing, second: rowView, secondAttribute: .trailing, constant: -TableGroupView.rowHorizontalPadding))
        XCTAssertTrue(hasConstraint(rowView, first: mainRow, firstAttribute: .bottom, second: rowView, secondAttribute: .bottom, constant: -TableGroupView.rowVerticalPadding))
    }

    func testRowsUseFlexibleMainRowHeightInsteadOfFrozenFittingHeight() throws {
        let table = TableGroupView(width: 320)
        let rowInfo = table.addRow(leftText: "Language", rightViews: [NSView()])
        let rowView = try XCTUnwrap(rowInfo.view as? NSStackView)
        let mainRow = try XCTUnwrap(rowView.arrangedSubviews.first as? NSStackView)
        XCTAssertTrue(hasStandaloneConstraint(rowView, attribute: .height, relation: .greaterThanOrEqual, constant: TableGroupView.minimumRowHeight))
        XCTAssertTrue(hasStandaloneConstraint(mainRow, attribute: .height, relation: .greaterThanOrEqual, constant: DesignSystem.Metrics.standardControlMinHeight))
        XCTAssertFalse(hasStandaloneConstraint(mainRow, attribute: .height, relation: .equal))
    }

    func testSecondaryOnlyRowsSkipPlaceholderMainRow() throws {
        let table = TableGroupView(width: 320)
        let secondary = NSView()
        let rowInfo = table.addRow(secondaryViews: [secondary], secondaryViewsAlignment: .centerX)
        let rowView = try XCTUnwrap(rowInfo.view as? NSStackView)
        XCTAssertTrue(rowView.arrangedSubviews.isEmpty)
        XCTAssertEqual(rowView.subviews.filter { $0 is NSStackView }.count, 1)
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

    private func hasStandaloneConstraint(_ view: NSView,
                                         attribute: NSLayoutConstraint.Attribute,
                                         relation: NSLayoutConstraint.Relation,
                                         constant: CGFloat) -> Bool {
        view.constraints.contains {
            guard let firstItem = $0.firstItem as? NSView else { return false }
            return firstItem === view
                && $0.secondItem == nil
                && $0.firstAttribute == attribute
                && $0.relation == relation
                && $0.constant == constant
        }
    }

    private func hasStandaloneConstraint(_ view: NSView,
                                         attribute: NSLayoutConstraint.Attribute,
                                         relation: NSLayoutConstraint.Relation) -> Bool {
        view.constraints.contains {
            guard let firstItem = $0.firstItem as? NSView else { return false }
            return firstItem === view
                && $0.secondItem == nil
                && $0.firstAttribute == attribute
                && $0.relation == relation
        }
    }
}
