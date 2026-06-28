import Cocoa
import Sparkle

class GeneralTab {
    static var updatesPolicyDropdown: NSPopUpButton?
    static var crashPolicyDropdown: NSPopUpButton?
    static var accessibilityPermissionRow: PermissionStatusRow?
    static var policyLock = false

    static func initTab() -> NSView {
        let form = SettingsFormView()
        form.addSection(startupSection())
        form.addSection(languageSection())
        form.addSection(updatesSection())
        form.addSection(privacyDiagnosticsSection())
        form.addSection(dataSection())
        return form
    }

    private static func startupSection() -> SettingsSectionView {
        let section = SettingsSectionView(title: NSLocalizedString("Startup", comment: ""))
        let startAtLoginSwitch = LabelAndControl.makeSwitch("startAtLogin")
        let startupRow = SettingsRowView(title: NSLocalizedString("Start at login", comment: ""), content: [startAtLoginSwitch])
        startupRow.registerFocusAnchor("general-startAtLogin", focalControl: startAtLoginSwitch)
        section.addRow(startupRow)
        return section
    }

    private static func languageSection() -> SettingsSectionView {
        let section = SettingsSectionView(title: NSLocalizedString("Language", comment: ""))
        let languageDropdown = LabelAndControl.makeDropdown("language", LanguagePreference.allCases, extraAction: setLanguageCallback)
        let languageRow = SettingsRowView(title: NSLocalizedString("Language", comment: ""), subtitle: NSLocalizedString("Changing the language requires a restart.", comment: ""), content: [languageDropdown])
        languageRow.registerFocusAnchor("general-language", focalControl: languageDropdown)
        section.addRow(languageRow)
        return section
    }

    private static func updatesSection() -> SettingsSectionView {
        updatesPolicyDropdown = LabelAndControl.makeDropdown("updatePolicy", UpdatePolicyPreference.allCases)
        let checkButton = SurfaceButton(title: NSLocalizedString("Check for updates now…", comment: ""), role: .flat) { _ in
            checkForUpdatesNow(nil)
        }
        let section = SettingsSectionView(title: NSLocalizedString("Updates", comment: ""))
        let policyRow = SettingsRowView(title: NSLocalizedString("Updates policy", comment: ""), content: [updatesPolicyDropdown!])
        policyRow.registerFocusAnchor("general-updatesPolicy", focalControl: updatesPolicyDropdown!)
        let checkRow = SettingsRowView(title: NSLocalizedString("Check for updates", comment: ""), content: [checkButton])
        checkRow.registerFocusAnchor("general-checkForUpdates", focalControl: checkButton)
        section.addRow(policyRow)
        section.addRow(checkRow)
        return section
    }

