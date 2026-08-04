import Cocoa

/// Removes everything ScryTab persists outside its own bundle, then quits.
///
/// Dragging the app to the Trash is not enough on its own: the launchd plist written by
/// `LoginItem` survives, so on every subsequent login launchd tries to start a binary that no
/// longer exists. Preferences are also spread over two suites, so removing only the main domain
/// leaves state behind that a reinstall silently inherits.
///
/// Everything is moved to the Trash rather than unlinked, so an uninstall triggered by mistake
/// stays recoverable. `UninstallPlan` decides what gets removed; this only carries it out.
enum Uninstaller {
    static func promptAndUninstall() {
        guard userConfirmedUninstall() else { return }
        forgetPreferenceDomains()
        moveToTrash(UninstallPlan.leftoverPaths(homeUrl: FileManager.default.homeDirectoryForCurrentUser,
            bundleIdentifier: App.bundleIdentifier))
        moveToTrash([App.bundleURL])
        App.shared.terminate(nil)
    }

    private static func userConfirmedUninstall() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("Uninstall ScryTab?", comment: "")
        alert.informativeText = NSLocalizedString("ScryTab and its settings will be moved to the Trash, and it will no longer start at login. You can’t undo this action from within the app.", comment: "")
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        let uninstallButton = alert.addButton(withTitle: NSLocalizedString("Uninstall", comment: ""))
        if #available(macOS 11.0, *) { uninstallButton.hasDestructiveAction = true }
        return alert.runModal() == .alertSecondButtonReturn
    }

    /// Clear both suites through `UserDefaults` before trashing their backing files: `cfprefsd`
    /// owns those files and can rewrite them from its in-memory copy while the app shuts down.
    private static func forgetPreferenceDomains() {
        UserDefaults.standard.removePersistentDomain(forName: App.bundleIdentifier)
        UserDefaults.standard.removePersistentDomain(forName: UsageStats.defaultsSuiteName)
        CachedUserDefaults.cache.withLock { $0.removeAll() }
        Preferences.invalidateAllCache()
    }

    private static func moveToTrash(_ urls: [URL]) {
        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                Logger.debug { "trashed \(url.path)" }
            } catch let error {
                Logger.error { "Failed to trash \(url.path). error:\(error)" }
            }
        }
    }
}
