import Foundation
import XCTest

final class FocusSetCandidateCounterTests: XCTestCase {

    // MARK: - A. Scope membership

    /// All Windows retains normal filtering while including assigned and unassigned applications.
    func testAllWindowsScopeAppliesProfileFiltersWithoutMembershipRestriction() {
        let setID = UUID()
        let resolver = makeResolver([focusSet(setID, bundles: ["com.example.editor"])])
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor"),
            candidate(application: app(2, "com.example.browser"), id: "browser"),
            candidate(application: app(3, "com.example.hidden", isHidden: true), id: "hidden")
        ]

        XCTAssertEqual(
            count(candidates, scope: .allWindows, resolver: resolver, filters: FocusSetCandidateFilters(hideHidden: true)),
            2)
    }

    /// Multiple scope previews share one normal-profile pass while resolving membership independently.
    func testCountsResolveMultipleScopesFromOneProfileSnapshot() {
        let firstSetID = UUID()
        let secondSetID = UUID()
        let resolver = makeResolver([
            focusSet(firstSetID, bundles: ["com.example.editor"]),
            focusSet(secondSetID, bundles: ["com.example.terminal"]),
        ])
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor"),
            candidate(application: app(2, "com.example.terminal"), id: "terminal"),
            candidate(application: app(3, "com.example.hidden", isHidden: true), id: "hidden"),
        ]
        let counts = FocusSetCandidateCounter.counts(
            candidates,
            scopes: [.allWindows, .set(id: firstSetID), .set(id: secondSetID), .unassigned],
            resolver: resolver,
            filters: FocusSetCandidateFilters(hideHidden: true))

        XCTAssertEqual(counts[.allWindows], 2)
        XCTAssertEqual(counts[.set(id: firstSetID)], 1)
        XCTAssertEqual(counts[.set(id: secondSetID)], 1)
        XCTAssertEqual(counts[.unassigned], 0)
    }

    /// No scope leaves saved membership inactive while retaining the supplied profile filters.
    func testNoScopeAppliesProfileFiltersWithoutMembershipRestriction() {
        let setID = UUID()
        let resolver = makeResolver([focusSet(setID, bundles: ["com.example.editor"])])
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor"),
            candidate(application: app(2, "com.example.browser"), id: "browser")
        ]

        XCTAssertEqual(count(candidates, resolver: resolver), 2)
    }

    /// A selected Focus Set excludes an otherwise visible application outside its membership.
    func testSetScopeCountsOnlyIncludedApplications() {
        let setID = UUID()
        let resolver = makeResolver([focusSet(setID, bundles: ["com.example.editor"])])
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor"),
            candidate(application: app(2, "com.example.terminal"), id: "terminal")
        ]

        XCTAssertEqual(count(candidates, scope: .set(id: setID), resolver: resolver), 1)
    }

    /// Unassigned excludes the union of every saved Focus Set's application membership.
    func testUnassignedScopeExcludesMembershipInEverySet() {
        let resolver = makeResolver([
            focusSet(UUID(), bundles: ["com.example.editor"]),
            focusSet(UUID(), bundles: ["com.example.terminal"])
        ])
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor"),
            candidate(application: app(2, "com.example.terminal"), id: "terminal"),
            candidate(application: app(3, "com.example.browser"), id: "browser")
        ]

        XCTAssertEqual(count(candidates, scope: .unassigned, resolver: resolver), 1)
    }

    // MARK: - B. Profile filters

    /// Every normal filter fact is applied before the candidate contributes to the count.
    func testNormalFilterFactsAreAppliedBeforeCounting() {
        let exception = ExceptionEntry(bundleIdentifier: "com.example.exception", hide: .always, ignore: .none)
        let candidates = [
            candidate(application: app(1, "com.example.pass"), id: "pass", spaceIds: [1]),
            candidate(application: app(1, "com.example.exception"), id: "exception", spaceIds: [1]),
            candidate(application: app(2, "com.example.non-frontmost"), id: "non-frontmost", spaceIds: [1]),
            candidate(application: app(1, "com.example.hidden", isHidden: true), id: "hidden", spaceIds: [1]),
            candidate(application: app(1, "com.example.windowless"), id: "windowless", isWindowlessApp: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.fullscreen"), id: "fullscreen", isFullscreen: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.minimized"), id: "minimized", isMinimized: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.other-space"), id: "other-space", spaceIds: [2]),
            candidate(application: app(1, "com.example.other-screen"), id: "other-screen", spaceIds: [1], isOnPreferredScreen: false),
            candidate(application: app(1, "com.example.tab"), id: "tab", isTabbed: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.phantom"), id: "phantom", isPhantom: true, spaceIds: [1])
        ]
        let filters = FocusSetCandidateFilters(
            onlyFrontmostApp: true,
            hideHidden: true,
            hideWindowless: true,
            hideFullscreen: true,
            hideMinimized: true,
            onlyVisibleSpaces: true,
            onlyPreferredScreen: true,
            frontmostPid: 1,
            visibleSpaceIds: [1],
            exceptions: [exception])

        XCTAssertEqual(count(candidates, filters: filters), 1)
    }

    /// Non-active and non-visible-space filters use the supplied frontmost and Space facts.
    func testExcludeFrontmostAndNonVisibleSpaceFiltersAreApplied() {
        let candidates = [
            candidate(application: app(1, "com.example.frontmost"), id: "frontmost", spaceIds: [2]),
            candidate(application: app(2, "com.example.visible-space"), id: "visible-space", spaceIds: [1]),
            candidate(application: app(2, "com.example.other-space"), id: "other-space", spaceIds: [2])
        ]
        let filters = FocusSetCandidateFilters(
            excludeFrontmostApp: true,
            onlyNonVisibleSpaces: true,
            frontmostPid: 1,
            visibleSpaceIds: [1])

        XCTAssertEqual(count(candidates, filters: filters), 1)
    }

    /// The precomputed preferred-screen fact excludes an off-screen candidate when requested.
    func testPreferredScreenFactFiltersCandidates() {
        let candidates = [
            candidate(application: app(1, "com.example.on-screen"), id: "on-screen", isOnPreferredScreen: true),
            candidate(application: app(2, "com.example.off-screen"), id: "off-screen", isOnPreferredScreen: false)
        ]

        XCTAssertEqual(count(candidates, filters: FocusSetCandidateFilters(onlyPreferredScreen: true)), 1)
    }

    /// A windowless candidate follows the profile's windowless-app setting.
    func testWindowlessCandidatesObeyProfileFilter() {
        let candidates = [
            candidate(application: app(1, "com.example.windowless"), id: "windowless", isWindowlessApp: true)
        ]

        XCTAssertEqual(count(candidates), 1)
        XCTAssertEqual(count(candidates, filters: FocusSetCandidateFilters(hideWindowless: true)), 0)
    }

    // MARK: - C. Grouping

    /// Main-window grouping counts one visible child candidate for each application PID.
    func testMainWindowGroupingCountsOneVisibleCandidatePerApplication() {
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor-1"),
            candidate(application: app(1, "com.example.editor"), id: "editor-2"),
            candidate(application: app(2, "com.example.terminal"), id: "terminal")
        ]

        XCTAssertEqual(count(candidates, filters: FocusSetCandidateFilters(onlyMainWindowPerApplication: true)), 2)
    }

    /// All-windows grouping retains each visible child candidate from the same application.
    func testAllWindowsGroupingCountsEachVisibleCandidate() {
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor-1"),
            candidate(application: app(1, "com.example.editor"), id: "editor-2"),
            candidate(application: app(2, "com.example.terminal"), id: "terminal")
        ]

        XCTAssertEqual(count(candidates), 3)
    }

    // MARK: - D. Membership edge cases

    /// A shared application counts in either selected overlapping set and never as unassigned.
    func testOverlappingSetsCountSharedApplicationInEachScope() {
        let firstSetID = UUID()
        let secondSetID = UUID()
        let resolver = makeResolver([
            focusSet(firstSetID, bundles: ["com.example.editor"]),
            focusSet(secondSetID, bundles: ["com.example.editor"])
        ])
        let candidates = [candidate(application: app(1, "com.example.editor"), id: "editor")]

        XCTAssertEqual(count(candidates, scope: .set(id: firstSetID), resolver: resolver), 1)
        XCTAssertEqual(count(candidates, scope: .set(id: secondSetID), resolver: resolver), 1)
        XCTAssertEqual(count(candidates, scope: .unassigned, resolver: resolver), 0)
    }

    /// An empty selected set has no candidates while its otherwise visible app remains unassigned.
    func testEmptySetHasNoSelectedCandidates() {
        let setID = UUID()
        let resolver = makeResolver([focusSet(setID, bundles: [])])
        let candidates = [candidate(application: app(1, "com.example.editor"), id: "editor")]

        XCTAssertEqual(count(candidates, scope: .set(id: setID), resolver: resolver), 0)
        XCTAssertEqual(count(candidates, scope: .unassigned, resolver: resolver), 1)
    }

    private func count(_ candidates: [FocusSetCandidate],
                       scope: FocusSetScope = .none,
                       resolver: FocusSetResolver = FocusSetResolver(configuration: FocusSetsConfiguration()),
                       filters: FocusSetCandidateFilters = FocusSetCandidateFilters()) -> Int {
        FocusSetCandidateCounter.count(candidates, scope: scope, resolver: resolver, filters: filters)
    }

    private func candidate(application: ApplicationState,
                           id: String,
                           isPhantom: Bool = false,
                           isWindowlessApp: Bool = false,
                           isFullscreen: Bool = false,
                           isMinimized: Bool = false,
                           isTabbed: Bool = false,
                           spaceIds: [UInt64] = [],
                           isOnPreferredScreen: Bool = true) -> FocusSetCandidate {
        let window = WindowState(
            id: id,
            isPhantom: isPhantom,
            isWindowlessApp: isWindowlessApp,
            isFullscreen: isFullscreen,
            isMinimized: isMinimized,
            isTabbed: isTabbed,
            isOnAllSpaces: false,
            spaceIds: spaceIds,
            spaceIndexes: [],
            lastFocusOrder: 0,
            creationOrder: 0,
            title: "Title")
        return FocusSetCandidate(
            window: window,
            application: application,
            isOnPreferredScreen: isOnPreferredScreen)
    }

    private func app(_ pid: pid_t, _ bundleIdentifier: String, isHidden: Bool = false) -> ApplicationState {
        ApplicationState(pid: pid, bundleIdentifier: bundleIdentifier, localizedName: nil, isHidden: isHidden)
    }

    private func makeResolver(_ sets: [FocusSet]) -> FocusSetResolver {
        FocusSetResolver(configuration: FocusSetsConfiguration(sets: sets))
    }

    private func focusSet(_ id: UUID, bundles: [String]) -> FocusSet {
        FocusSet(
            id: id,
            name: "Example",
            rules: bundles.map {
                FocusSetRule(applicationBundleIdentifier: $0, cachedApplicationName: "Example App")
            })
    }
}
