import Foundation
import XCTest

final class FocusSetCandidateCounterTests: XCTestCase {

    // MARK: - A. Scope membership

    /// All Windows retains the Focus Sets safety policy while including assigned and unassigned applications.
    func testAllWindowsScopeAppliesPolicyWithoutMembershipRestriction() {
        let setID = UUID()
        let resolver = makeResolver([focusSet(setID, bundles: ["com.example.editor"])])
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor"),
            candidate(application: app(2, "com.example.browser"), id: "browser"),
            candidate(application: app(3, "com.example.hidden", isHidden: true), id: "hidden")
        ]

        XCTAssertEqual(
            count(candidates, scope: .allWindows, resolver: resolver),
            3)
        XCTAssertEqual(
            count(candidates, scope: .allWindows, resolver: resolver, visibility: visibility(hideHidden: true)),
            2)
    }

    /// Multiple scope previews share one policy snapshot while resolving membership independently.
    func testCountsResolveMultipleScopesFromOnePolicySnapshot() {
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
            visibility: visibility(hideHidden: true))

        XCTAssertEqual(counts[.allWindows], 2)
        XCTAssertEqual(counts[.set(id: firstSetID)], 1)
        XCTAssertEqual(counts[.set(id: secondSetID)], 1)
        XCTAssertEqual(counts[.unassigned], 0)
    }

    /// No scope leaves saved membership inactive while retaining the supplied Focus Sets policy.
    func testNoScopeAppliesPolicyWithoutMembershipRestriction() {
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

    /// Selected-set membership and the Focus Sets policy are conjunctive rather than overriding each other.
    func testSetScopeConjoinsMembershipWithPolicy() {
        let setID = UUID()
        let resolver = makeResolver([focusSet(setID, bundles: ["com.example.editor"])])
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "visible-member"),
            candidate(application: app(2, "com.example.editor", isHidden: true), id: "hidden-member"),
            candidate(application: app(3, "com.example.browser"), id: "visible-nonmember"),
        ]

        XCTAssertEqual(
            count(
                candidates,
                scope: .set(id: setID),
                resolver: resolver,
                visibility: visibility(hideHidden: true)),
            1)
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

    // MARK: - B. Focus Sets visibility policy

    /// Standard policy includes all app states, Spaces, and screens while safety exclusions still apply.
    func testStandardPolicyIncludesAllVisibilityStatesWhileKeepingSafetyExclusions() {
        XCTAssertTrue(FocusSetsPresentationPolicy.standard.windowlessAtEnd)
        let exception = ExceptionEntry(bundleIdentifier: "com.example.exception", hide: .always, ignore: .none)
        let candidates = [
            candidate(application: app(1, "com.example.pass"), id: "pass", spaceIds: [1]),
            candidate(application: app(1, "com.example.exception"), id: "exception", spaceIds: [1]),
            candidate(application: app(2, "com.example.other-app"), id: "other-app", spaceIds: [1]),
            candidate(application: app(1, "com.example.hidden", isHidden: true), id: "hidden", spaceIds: [1]),
            candidate(application: app(1, "com.example.windowless"), id: "windowless", isWindowlessApp: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.fullscreen"), id: "fullscreen", isFullscreen: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.minimized"), id: "minimized", isMinimized: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.other-space"), id: "other-space", spaceIds: [999]),
            candidate(application: app(1, "com.example.tab"), id: "tab", isTabbed: true, spaceIds: [1]),
            candidate(application: app(1, "com.example.phantom"), id: "phantom", isPhantom: true, spaceIds: [1])
        ]
        let visibility = FocusSetsVisibilitySnapshot(exceptions: [exception])

        XCTAssertEqual(count(candidates, visibility: visibility), 7)
    }

    /// Shared tab grouping controls whether secondary tab candidates remain visible.
    func testSharedTabGroupingControlsTabbedCandidates() {
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "main"),
            candidate(application: app(1, "com.example.editor"), id: "tab", isTabbed: true)
        ]

        XCTAssertEqual(count(candidates), 1)
        XCTAssertEqual(count(candidates, visibility: FocusSetsVisibilitySnapshot(separateTabs: true)), 2)
    }

    // MARK: - C. Grouping

    /// Main-window grouping counts one visible child candidate for each application PID.
    func testMainWindowGroupingCountsOneVisibleCandidatePerApplication() {
        let candidates = [
            candidate(application: app(1, "com.example.editor"), id: "editor-1"),
            candidate(application: app(1, "com.example.editor"), id: "editor-2"),
            candidate(application: app(2, "com.example.terminal"), id: "terminal")
        ]

        XCTAssertEqual(count(candidates, visibility: FocusSetsVisibilitySnapshot(onlyMainWindowPerApplication: true)), 2)
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
                       visibility: FocusSetsVisibilitySnapshot = FocusSetsVisibilitySnapshot()) -> Int {
        FocusSetCandidateCounter.count(candidates, scope: scope, resolver: resolver, visibility: visibility)
    }

    private func visibility(hideHidden: Bool = false) -> FocusSetsVisibilitySnapshot {
        let policy = FocusSetsPresentationPolicy(
            hideHidden: hideHidden,
            hideWindowless: false,
            windowlessAtEnd: true,
            hideFullscreen: false,
            hideMinimized: false,
            onlyVisibleSpaces: false,
            onlyNonVisibleSpaces: false,
            onlyPreferredScreen: false)
        return FocusSetsVisibilitySnapshot(policy: policy)
    }

    private func candidate(application: ApplicationState,
                           id: String,
                           isPhantom: Bool = false,
                           isWindowlessApp: Bool = false,
                           isFullscreen: Bool = false,
                           isMinimized: Bool = false,
                           isTabbed: Bool = false,
                           spaceIds: [UInt64] = []) -> FocusSetCandidate {
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
            application: application)
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
