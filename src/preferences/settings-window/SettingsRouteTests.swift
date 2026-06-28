import XCTest

final class SettingsRouteTests: XCTestCase {
    func testShellGroupsProductPagesUnderScryTabAndAboutUnderApplication() {
        let groups = SettingsTopLevelPage.groupedForShell()
        XCTAssertEqual(groups.map(\.group), [.scryTab, .application])
        XCTAssertEqual(groups[0].pages, [.appearance, .controls, .general, .exceptions])
        XCTAssertEqual(groups[1].pages, [.about])
    }

    func testShellMetadataDefinesPageIconsAndBaseColors() {
        XCTAssertEqual(SettingsTopLevelPage.appearance.shellMetadata.icon, .paintpalette)
        XCTAssertEqual(SettingsTopLevelPage.controls.shellMetadata.baseColor, .indigo)
        XCTAssertEqual(SettingsTopLevelPage.general.shellMetadata.baseColor, .green)
        XCTAssertEqual(SettingsTopLevelPage.exceptions.shellMetadata.baseColor, .orange)
        XCTAssertEqual(SettingsTopLevelPage.about.shellMetadata.sidebarGroup, .application)
        XCTAssertEqual(SettingsTopLevelPage.about.shellMetadata.baseColor, .neutralGray)
    }

    func testApplicationInterfaceAppearanceResolvesIndependentlyFromSwitcherTheme() {
        XCTAssertEqual(ApplicationInterfaceAppearancePreference.system.resolvedAppearance(supportsDarkMode: true), .system)
        XCTAssertEqual(ApplicationInterfaceAppearancePreference.light.resolvedAppearance(supportsDarkMode: true), .aqua)
        XCTAssertEqual(ApplicationInterfaceAppearancePreference.dark.resolvedAppearance(supportsDarkMode: true), .darkAqua)
    }

    func testApplicationInterfaceAppearanceFallsBackToLightWithoutDarkMode() {
        XCTAssertEqual(ApplicationInterfaceAppearancePreference.system.resolvedAppearance(supportsDarkMode: false), .aqua)
        XCTAssertEqual(ApplicationInterfaceAppearancePreference.dark.resolvedAppearance(supportsDarkMode: false), .aqua)
    }

    func testInitialSearchRouteNormalizesToAppearance() {
        let navigation = SettingsNavigationController(initialRoute: .search(query: "theme"))
        XCTAssertEqual(navigation.selectedRoute, .appearance)
        XCTAssertEqual(navigation.previousNonSearchRoute, .appearance)
    }

    func testNavigateUpdatesPreviousNonSearchRoute() {
        let navigation = SettingsNavigationController()
        navigation.navigate(to: .controls(.gesture))
        XCTAssertEqual(navigation.selectedRoute, .controls(.gesture))
        XCTAssertEqual(navigation.previousNonSearchRoute, .controls(.gesture))
    }

    func testSearchPreservesPreviousNonSearchRoute() {
        let navigation = SettingsNavigationController(initialRoute: .general)
        navigation.updateSearch(query: "update")
        XCTAssertEqual(navigation.selectedRoute, .search(query: "update"))
        XCTAssertEqual(navigation.previousNonSearchRoute, .general)
    }

    func testEmptySearchRestoresPreviousNonSearchRoute() {
        let navigation = SettingsNavigationController(initialRoute: .exceptions(nil))
        navigation.updateSearch(query: "bundle")
        navigation.updateSearch(query: "   ")
        XCTAssertEqual(navigation.selectedRoute, .exceptions(nil))
        XCTAssertEqual(navigation.previousNonSearchRoute, .exceptions(nil))
    }

    func testDeletedShortcutRouteFallsBackToControlsRoot() {
        let route = SettingsRoute.controls(.shortcut(id: "deleted", pane: .appearance))
        XCTAssertEqual(route.normalizedDeletedShortcut { $0 == "existing" }, .controls(nil))
    }

    func testExistingShortcutRouteKeepsPane() {
        let route = SettingsRoute.controls(.shortcut(id: "existing", pane: .appearance))
        XCTAssertEqual(route.normalizedDeletedShortcut { $0 == "existing" }, .controls(.shortcut(id: "existing", pane: .appearance)))
    }

    func testDescriptorSearchableStringsIncludeDynamicValues() {
        var dynamic = ["Shortcut 1", "⌥ + ⇥"]
        let descriptor = SettingsSearchDescriptor(id: "shortcut",
                                                  route: .controls(.shortcut(id: "id", pane: nil)),
                                                  sectionID: "controls",
                                                  title: "Shortcut",
                                                  subtitle: "Trigger",
                                                  keywords: ["Hold"],
                                                  valueProvider: { dynamic })
        XCTAssertEqual(descriptor.searchableStrings, ["Shortcut", "Trigger", "Hold", "Shortcut 1", "⌥ + ⇥"])
        dynamic = ["Shortcut 2"]
        XCTAssertEqual(descriptor.searchableStrings, ["Shortcut", "Trigger", "Hold", "Shortcut 2"])
    }

    func testDescriptorMatcherReturnsSortedMatches() {
        let direct = SettingsSearchDescriptor(id: "theme",
                                              route: .appearance,
                                              sectionID: "appearance",
                                              title: "Theme")
        let fuzzy = SettingsSearchDescriptor(id: "appearance",
                                             route: .appearance,
                                             sectionID: "appearance",
                                             title: "Appearance",
                                             keywords: ["Theme"])
        let miss = SettingsSearchDescriptor(id: "updates",
                                            route: .general,
                                            sectionID: "general",
                                            title: "Updates")
        let matches = SettingsSearchDescriptorMatcher.matches(query: "theme", descriptors: [miss, fuzzy, direct])
        XCTAssertEqual(matches.map { $0.descriptor.id }, ["theme", "appearance"])
    }

    func testDescriptorMatcherGroupsMatchesByPageOrder() {
        let appearance = SettingsSearchDescriptor(id: "appearance",
                                                  route: .appearance,
                                                  sectionID: "appearance",
                                                  title: "Appearance",
                                                  keywords: ["Theme"])
        let controls = SettingsSearchDescriptor(id: "controls",
                                                route: .controls(.gesture),
                                                sectionID: "controls",
                                                title: "Controls",
                                                keywords: ["Theme"])
        let general = SettingsSearchDescriptor(id: "general",
                                               route: .general,
                                               sectionID: "general",
                                               title: "General",
                                               keywords: ["Theme"])
        let groups = SettingsSearchDescriptorMatcher.groupedMatches(query: "theme",
                                                                    descriptors: [appearance, general, controls],
                                                                    pageOrder: [.controls, .appearance, .general])
        XCTAssertEqual(groups.map(\.page), [.controls, .appearance, .general])
        XCTAssertEqual(groups.map { $0.matches.map { $0.descriptor.id } }, [["controls"], ["appearance"], ["general"]])
    }
}
