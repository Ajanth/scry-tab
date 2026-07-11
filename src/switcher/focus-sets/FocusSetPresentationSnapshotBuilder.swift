import Cocoa

enum FocusSetPresentationSnapshotBuilder {
    static func make(configuration: FocusSetsConfiguration? = nil,
                     countedScopes: [FocusSetScope]? = nil) -> FocusSetPresentationSnapshot {
        precondition(Thread.isMainThread, "Focus Set presentation snapshots require the main thread.")
        let configuration = configuration ?? readConfiguration()
        let visibility = makeVisibilitySnapshot()
        let resolver = FocusSetResolver(configuration: configuration)
        let scopes = countedScopes ?? ([FocusSetScope.allWindows, .unassigned] + configuration.sets.map { .set(id: $0.id) })
        let candidates = scopes.isEmpty ? [] : makeCandidates()
        let candidateCounts = FocusSetCandidateCounter.counts(
            candidates,
            scopes: scopes,
            resolver: resolver,
            visibility: visibility)
        return FocusSetPresentationSnapshot(
            configuration: configuration,
            resolver: resolver,
            candidates: candidates,
            visibility: visibility,
            candidateCounts: candidateCounts)
    }

    private static func readConfiguration() -> FocusSetsConfiguration {
        FocusSetsStore().read()
    }

    private static func makeVisibilitySnapshot() -> FocusSetsVisibilitySnapshot {
        FocusSetsVisibilitySnapshot(
            separateTabs: Preferences.sharedGroupTabs == .separateWindows,
            onlyMainWindowPerApplication: Preferences.sharedGroupApps == .mainWindow,
            exceptions: Preferences.exceptions)
    }

    private static func makeCandidates() -> [FocusSetCandidate] {
        Windows.list.map {
            FocusSetCandidate(
                window: $0.state,
                application: $0.application.state)
        }
    }
}
