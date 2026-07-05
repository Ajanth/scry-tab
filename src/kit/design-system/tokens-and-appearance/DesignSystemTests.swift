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
        XCTAssertEqual(DesignSystem.Metrics.controlTextInset, 10)
        XCTAssertEqual(DesignSystem.Metrics.buttonHorizontalPadding, 14)
        XCTAssertEqual(DesignSystem.Metrics.buttonVerticalPadding, 7)
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

    func testPopupButtonUsesAppOwnedSurface() {
        let button = PopupButtonLikeSystemSettings()
        button.addItems(withTitles: ["One", "Two"])
        XCTAssertTrue(button.drawsAppOwnedSurface)
        XCTAssertFalse(button.isBordered)
        XCTAssertEqual(button.focusRingType, NSFocusRingType.none)
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

    func testSegmentedControlUsesAppOwnedSurface() {
        let control = DesignSystemSegmentedControl(labels: ["One", "Two"], trackingMode: .selectOne, target: nil, action: nil)
        let appKitControl: NSSegmentedControl = control
        XCTAssertEqual(appKitControl.segmentCount, 2)
        XCTAssertTrue(control.drawsAppOwnedSurface)
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
