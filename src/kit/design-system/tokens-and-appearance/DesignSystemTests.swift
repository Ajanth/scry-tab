import Cocoa
import XCTest

final class DesignSystemTests: XCTestCase {
    func testMaterialTintAlphaUsesLightAndDarkValues() {
        XCTAssertEqual(DesignSystem.materialTintAlpha(NSAppearance(named: .aqua)), 0.025, accuracy: 0.0001)
        if #available(macOS 10.14, *) {
            XCTAssertEqual(DesignSystem.materialTintAlpha(NSAppearance(named: .darkAqua)), 0.10, accuracy: 0.0001)
        }
    }

    func testSettingsPageIconDescriptorsFollowPageIdentity() {
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .appearance).symbolValue, "􀝥")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .controls).symbolValue, "􀆔")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .general).symbolValue, "􀣋")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .exceptions).symbolValue, "􀉻")
        XCTAssertEqual(SettingsPageIconDescriptor.descriptor(for: .about).symbolValue, "􀅴")
    }

    func testStandardGeometryTokensMatchMigrationPlan() {
        XCTAssertEqual(DesignSystem.Metrics.windowRadius, 12)
        XCTAssertEqual(DesignSystem.Metrics.sectionRadius, 12)
        XCTAssertEqual(DesignSystem.Metrics.joinedOuterRowRadius, 8)
        XCTAssertEqual(DesignSystem.Metrics.sidebarSelectionRadius, 12)
        XCTAssertEqual(DesignSystem.Metrics.sidebarIconRadius, 6)
        XCTAssertEqual(DesignSystem.Metrics.standardControlMinHeight, 32)
        XCTAssertEqual(DesignSystem.Metrics.settingsEditorSidebarHeight, 470)
    }

    func testControlGeometryTokensMatchMigrationPlan() {
        XCTAssertEqual(DesignSystem.Metrics.standardControlMinHeight, 32)
        XCTAssertEqual(DesignSystem.Metrics.controlRadius, 8)
        XCTAssertEqual(DesignSystem.Metrics.focusIndicatorBorderWidth, 3)
        XCTAssertEqual(DesignSystem.Metrics.controlTextInset, 10)
        XCTAssertEqual(DesignSystem.Metrics.buttonHorizontalPadding, 14)
        XCTAssertEqual(DesignSystem.Metrics.buttonVerticalPadding, 7)
        XCTAssertEqual(DesignSystem.Metrics.disclosureCaretWidth, 10)
        XCTAssertEqual(DesignSystem.Metrics.disclosureCaretHeight, 6)
        XCTAssertEqual(DesignSystem.Metrics.disclosureCaretStrokeWidth, 1.75)
        XCTAssertEqual(DesignSystem.Metrics.disclosureCaretTitleSpacing, 6)
    }

    func testFlatButtonUsesAppOwnedSurfaceAndDestructiveAccent() {
        let button = DesignSystemControlStyler.makeButton("Reset settings and restart…", destructive: true)
        XCTAssertTrue(button.drawsAppOwnedSurface)
        XCTAssertFalse(button.isBordered)
        XCTAssertEqual(button.focusRingType, .none)
        XCTAssertTrue(button.usesDestructiveAccent)
    }

    func testFlatButtonIntrinsicContentIncludesHorizontalPadding() {
        let title = "Customize more…"
        let button = DesignSystemControlStyler.makeButton(title)
        let font = button.font ?? NSFont.systemFont(ofSize: 13)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        XCTAssertGreaterThanOrEqual(button.intrinsicContentSize.width, ceil(titleWidth) + 2 * DesignSystem.Metrics.buttonHorizontalPadding)
        XCTAssertGreaterThanOrEqual(button.intrinsicContentSize.height, DesignSystem.Metrics.standardControlMinHeight)
    }

    func testDisclosureSectionTogglesItsContentAndTitle() {
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.widthAnchor.constraint(equalToConstant: 220).isActive = true
        content.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let section = DesignSystemDisclosureSection(collapsedTitle: "Show More Options", expandedTitle: "Show Fewer Options", content: content)

        XCTAssertFalse(section.isExpanded)
        XCTAssertFalse(section.isContentVisible)
        XCTAssertEqual(section.alignment, .centerX)
        XCTAssertEqual(section.fittingSize.width, 220, accuracy: 0.0001)
        XCTAssertEqual(section.caretDirection, .down)
        XCTAssertTrue(section.hasTrailingCaret)
        XCTAssertEqual(section.title, "Show More Options")
        XCTAssertEqual(section.caretImageSize.width, DesignSystem.Metrics.disclosureCaretTitleSpacing + DesignSystem.Metrics.disclosureCaretWidth)
        XCTAssertEqual(section.caretImageSize.height, DesignSystem.Metrics.disclosureCaretHeight)
        XCTAssertGreaterThanOrEqual(section.caretTrailingPadding, DesignSystem.Metrics.buttonHorizontalPadding)
        let collapsedButtonWidth = section.disclosureButtonWidth

        section.setExpanded(true, animated: false)

        XCTAssertTrue(section.isExpanded)
        XCTAssertTrue(section.isContentVisible)
        XCTAssertEqual(section.caretDirection, .up)
        XCTAssertEqual(section.title, "Show Fewer Options")
        XCTAssertEqual(section.disclosureButtonWidth, collapsedButtonWidth, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(section.caretTrailingPadding, DesignSystem.Metrics.buttonHorizontalPadding)

        section.setExpanded(false, animated: false)

        XCTAssertFalse(section.isExpanded)
        XCTAssertFalse(section.isContentVisible)
        XCTAssertEqual(section.title, "Show More Options")
    }

    func testPopupButtonUsesAppOwnedSurface() {
        let button = PopupButtonLikeSystemSettings()
        button.addItems(withTitles: ["One", "Two"])
        XCTAssertTrue(button.drawsAppOwnedSurface)
        XCTAssertFalse(button.isBordered)
        XCTAssertEqual(button.focusRingType, NSFocusRingType.none)
        XCTAssertTrue(button.wantsLayer)
        XCTAssertNotNil(button.layer)
    }

    func testTextFieldUsesFlatSurfaceAndHorizontalPadding() {
        let field = NSTextField()
        field.frame = NSRect(x: 0, y: 0, width: 200, height: 32)
        DesignSystemControlStyler.styleTextField(field)
        XCTAssertFalse(field.isBezeled)
        XCTAssertFalse(field.drawsBackground)
        XCTAssertEqual(field.layer?.cornerRadius, DesignSystem.Metrics.controlRadius)
        XCTAssertEqual(field.layer?.borderWidth, 1)
        XCTAssertGreaterThanOrEqual(field.cell?.drawingRect(forBounds: field.bounds).minX ?? 0, DesignSystem.Metrics.controlTextInset)
    }

    func testSearchFieldUsesFlatSurfaceWithoutStockBezel() {
        let field = NSSearchField()
        field.frame = NSRect(x: 0, y: 0, width: 200, height: 32)
        DesignSystemControlStyler.styleSearchField(field)
        XCTAssertFalse(field.isBezeled)
        XCTAssertFalse(field.drawsBackground)
        XCTAssertEqual(field.focusRingType, .none)
        XCTAssertEqual(field.layer?.cornerRadius, DesignSystem.Metrics.controlRadius)
        XCTAssertEqual(field.layer?.borderWidth, 1)
        if let cell = field.cell as? NSSearchFieldCell {
            XCTAssertGreaterThanOrEqual(cell.searchButtonRect(forBounds: field.bounds).minX, DesignSystem.Metrics.searchGlyphInset)
            XCTAssertGreaterThan(cell.searchTextRect(forBounds: field.bounds).minX, DesignSystem.Metrics.controlTextInset)
        } else {
            XCTFail("Expected styled search field to keep an NSSearchFieldCell")
        }
    }

    func testMainSearchFieldUsesSwitcherChrome() {
        let field = NSSearchField()
        DesignSystemControlStyler.styleMainSearchField(field)

        XCTAssertTrue(field.sendsSearchStringImmediately)
        XCTAssertTrue(field.sendsWholeSearchString)
        XCTAssertEqual(field.bezelStyle, .roundedBezel)
        XCTAssertTrue(field.usesSingleLineMode)
    }

    func testFlatSurfaceViewUsesSharedControlChrome() {
        let view = DesignSystemFlatSurfaceView()
        XCTAssertTrue(view.wantsLayer)
        XCTAssertEqual(view.layer?.cornerRadius, DesignSystem.Metrics.controlRadius)
        XCTAssertEqual(view.layer?.borderWidth, 1)
        XCTAssertNotNil(view.layer?.backgroundColor)
        XCTAssertNotNil(view.layer?.borderColor)
    }

    func testSegmentedControlUsesAppOwnedSurface() {
        let control = DesignSystemSegmentedControl(labels: ["One", "Two"], trackingMode: .selectOne, target: nil, action: nil)
        let appKitControl: NSSegmentedControl = control
        XCTAssertEqual(appKitControl.segmentCount, 2)
        XCTAssertTrue(control.drawsAppOwnedSurface)
    }

    func testSegmentedControlUsesCompositorSelectionIndicator() {
        let control = DesignSystemSegmentedControl(labels: ["One", "Two"], trackingMode: .selectOne, target: nil, action: nil)
        let indicator = try! XCTUnwrap(control.layer?.sublayers?.first)
        XCTAssertTrue(control.usesAnimatedSelectionIndicator)
        XCTAssertTrue(control.wantsLayer)
        XCTAssertNotNil(control.layer)
        XCTAssertEqual(indicator.borderWidth, DesignSystem.Metrics.focusIndicatorBorderWidth)
    }

    func testSegmentedControlImageContentPreservesAspectRatio() {
        let control = DesignSystemSegmentedControl(labels: [""], trackingMode: .momentary, target: nil, action: nil)
        let rect = control.fittedImageRect(CGSize(width: 9, height: 1),
                                           centeredIn: CGRect(x: 0, y: 0, width: 16, height: 16),
                                           maximumDimension: 16)
        XCTAssertEqual(rect.width, 16, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 16 / 9, accuracy: 0.0001)
        XCTAssertEqual(rect.midX, 8, accuracy: 0.0001)
        XCTAssertEqual(rect.midY, 8, accuracy: 0.0001)
    }

    func testSegmentedControlImageContentUsesSemanticTint() {
        let control = DesignSystemSegmentedControl(labels: [""], trackingMode: .momentary, target: nil, action: nil)
        XCTAssertEqual(control.imageTintColor(enabled: true), DesignSystem.color(.textPrimary, appearance: control.effectiveAppearance))
        XCTAssertEqual(control.imageTintColor(enabled: false), DesignSystem.color(.textDisabled, appearance: control.effectiveAppearance))
    }

    func testChipSelectUsesAppOwnedChoiceButtons() {
        let control = DesignSystemChipSelectControl(labels: ["Start", "Middle", "End"], selectedIndex: 1, chipWidth: 72)
        XCTAssertTrue(control.drawsAppOwnedSurface)
        XCTAssertEqual(control.chipCount, 3)
        XCTAssertEqual(control.chipTitle(at: 1), "Middle")
        XCTAssertEqual(control.selectedIndex, 1)
        XCTAssertTrue(control.isChipSelected(at: 1))
        XCTAssertFalse(control.isChipSelected(at: 0))
        XCTAssertGreaterThanOrEqual(control.intrinsicContentSize.height, DesignSystem.Metrics.standardControlMinHeight)
    }

    func testChipSelectUsesCompositorSelectionIndicator() {
        let control = DesignSystemChipSelectControl(labels: ["Start", "Middle", "End"])
        let indicator = try! XCTUnwrap(control.layer?.sublayers?.first)
        XCTAssertTrue(control.usesAnimatedSelectionIndicator)
        XCTAssertTrue(control.wantsLayer)
        XCTAssertNotNil(control.layer)
        XCTAssertEqual(indicator.borderWidth, DesignSystem.Metrics.focusIndicatorBorderWidth)
    }

    func testChipSelectClampsSelectionToAvailableChoices() {
        let control = DesignSystemChipSelectControl(labels: ["Start", "Middle", "End"], selectedIndex: 12)
        XCTAssertEqual(control.selectedIndex, 2)
        control.selectedIndex = -4
        XCTAssertEqual(control.selectedIndex, 0)
    }

    func testChipSelectKeepsStableEqualWidthsAcrossSelectionChanges() {
        let control = DesignSystemChipSelectControl(labels: ["Start", "Middle", "End"], selectedIndex: 0, chipWidth: 72, equalWidth: true)
        let initialWidth = control.intrinsicContentSize.width
        control.selectedIndex = 2
        XCTAssertEqual(control.intrinsicContentSize.width, initialWidth, accuracy: 0.0001)
        let stack = try! XCTUnwrap(control.subviews.first as? NSStackView)
        let buttons = stack.arrangedSubviews.compactMap { $0 as? NSButton }
        let widths = buttons.compactMap { button in
            button.constraints.first { $0.firstAttribute == .width && $0.relation == .equal }?.constant
        }
        XCTAssertEqual(widths.count, 3)
        XCTAssertEqual(widths[0], widths[1], accuracy: 0.0001)
        XCTAssertEqual(widths[1], widths[2], accuracy: 0.0001)
    }

    func testDarkModeSurfacesUseOpaqueMattePalette() {
        guard #available(macOS 10.14, *) else { return }
        let darkAppearance = NSAppearance(named: .darkAqua)
        let plateau = try! XCTUnwrap(DesignSystem.color(.surfacePlateau, appearance: darkAppearance).usingColorSpace(.extendedSRGB))
        let flat = try! XCTUnwrap(DesignSystem.color(.surfaceFlat, appearance: darkAppearance).usingColorSpace(.extendedSRGB))
        let selected = try! XCTUnwrap(DesignSystem.color(.surfaceSelected, appearance: darkAppearance).usingColorSpace(.extendedSRGB))
        XCTAssertEqual(plateau.alphaComponent, 1)
        XCTAssertEqual(flat.alphaComponent, 1)
        XCTAssertEqual(selected.alphaComponent, 1)
        XCTAssertGreaterThan(flat.redComponent, plateau.redComponent)
        XCTAssertGreaterThan(selected.redComponent, flat.redComponent)
        XCTAssertLessThan(DesignSystem.color(.borderSelected, appearance: darkAppearance).alphaComponent,
                          DesignSystem.color(.focusAccent, appearance: darkAppearance).alphaComponent)
    }

    func testWindowContentViewLayersMaterialBehindInsetContent() {
        let content = NSView()
        let wrapper = DesignSystemWindowContentView(content: content, topPadding: 10)
        XCTAssertTrue(wrapper.subviews.first is DesignSystemMaterialView)
        XCTAssertTrue(wrapper.subviews.last === content)
        XCTAssertTrue(wrapper.constraints.contains {
            guard let first = $0.firstItem as? NSView, let second = $0.secondItem as? NSView else { return false }
            return first === content && second === wrapper && $0.firstAttribute == .top && $0.secondAttribute == .top && $0.constant == 10
        })
    }
}
