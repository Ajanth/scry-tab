import Cocoa
import Sparkle

/// Side-effect dispatcher for preference changes. Each branch of `preferenceChanged(_:)`
/// calls into a domain-specific owner (Menubar, TrackpadEvents, SparkleDelegate, LoginItem)
/// rather than implementing the side effect inline. Over time each call-site should subscribe
/// directly to its own preference; this file is a transition scaffold.
class PreferencesEvents {
    private static var initialized = false
    private static let preferencesRequiringUiReset = [
        "appearanceStyle",
        "appearanceSize",
        "appearanceTheme",
        "sharedWindowOrder",
        "showOnScreen",
    ]

    /// True if `key` is an indexed override of an overridable appearance preference
    /// (e.g. `appearanceStyleOverride2`). Used to refresh the switcher and Settings controls.
    private static func isOverrideKey(_ key: String) -> Bool {
        for baseName in Preferences.appearanceOverrideBaseNames {
            for i in 0...Preferences.maxShortcutCount {
                if Preferences.indexToName(baseName, i) == key { return true }
            }
        }
        return false
    }

    /// True if `key` is an indexed per-shortcut window-order pref (`windowOrder` + index suffix).
    private static func isPerShortcutOrderingKey(_ key: String) -> Bool {
        for i in 0...Preferences.maxShortcutCount {
            if Preferences.indexToName("windowOrder", i) == key { return true }
        }
        return false
    }

    static func initialize() {
        guard !initialized else { return }
        initialized = true
        UserDefaultsEvents.observe()
        ControlsTab.initializePreferencesDependentState()
        applyUpdatePolicyPreference()
        if FeatureFlags.gestures { TrackpadEvents.toggle(Preferences.nextWindowGesture != .disabled) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            LoginItem.applyCurrentPreference()
        }
    }

    static func preferenceChanged(_ key: String) {
        if !initialized {
            if key == "startAtLogin" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    LoginItem.applyCurrentPreference()
                }
            }
            return
        }
        ControlsTab.preferenceChanged(key)
        switch key {
        case "nextWindowGesture":
            if FeatureFlags.gestures { TrackpadEvents.toggle(Preferences.nextWindowGesture != .disabled) }
        case "startAtLogin": LoginItem.applyCurrentPreference()
        case "updatePolicy": applyUpdatePolicyPreference()
        case let k where preferencesRequiringUiReset.contains(k) && TilesPanel.shared != nil: App.resetPreferencesDependentComponents()
        case let k where (isOverrideKey(k) || isPerShortcutOrderingKey(k)) && TilesPanel.shared != nil: App.resetPreferencesDependentComponents()
        default: break
        }
    }

    private static func applyUpdatePolicyPreference() {
        GeneralTab.policyLock = true
        let policy = Preferences.updatePolicy
        App.updaterController?.updater.automaticallyDownloadsUpdates = policy == .autoInstall
        App.updaterController?.updater.automaticallyChecksForUpdates = policy == .autoInstall || policy == .autoCheck
        GeneralTab.policyLock = false
    }
}
