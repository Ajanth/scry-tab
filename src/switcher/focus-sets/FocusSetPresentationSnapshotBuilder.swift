import Cocoa

enum FocusSetPresentationSnapshotBuilder {
    static func make(configuration: FocusSetsConfiguration? = nil,
                     countedScopes: [FocusSetScope]? = nil) -> FocusSetPresentationSnapshot {
        precondition(Thread.isMainThread, "Focus Set presentation snapshots require the main thread.")
        let configuration = configuration ?? readConfiguration()
        let profileIndex = Preferences.shortcutIndex(forIdentifier: configuration.presentationShortcutIdentifier) ?? 0
        let filters = makeFilters(profileIndex: profileIndex)
        let resolver = FocusSetResolver(configuration: configuration)
        let scopes = countedScopes ?? ([FocusSetScope.allWindows, .unassigned] + configuration.sets.map { .set(id: $0.id) })
        let candidates = scopes.isEmpty ? [] : makeCandidates(requiresPreferredScreen: filters.onlyPreferredScreen)
        let candidateCounts = FocusSetCandidateCounter.counts(
            candidates,
            scopes: scopes,
            resolver: resolver,
            filters: filters)
        return FocusSetPresentationSnapshot(
            configuration: configuration,
            profileIndex: profileIndex,
            resolver: resolver,
            candidates: candidates,
            filters: filters,
            candidateCounts: candidateCounts)
    }

    private static func readConfiguration() -> FocusSetsConfiguration {
        let identifiers = (0..<Preferences.shortcutCount).map { Preferences.shortcutIdentifier(at: $0) }
        return FocusSetsStore().read(availableShortcutIdentifiers: identifiers)
    }

    private static func makeFilters(profileIndex: Int) -> FocusSetCandidateFilters {
        let profile = Preferences.shortcut(at: profileIndex)
        return FocusSetCandidateFilters(
            onlyFrontmostApp: profile.appsToShow == .active,
            excludeFrontmostApp: profile.appsToShow == .nonActive,
            hideHidden: profile.showHiddenWindows == .hide,
            hideWindowless: profile.showWindowlessApps == .hide,
            hideFullscreen: profile.showFullscreenWindows == .hide,
            hideMinimized: profile.showMinimizedWindows == .hide,
            onlyVisibleSpaces: profile.spacesToShow == .visible,
            onlyNonVisibleSpaces: profile.spacesToShow == .nonVisible,
            onlyPreferredScreen: profile.screensToShow == .showingScryTab,
            separateTabs: Preferences.groupTabs(profileIndex) == .separateWindows,
            onlyMainWindowPerApplication: Preferences.onlyShowMainWindows(profileIndex),
            frontmostPid: Applications.frontmostPid,
            visibleSpaceIds: Spaces.visibleSpaces,
            exceptions: Preferences.exceptions)
    }

    private static func makeCandidates(requiresPreferredScreen: Bool) -> [FocusSetCandidate] {
        Windows.list.map {
            FocusSetCandidate(
                window: $0.state,
                application: $0.application.state,
                isOnPreferredScreen: !requiresPreferredScreen || $0.isOnScreen(NSScreen.preferred))
        }
    }
}