    private static func privacyDiagnosticsSection() -> SettingsSectionView {
        crashPolicyDropdown = LabelAndControl.makeDropdown("crashPolicy", CrashPolicyPreference.allCases)
        let section = SettingsSectionView(title: NSLocalizedString("Privacy & diagnostics", comment: ""))
        let crashRow = SettingsRowView(title: NSLocalizedString("Crash reports policy", comment: ""), content: [crashPolicyDropdown!])
        crashRow.registerFocusAnchor("general-crashPolicy", focalControl: crashPolicyDropdown!)
        section.addRow(crashRow)
        let permRow = PermissionStatusRow(
            title: NSLocalizedString("Accessibility", comment: ""),
            text: NSLocalizedString("Required to focus windows after you release the shortcut.", comment: ""),
            image: NSImage.fromSymbol(.handRaised, pointSize: 18),
            statusText: accessibilityStatusText(AccessibilityPermission.status),
            status: accessibilityStatusKind(AccessibilityPermission.status),
            action: { _ in
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        )
        permRow.registerFocusAnchor("general-accessibilityPermission", focalControl: permRow)
        accessibilityPermissionRow = permRow
        section.addRow(permRow)
        return section
    }

    private static func accessibilityStatusKind(_ status: PermissionStatus) -> PermissionStatusKind {
        status == .granted ? .granted : .missing
    }

    private static func accessibilityStatusText(_ status: PermissionStatus) -> String {
        status == .granted
            ? NSLocalizedString("Granted", comment: "")
            : NSLocalizedString("Not granted", comment: "")
    }

    private static func dataSection() -> SettingsSectionView {
        let exportButton = SurfaceButton(title: NSLocalizedString("Export settings…", comment: ""), role: .flat) { _ in
            exportSettings()
        }
        let importButton = SurfaceButton(title: NSLocalizedString("Import settings…", comment: ""), role: .flat) { _ in
            importSettings()
        }
        let resetButton = NSButton(title: NSLocalizedString("Reset settings and restart…", comment: ""), target: nil, action: nil)
        resetButton.bezelStyle = .rounded
        if #available(macOS 11.0, *) { resetButton.hasDestructiveAction = true }
        resetButton.onAction = { _ in resetPreferences() }
        let section = SettingsSectionView(title: NSLocalizedString("Data", comment: ""))
        let exportRow = SettingsRowView(title: NSLocalizedString("Export and import", comment: ""), content: [exportButton, importButton])
        exportRow.registerFocusAnchor("general-exportImport", focalControl: exportButton)
        let resetRow = SettingsRowView(title: NSLocalizedString("Reset settings and restart", comment: ""), subtitle: NSLocalizedString("Restore all preferences to their defaults and restart the app.", comment: ""), content: [resetButton])
        resetRow.registerFocusAnchor("general-reset", focalControl: resetButton)
        section.addRow(exportRow)
        section.addRow(resetRow)
        return section
    }

    static func cleanup() {
        updatesPolicyDropdown = nil
        crashPolicyDropdown = nil
        accessibilityPermissionRow = nil
        SettingsFocusRegistry.shared.unregisterPrefix("general-")
    }

    static func refreshControlsFromPreferences() {
        updatesPolicyDropdown?.selectItem(at: CachedUserDefaults.intFromMacroPref("updatePolicy", UpdatePolicyPreference.allCases))
        crashPolicyDropdown?.selectItem(at: CachedUserDefaults.intFromMacroPref("crashPolicy", CrashPolicyPreference.allCases))
    }

    static func refreshAccessibilityPermissionRow() {
        let status = AccessibilityPermission.status
        accessibilityPermissionRow?.setStatus(accessibilityStatusText(status), accessibilityStatusKind(status))
    }

    @objc static func resetPreferences() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = ""
        alert.informativeText = NSLocalizedString("You can’t undo this action.", comment: "")
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        let resetButton = alert.addButton(withTitle: NSLocalizedString("Reset settings and restart", comment: ""))
        if #available(macOS 11.0, *) { resetButton.hasDestructiveAction = true }
        if alert.runModal() == .alertSecondButtonReturn {
            Preferences.resetAll()
            App.restart()
        }
    }

    @objc static func checkForUpdatesNow(_ sender: Any?) {
        // The updater is lazy-started 30s after launch; if the user presses this button before
        // then, defensively start it first (idempotent — second call is a no-op).
        App.updaterController?.startUpdater()
        App.updaterController?.checkForUpdates(sender)
    }

    private static func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(App.bundleIdentifier).plist"
        panel.allowedFileTypes = ["plist"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        NSDictionary(dictionary: Preferences.all).write(to: url, atomically: true)
    }

    private static func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["plist"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Failed to import settings", comment: "")
            alert.runModal()
            return
        }
        let filtered = dict.filter { Preferences.ownedKeys.contains($0.key) }
        UserDefaults.standard.setPersistentDomain(filtered, forName: App.bundleIdentifier)
        CachedUserDefaults.cache.withLock { $0.removeAll() }
        Preferences.invalidateAllCache()
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Settings imported", comment: "")
        alert.informativeText = NSLocalizedString("The application needs to restart to apply the imported settings.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: ""))
        let laterButton = alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
        laterButton.keyEquivalent = "\u{1b}" // Escape
        if alert.runModal() == .alertFirstButtonReturn {
            App.restart()
        }
    }

    static func setLanguageCallback(_ sender: NSControl) {
        if Preferences.language == .systemDefault {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([Preferences.language.appleLanguageCode!], forKey: "AppleLanguages")
        }
        // Inform the user that the app needs to restart to apply the language change
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Language Change", comment: "")
        alert.informativeText = NSLocalizedString("The application needs to restart to apply the language change.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: ""))
        let laterButton = alert.addButton(withTitle: NSLocalizedString("Later", comment: ""))
        laterButton.keyEquivalent = "\u{1b}" // Escape
        if alert.runModal() == .alertFirstButtonReturn {
            App.restart()
        }
    }
}