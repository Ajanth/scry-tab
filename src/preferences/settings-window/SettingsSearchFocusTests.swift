import Cocoa
import XCTest

/// Pins `SettingsFocusRegistry` behaviour.
/// Mirrors `SettingsSearchFocusSpecs.md` 1:1.
final class SettingsSearchFocusTests: XCTestCase {
    private var reg: SettingsFocusRegistry { SettingsFocusRegistry.shared }

    override func setUp() {
        super.setUp()
        reg.clear()
    }

    override func tearDown() {
        reg.clear()
        super.tearDown()
    }

    // MARK: - testRegistryRetainsLiveViewAndReleasesOnTeardown

    /// A registered id resolves to the live view; after the view is released the same id
    /// resolves to nil.
    func testRegistryRetainsLiveViewAndReleasesOnTeardown() {
        var view: NSView? = NSView()
        reg.register("page-control", view!)
        XCTAssertIdentical(reg.view(for: "page-control"), view)
        view = nil
        XCTAssertNil(reg.view(for: "page-control"), "Weak ref must release when view is deallocated")
    }

    // MARK: - testUnregisterPrefixRemovesOnlyMatchingAnchors

    /// Unregistering a page prefix clears that page's anchors but leaves unrelated anchors intact.
    func testUnregisterPrefixRemovesOnlyMatchingAnchors() {
        let viewA = NSView()
        let viewB = NSView()
        reg.register("general-startAtLogin", viewA)
        reg.register("appearance-style", viewB)
        reg.unregisterPrefix("general-")
        XCTAssertNil(reg.view(for: "general-startAtLogin"), "general- prefix must be cleared")
        XCTAssertIdentical(reg.view(for: "appearance-style"), viewB, "appearance- prefix must be untouched")
    }

    // MARK: - testRowRegisterFocusAnchorStoresMetadataAndPublishesRow

    /// `registerFocusAnchor` stores the row metadata and publishes the row by descriptor id.
    func testRowRegisterFocusAnchorStoresMetadataAndPublishesRow() {
        let focalControl = NSButton()
        let row = SettingsRowView(title: "Test", content: [focalControl])
        row.registerFocusAnchor("general-test", focalControl: focalControl)
        XCTAssertEqual(row.anchorIdentifier, "general-test")
        XCTAssertIdentical(row.focalControl, focalControl)
        XCTAssertIdentical(reg.view(for: "general-test"), row, "Row must be retrievable by its anchor id")
    }

    // MARK: - testPhase3MigratedDescriptorAnchorsUseRegisteredIds

    /// Controls and Exceptions search descriptors share anchor ids with their migrated pages.
    func testPhase3MigratedDescriptorAnchorsUseRegisteredIds() {
        let controlsGesture = SidebarListRow()
        let controlsActive = SidebarListRow()
        let controlsNavigationPointer = SidebarListRow()
        let shortcut = SidebarListRow()
        let exceptions = SidebarListContainer()
        let exception = SidebarListRow()
        reg.register(SettingsFocusAnchorID.controlsGesture, controlsGesture)
        reg.register(SettingsFocusAnchorID.controlsActive, controlsActive)
        reg.register(SettingsFocusAnchorID.controlsNavigationPointer, controlsNavigationPointer)
        reg.register(SettingsFocusAnchorID.shortcut("shortcut-a"), shortcut)
        reg.register(SettingsFocusAnchorID.exceptions, exceptions)
        reg.register(SettingsFocusAnchorID.exception("com.example.App"), exception)
        XCTAssertIdentical(reg.view(for: "controls-gesture"), controlsGesture)
        XCTAssertIdentical(reg.view(for: "controls-active"), controlsActive)
        XCTAssertIdentical(reg.view(for: "controls-navigation-pointer"), controlsNavigationPointer)
        XCTAssertIdentical(reg.view(for: "shortcut-shortcut-a"), shortcut)
        XCTAssertIdentical(reg.view(for: "exceptions"), exceptions)
        XCTAssertIdentical(reg.view(for: "exception-com.example.App"), exception)
    }

    // MARK: - testRegisterReplacesPriorAnchorViewForSameId

    /// Re-registering an id swaps the resolved view to the new one so a rebuilt page never
    /// publishes stale anchors.
    func testRegisterReplacesPriorAnchorViewForSameId() {
        let first = NSView()
        let second = NSView()
        reg.register("general-startAtLogin", first)
        reg.register("general-startAtLogin", second)
        XCTAssertIdentical(reg.view(for: "general-startAtLogin"), second, "Second registration must replace the first")
    }

    // MARK: - testClearRemovesEveryAnchor

    /// `clear` empties the registry entirely.
    func testClearRemovesEveryAnchor() {
        let viewA = NSView()
        let viewB = NSView()
        reg.register("general-startAtLogin", viewA)
        reg.register("appearance-style", viewB)
        reg.clear()
        XCTAssertNil(reg.view(for: "general-startAtLogin"))
        XCTAssertNil(reg.view(for: "appearance-style"))
    }
}
