import Foundation

/// A hostless window candidate used by picker counting.
struct FocusSetCandidate {
    let window: WindowState
    let application: ApplicationState

    init(window: WindowState, application: ApplicationState) {
        self.window = window
        self.application = application
    }
}

/// Immutable Focus Sets policy and shared grouping facts required by `WindowFilterResolver`.
struct FocusSetsVisibilitySnapshot {
    let policy: FocusSetsPresentationPolicy
    let separateTabs: Bool
    let onlyMainWindowPerApplication: Bool
    let exceptions: [ExceptionEntry]

    init(policy: FocusSetsPresentationPolicy = .standard,
         separateTabs: Bool = false,
         onlyMainWindowPerApplication: Bool = false,
         exceptions: [ExceptionEntry] = []) {
        self.policy = policy
        self.separateTabs = separateTabs
        self.onlyMainWindowPerApplication = onlyMainWindowPerApplication
        self.exceptions = exceptions
    }
}

/// Counts child-grid candidates without touching live `Window` or `Windows` state.
enum FocusSetCandidateCounter {
    static func count(_ candidates: [FocusSetCandidate],
                      scope: FocusSetScope,
                      resolver: FocusSetResolver,
                      visibility: FocusSetsVisibilitySnapshot) -> Int {
        counts(candidates, scopes: [scope], resolver: resolver, visibility: visibility)[scope] ?? 0
    }

    static func counts(_ candidates: [FocusSetCandidate],
                       scopes: [FocusSetScope],
                       resolver: FocusSetResolver,
                       visibility: FocusSetsVisibilitySnapshot) -> [FocusSetScope: Int] {
        let scopes = Array(Set(scopes))
        return Dictionary(uniqueKeysWithValues: scopes.map { scope in
            let scopeVisibleCandidates = candidates.filter {
                isVisible($0, scope: scope, resolver: resolver, visibility: visibility)
            }
            if visibility.onlyMainWindowPerApplication {
                return (scope, Set(scopeVisibleCandidates.map { $0.application.pid }).count)
            }
            return (scope, scopeVisibleCandidates.count)
        })
    }

    static func countsByBundleIdentifier(_ candidates: [FocusSetCandidate],
                                         visibility: FocusSetsVisibilitySnapshot) -> [String: Int] {
        var applicationPids = Set<pid_t>()
        var counts = [String: Int]()
        for candidate in candidates where isVisible(candidate, visibility: visibility) {
            guard !visibility.onlyMainWindowPerApplication || applicationPids.insert(candidate.application.pid).inserted,
                  let bundleIdentifier = candidate.application.bundleIdentifier,
                  !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            counts[bundleIdentifier, default: 0] += 1
        }
        return counts
    }

    private static func isVisible(_ candidate: FocusSetCandidate,
                                  scope: FocusSetScope = .allWindows,
                                  resolver: FocusSetResolver? = nil,
                                  visibility: FocusSetsVisibilitySnapshot) -> Bool {
        let policy = visibility.policy
        return WindowFilterResolver.shouldShow(
            candidate.window, candidate.application,
            hideHidden: policy.hideHidden,
            hideWindowless: policy.hideWindowless,
            hideFullscreen: policy.hideFullscreen,
            hideMinimized: policy.hideMinimized,
            onlyVisibleSpaces: policy.onlyVisibleSpaces,
            onlyNonVisibleSpaces: policy.onlyNonVisibleSpaces,
            onlyPreferredScreen: policy.onlyPreferredScreen,
            separateTabs: visibility.separateTabs,
            exceptions: visibility.exceptions,
            matchesFocusSet: resolver?.matchesApp(
                bundleIdentifier: candidate.application.bundleIdentifier,
                scope: scope) ?? true,
            isOnPreferredScreen: true)
    }
}
