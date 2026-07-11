import Foundation

/// A hostless window candidate whose preferred-screen fact was resolved before counting.
struct FocusSetCandidate {
    let window: WindowState
    let application: ApplicationState
    let isOnPreferredScreen: Bool

    init(window: WindowState, application: ApplicationState, isOnPreferredScreen: Bool) {
        self.window = window
        self.application = application
        self.isOnPreferredScreen = isOnPreferredScreen
    }
}

/// Immutable profile and runtime facts required by `WindowFilterResolver`.
struct FocusSetCandidateFilters {
    let onlyFrontmostApp: Bool
    let excludeFrontmostApp: Bool
    let hideHidden: Bool
    let hideWindowless: Bool
    let hideFullscreen: Bool
    let hideMinimized: Bool
    let onlyVisibleSpaces: Bool
    let onlyNonVisibleSpaces: Bool
    let onlyPreferredScreen: Bool
    let separateTabs: Bool
    let onlyMainWindowPerApplication: Bool
    let frontmostPid: pid_t?
    let visibleSpaceIds: [UInt64]
    let exceptions: [ExceptionEntry]

    init(onlyFrontmostApp: Bool = false,
         excludeFrontmostApp: Bool = false,
         hideHidden: Bool = false,
         hideWindowless: Bool = false,
         hideFullscreen: Bool = false,
         hideMinimized: Bool = false,
         onlyVisibleSpaces: Bool = false,
         onlyNonVisibleSpaces: Bool = false,
         onlyPreferredScreen: Bool = false,
         separateTabs: Bool = false,
         onlyMainWindowPerApplication: Bool = false,
         frontmostPid: pid_t? = nil,
         visibleSpaceIds: [UInt64] = [],
         exceptions: [ExceptionEntry] = []) {
        self.onlyFrontmostApp = onlyFrontmostApp
        self.excludeFrontmostApp = excludeFrontmostApp
        self.hideHidden = hideHidden
        self.hideWindowless = hideWindowless
        self.hideFullscreen = hideFullscreen
        self.hideMinimized = hideMinimized
        self.onlyVisibleSpaces = onlyVisibleSpaces
        self.onlyNonVisibleSpaces = onlyNonVisibleSpaces
        self.onlyPreferredScreen = onlyPreferredScreen
        self.separateTabs = separateTabs
        self.onlyMainWindowPerApplication = onlyMainWindowPerApplication
        self.frontmostPid = frontmostPid
        self.visibleSpaceIds = visibleSpaceIds
        self.exceptions = exceptions
    }
}

/// Counts child-grid candidates without touching live `Window` or `Windows` state.
enum FocusSetCandidateCounter {
    static func count(_ candidates: [FocusSetCandidate],
                      scope: FocusSetScope,
                      resolver: FocusSetResolver,
                      filters: FocusSetCandidateFilters) -> Int {
        counts(candidates, scopes: [scope], resolver: resolver, filters: filters)[scope] ?? 0
    }

    static func counts(_ candidates: [FocusSetCandidate],
                       scopes: [FocusSetScope],
                       resolver: FocusSetResolver,
                       filters: FocusSetCandidateFilters) -> [FocusSetScope: Int] {
        let scopes = Array(Set(scopes))
        let profileVisibleCandidates = candidates.filter { passesProfile($0, filters: filters) }
        return Dictionary(uniqueKeysWithValues: scopes.map { scope in
            let scopeVisibleCandidates = profileVisibleCandidates.filter {
                resolver.matchesApp(bundleIdentifier: $0.application.bundleIdentifier, scope: scope)
            }
            if filters.onlyMainWindowPerApplication {
                return (scope, Set(scopeVisibleCandidates.map { $0.application.pid }).count)
            }
            return (scope, scopeVisibleCandidates.count)
        })
    }

    static func countsByBundleIdentifier(_ candidates: [FocusSetCandidate],
                                         filters: FocusSetCandidateFilters) -> [String: Int] {
        let profileVisibleCandidates = candidates.filter { passesProfile($0, filters: filters) }
        var applicationPids = Set<pid_t>()
        var counts = [String: Int]()
        for candidate in profileVisibleCandidates {
            guard !filters.onlyMainWindowPerApplication || applicationPids.insert(candidate.application.pid).inserted,
                  let bundleIdentifier = candidate.application.bundleIdentifier,
                  !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            counts[bundleIdentifier, default: 0] += 1
        }
        return counts
    }

    private static func passesProfile(_ candidate: FocusSetCandidate,
                                      filters: FocusSetCandidateFilters) -> Bool {
        WindowFilterResolver.shouldShow(
            candidate.window, candidate.application,
            onlyFrontmostApp: filters.onlyFrontmostApp,
            excludeFrontmostApp: filters.excludeFrontmostApp,
            hideHidden: filters.hideHidden,
            hideWindowless: filters.hideWindowless,
            hideFullscreen: filters.hideFullscreen,
            hideMinimized: filters.hideMinimized,
            onlyVisibleSpaces: filters.onlyVisibleSpaces,
            onlyNonVisibleSpaces: filters.onlyNonVisibleSpaces,
            onlyPreferredScreen: filters.onlyPreferredScreen,
            separateTabs: filters.separateTabs,
            frontmostPid: filters.frontmostPid,
            visibleSpaceIds: filters.visibleSpaceIds,
            exceptions: filters.exceptions,
            matchesFocusSet: true,
            isOnPreferredScreen: candidate.isOnPreferredScreen)
    }
}
