import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

class Preferences {
    static var defaultValues: [String: Any] = {
        var values: [String: Any] = [
            "shortcutCount": "2",
            "nextWindowGesture": GesturePreference.disabled.indexAsString,
            "focusWindowShortcut": defaultShortcut(returnKeyEquivalent()),
            "previousWindowShortcut": defaultShortcut("⇧"),
            "cancelShortcut": defaultShortcut("⎋"),
            "lockSearchShortcut": defaultShortcut("Space"),
            "closeWindowShortcut": defaultShortcut("W"),
            "minDeminWindowShortcut": defaultShortcut("M"),
            "toggleFullscreenWindowShortcut": defaultShortcut("F"),
            "quitAppShortcut": defaultShortcut("Q"),
            "hideShowAppShortcut": defaultShortcut("H"),
            "searchShortcut": defaultShortcut("S"),
            "arrowKeysEnabled": "true",
            "vimKeysEnabled": "false",
            "mouseHoverEnabled": "false",
            "cursorFollowFocus": CursorFollowFocus.never.indexAsString,
            "hideColoredCircles": "false",
            "appearanceStyle": AppearanceStylePreference.appIcons.indexAsString,
            "appearanceSize": AppearanceSizePreference.auto.indexAsString,
            "appearanceTheme": AppearanceThemePreference.system.indexAsString,
            "sharedWindowOrder": WindowOrderPreference.recentlyFocused.indexAsString,
            "sharedGroupApps": GroupAppsPreference.allWindows.indexAsString,
            "sharedGroupTabs": GroupTabsPreference.singleWindow.indexAsString,
            "focusSetsShortcutStyle": ShortcutStylePreference.focusOnRelease.indexAsString,
            "sharedPresentationDefaultsMigrated": "false",
            "theme": ThemePreference.macOs.indexAsString,
            "showOnScreen": ShowOnScreenPreference.active.indexAsString,
            "titleTruncation": TitleTruncationPreference.end.indexAsString,
            "showTitles": ShowTitlesPreference.windowTitle.indexAsString,
            "startAtLogin": "true",
            "language": LanguagePreference.systemDefault.indexAsString,
            "exceptions": defaultExceptions(),
            "updatePolicy": UpdatePolicyPreference.autoCheck.indexAsString,
            "crashPolicy": CrashPolicyPreference.ask.indexAsString,
            "hideSpaceNumberLabels": "false",
            "hideStatusIcons": "false",
            "trackpadHapticFeedbackEnabled": "true",
            "settingsWindowShownOnFirstLaunch": "false",
            "appearanceOverrideResetChoiceRemembered": "false",
            "appearanceOverrideResetRemovesOverrides": "false",
        ]
        (0..<maxShortcutCount).forEach { index in
            values[indexToName("shortcutIdentifier", index)] = ""
            values[indexToName("holdShortcut", index)] = defaultShortcut("⌥")
            values[indexToName("nextWindowShortcut", index)] = defaultShortcut(index == 0 ? "⇥" : (index == 1 ? keyAboveTabDependingOnInputSource() : ""))
        }
        (0...maxShortcutCount).forEach { index in
            values[indexToName("appsToShow", index)] = index == 1 ? AppsToShowPreference.active.indexAsString : (index == 2 ? AppsToShowPreference.nonActive.indexAsString : AppsToShowPreference.all.indexAsString)
            values[indexToName("spacesToShow", index)] = SpacesToShowPreference.all.indexAsString
            values[indexToName("screensToShow", index)] = ScreensToShowPreference.all.indexAsString
            values[indexToName("showMinimizedWindows", index)] = ShowHowPreference.show.indexAsString
            values[indexToName("showHiddenWindows", index)] = ShowHowPreference.show.indexAsString
            values[indexToName("showFullscreenWindows", index)] = ShowHowPreference.show.indexAsString
            values[indexToName("showWindowlessApps", index)] = ShowHowPreference.showAtTheEnd.indexAsString
            values[indexToName("windowOrder", index)] = WindowOrderPreference.recentlyFocused.indexAsString
            values[indexToName("shortcutStyle", index)] = ShortcutStylePreference.focusOnRelease.indexAsString
            values[indexToName("showAppsOrWindows", index)] = GroupAppsPreference.allWindows.indexAsString
            values[indexToName("showTabsAsWindows", index)] = GroupTabsPreference.singleWindow.indexAsString
            values[indexToName("appearanceStyleOverride", index)] = AppearanceStylePreference.appIcons.indexAsString
            values[indexToName("appearanceSizeOverride", index)] = AppearanceSizePreference.auto.indexAsString
            values[indexToName("appearanceThemeOverride", index)] = AppearanceThemePreference.system.indexAsString
            values[indexToName("shortcutStyleOverride", index)] = ShortcutStylePreference.focusOnRelease.indexAsString
        }
        return values
    }()

    // system preferences
    static var finderShowsQuitMenuItem: Bool { UserDefaults(suiteName: "com.apple.Finder")?.bool(forKey: "QuitMenuItem") ?? false }
    static let staticShortcutKeys = [
        "focusWindowShortcut", "previousWindowShortcut", "cancelShortcut", "lockSearchShortcut", "closeWindowShortcut",
        "minDeminWindowShortcut", "toggleFullscreenWindowShortcut", "quitAppShortcut", "hideShowAppShortcut", "searchShortcut",
    ]
    static var allShortcutPreferenceKeys: [String] {
        staticShortcutKeys + (0..<maxShortcutCount).flatMap { [indexToName("holdShortcut", $0), indexToName("nextWindowShortcut", $0)] }
    }
    static let emptyShortcut = Shortcut(code: .none, modifierFlags: [], characters: nil, charactersIgnoringModifiers: nil)
    private static let shortcutStorageStringField = "string"
    private static let shortcutStorageDataField = "secureData"

    // persisted values
    static var holdShortcut: [Shortcut?] { (0..<shortcutCount).map { CachedUserDefaults.shortcut(indexToName("holdShortcut", $0)) } }
    static var nextWindowShortcut: [Shortcut?] { (0..<shortcutCount).map { CachedUserDefaults.shortcut(indexToName("nextWindowShortcut", $0)) } }
    static var nextWindowGesture: GesturePreference { CachedUserDefaults.macroPref("nextWindowGesture", GesturePreference.allCases) }
    static var focusWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("focusWindowShortcut") }
    static var previousWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("previousWindowShortcut") }
    static var cancelShortcut: Shortcut? { CachedUserDefaults.shortcut("cancelShortcut") }
    static var lockSearchShortcut: Shortcut? { CachedUserDefaults.shortcut("lockSearchShortcut") }
    static var closeWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("closeWindowShortcut") }
    static var minDeminWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("minDeminWindowShortcut") }
    static var toggleFullscreenWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("toggleFullscreenWindowShortcut") }
    static var quitAppShortcut: Shortcut? { CachedUserDefaults.shortcut("quitAppShortcut") }
    static var hideShowAppShortcut: Shortcut? { CachedUserDefaults.shortcut("hideShowAppShortcut") }
    static var searchShortcut: Shortcut? { CachedUserDefaults.shortcut("searchShortcut") }
    // periphery:ignore
    static var arrowKeysEnabled: Bool { CachedUserDefaults.bool("arrowKeysEnabled") }
    // periphery:ignore
    static var vimKeysEnabled: Bool { CachedUserDefaults.bool("vimKeysEnabled") }
    static var mouseHoverEnabled: Bool { CachedUserDefaults.bool("mouseHoverEnabled") }
    static var cursorFollowFocus: CursorFollowFocus { CachedUserDefaults.macroPref("cursorFollowFocus", CursorFollowFocus.allCases) }
    static var trackpadHapticFeedbackEnabled: Bool { CachedUserDefaults.bool("trackpadHapticFeedbackEnabled") }
    static var hideColoredCircles: Bool { CachedUserDefaults.bool("hideColoredCircles") }
    static var hideSpaceNumberLabels: Bool { CachedUserDefaults.bool("hideSpaceNumberLabels") }
    static var hideStatusIcons: Bool { CachedUserDefaults.bool("hideStatusIcons") }
    // periphery:ignore
    static var startAtLogin: Bool { CachedUserDefaults.bool("startAtLogin") }
    static var exceptions: [ExceptionEntry] { CachedUserDefaults.json("exceptions", [ExceptionEntry].self) }
    static var settingsWindowShownOnFirstLaunch: Bool { CachedUserDefaults.bool("settingsWindowShownOnFirstLaunch") }

    // macro values
    static var appearanceStyle: AppearanceStylePreference { CachedUserDefaults.macroPref("appearanceStyle", AppearanceStylePreference.allCases) }
    static var appearanceSize: AppearanceSizePreference { CachedUserDefaults.macroPref("appearanceSize", AppearanceSizePreference.allCases) }
    static var appearanceTheme: AppearanceThemePreference { CachedUserDefaults.macroPref("appearanceTheme", AppearanceThemePreference.allCases) }
    static var sharedWindowOrder: WindowOrderPreference { CachedUserDefaults.macroPref("sharedWindowOrder", WindowOrderPreference.allCases) }
    static var sharedGroupApps: GroupAppsPreference { CachedUserDefaults.macroPref("sharedGroupApps", GroupAppsPreference.allCases) }
    static var sharedGroupTabs: GroupTabsPreference { CachedUserDefaults.macroPref("sharedGroupTabs", GroupTabsPreference.allCases) }
    static var focusSetsShortcutStyle: ShortcutStylePreference { CachedUserDefaults.macroPref("focusSetsShortcutStyle", ShortcutStylePreference.allCases) }
    // periphery:ignore
    static var theme: ThemePreference { ThemePreference.macOs/*CachedUserDefaults.macroPref("theme", ThemePreference.allCases)*/ }
    static var showOnScreen: ShowOnScreenPreference { CachedUserDefaults.macroPref("showOnScreen", ShowOnScreenPreference.allCases) }
    static var titleTruncation: TitleTruncationPreference { CachedUserDefaults.macroPref("titleTruncation", TitleTruncationPreference.allCases) }
    static var showTitles: ShowTitlesPreference { CachedUserDefaults.macroPref("showTitles", ShowTitlesPreference.allCases) }
    static var updatePolicy: UpdatePolicyPreference { CachedUserDefaults.macroPref("updatePolicy", UpdatePolicyPreference.allCases) }
    static var crashPolicy: CrashPolicyPreference { CachedUserDefaults.macroPref("crashPolicy", CrashPolicyPreference.allCases) }
    static var appsToShow: [AppsToShowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("appsToShow", $0), AppsToShowPreference.allCases) } }
    static var spacesToShow: [SpacesToShowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("spacesToShow", $0), SpacesToShowPreference.allCases) } }
    static var screensToShow: [ScreensToShowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("screensToShow", $0), ScreensToShowPreference.allCases) } }
    static var showMinimizedWindows: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showMinimizedWindows", $0), ShowHowPreference.allCases) } }
    static var showHiddenWindows: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showHiddenWindows", $0), ShowHowPreference.allCases) } }
    static var showFullscreenWindows: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showFullscreenWindows", $0), ShowHowPreference.allCases) } }
    static var showWindowlessApps: [ShowHowPreference] { (0...maxShortcutCount).map { CachedUserDefaults.macroPref(indexToName("showWindowlessApps", $0), ShowHowPreference.allCases) } }
    static func showMinimizedWindows(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showMinimizedWindows", i), ShowHowPreference.allCases) }
    static func showHiddenWindows(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showHiddenWindows", i), ShowHowPreference.allCases) }
    static func showFullscreenWindows(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showFullscreenWindows", i), ShowHowPreference.allCases) }
    static func showWindowlessApps(_ i: Int) -> ShowHowPreference { CachedUserDefaults.macroPref(indexToName("showWindowlessApps", i), ShowHowPreference.allCases) }
    static func windowOrder(_ i: Int) -> WindowOrderPreference { effectivePresentationPreference("windowOrder", i, sharedWindowOrder, WindowOrderPreference.allCases) }
    static func groupApps(_ i: Int) -> GroupAppsPreference { effectivePresentationPreference("showAppsOrWindows", i, sharedGroupApps, GroupAppsPreference.allCases) }
    static func groupTabs(_ i: Int) -> GroupTabsPreference { effectivePresentationPreference("showTabsAsWindows", i, sharedGroupTabs, GroupTabsPreference.allCases) }
    static var shortcutStyle: ShortcutStylePreference { CachedUserDefaults.macroPref("shortcutStyle", ShortcutStylePreference.allCases) }
    static var language: LanguagePreference { CachedUserDefaults.macroPref("language", LanguagePreference.allCases) }

    static let minShortcutCount = 1
    static let maxShortcutCount = 9
    static var shortcutCount: Int {
        max(minShortcutCount, min(maxShortcutCount, CachedUserDefaults.int("shortcutCount")))
    }

    static let gestureIndex = maxShortcutCount

    static func initialize() {
        PreferencesMigrations.removeCorruptedPreferences()
        PreferencesMigrations.migratePreferences()
        registerDefaults()
    }

    static func resetAll() {
        UserDefaults.standard.removePersistentDomain(forName: App.bundleIdentifier)
        invalidateAllCache()
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaultValues)
    }

    static func markSettingsWindowShownOnFirstLaunch() {
        set("settingsWindowShownOnFirstLaunch", "true", false)
    }

    static func defaultShortcut(_ keyEquivalent: String) -> [String: Any] {
        shortcutStorage(shortcutFromKeyEquivalent(keyEquivalent), keyEquivalent)
    }

    static func setShortcut(_ key: String, _ shortcut: Shortcut?, _ notify: Bool = true) {
        setShortcut(key, shortcut, stringRepresentation: nil, notify)
    }

    static func setShortcut(_ key: String, _ shortcut: Shortcut?, stringRepresentation: String?, _ notify: Bool = true) {
        UserDefaults.standard.set(shortcutStorage(shortcut, stringRepresentation), forKey: key)
        CachedUserDefaults.removeFromCache(key)
        invalidateAllCache()
        if notify {
            PreferencesEvents.preferenceChanged(key)
        }
    }

    static func setShortcut(_ key: String, keyEquivalent: String, _ notify: Bool = true) {
        setShortcut(key, shortcutFromKeyEquivalent(keyEquivalent), stringRepresentation: keyEquivalent, notify)
    }

    static func shortcut(_ key: String) -> Shortcut? {
        CachedUserDefaults.shortcut(key)
    }

    static func set<T>(_ key: String, _ value: T, _ notify: Bool = true) where T: Encodable {
        UserDefaults.standard.set(key == "exceptions" ? jsonEncode(value) : value, forKey: key)
        CachedUserDefaults.removeFromCache(key)
        invalidateAllCache()
        if notify {
            PreferencesEvents.preferenceChanged(key)
        }
    }

    static func remove(_ key: String, _ notify: Bool = true) {
        UserDefaults.standard.removeObject(forKey: key)
        CachedUserDefaults.removeFromCache(key)
        invalidateAllCache()
        if notify {
            PreferencesEvents.preferenceChanged(key)
        }
    }

    static let focusSetsKey = "focusSets"
    static let ownedKeys: Set<String> = Set(defaultValues.keys).union([focusSetsKey])

    /// `persistentDomain(forName:)` rebuilds a full snapshot dictionary on every call, which adds
    /// up: every `hasOverride` / `effectiveAppearanceStyle` consults `all`, and the switcher show
    /// path triggers a cascade of these per show. Cache the filtered snapshot; the only paths that
    /// mutate the domain (`set`, `setShortcut`, `remove`, `resetAll`) clear `cachedAll` below.
    private static var cachedAll: [String: Any]?

    static var all: [String: Any] {
        if let cachedAll { return cachedAll }
        let domain = UserDefaults.standard.persistentDomain(forName: App.bundleIdentifier) ?? [:]
        let filtered = domain.filter { ownedKeys.contains($0.key) }
        cachedAll = filtered
        return filtered
    }

    static func invalidateAllCache() {
        cachedAll = nil
    }

    static func windowOrder(_ source: SwitcherPresentationSource) -> WindowOrderPreference {
        switch source {
            case let .shortcut(index): return windowOrder(index)
            case .focusSets: return sharedWindowOrder
        }
    }

    static func groupTabs(_ source: SwitcherPresentationSource) -> GroupTabsPreference {
        switch source {
            case let .shortcut(index): return groupTabs(index)
            case .focusSets: return sharedGroupTabs
        }
    }

    static func appearanceStyle(_ source: SwitcherPresentationSource) -> AppearanceStylePreference {
        switch source {
            case let .shortcut(index): return effectiveAppearanceStyle(index)
            case .focusSets: return appearanceStyle
        }
    }

    static func appearanceSize(_ source: SwitcherPresentationSource) -> AppearanceSizePreference {
        switch source {
            case let .shortcut(index): return effectiveAppearanceSize(index)
            case .focusSets: return appearanceSize
        }
    }

    static func appearanceTheme(_ source: SwitcherPresentationSource) -> AppearanceThemePreference {
        switch source {
            case let .shortcut(index): return effectiveAppearanceTheme(index)
            case .focusSets: return appearanceTheme
        }
    }

    static func shortcutStyle(_ source: SwitcherPresentationSource) -> ShortcutStylePreference {
        switch source {
            case let .shortcut(index): return effectiveShortcutStyle(index)
            case .focusSets: return focusSetsShortcutStyle
        }
    }

    private static func effectivePresentationPreference<T>(_ baseName: String,
                                                            _ index: Int,
                                                            _ shared: T,
                                                            _ cases: [T]) -> T where T: MacroPreference {
        guard hasOverride(baseName, index) else { return shared }
        return CachedUserDefaults.macroPref(indexToName(baseName, index), cases)
    }

    // MARK: - Per-shortcut appearance overrides

    /// The 4 override base names. Their indexed forms (e.g. `appearanceStyleOverride2`) live in
    /// `Preferences.all` only when the user has explicitly set an override on that shortcut.
    static let appearanceOverrideBaseNames = [
        "appearanceStyleOverride", "appearanceSizeOverride", "appearanceThemeOverride",
        "shortcutStyleOverride",
    ]

    /// True when the user has explicitly set an override for `baseName` on shortcut `index`.
    /// Reads from `persistentDomain` (`Preferences.all`) which excludes registered defaults, so
    /// an untouched override correctly reports `false` even though its key has a registered default.
    static func hasOverride(_ baseName: String, _ index: Int) -> Bool {
        all[indexToName(baseName, index)] != nil
    }

    static func hasAnyOverride(_ baseName: String) -> Bool {
        let persistedValues = all
        return appearanceOverrideKeys(baseName).contains { persistedValues[$0] != nil }
    }

    static func removeOverride(_ baseName: String, _ index: Int) {
        remove(indexToName(baseName, index))
    }

    /// Remove every matching persisted override, then refresh runtime and controls once.
    static func removeAllOverrides(_ baseName: String) {
        let persistedValues = all
        let keys = appearanceOverrideKeys(baseName).filter { persistedValues[$0] != nil }
        guard let notificationKey = keys.first else { return }
        keys.forEach {
            UserDefaults.standard.removeObject(forKey: $0)
            CachedUserDefaults.removeFromCache($0)
        }
        invalidateAllCache()
        PreferencesEvents.preferenceChanged(notificationKey)
    }

    private static func appearanceOverrideKeys(_ baseName: String) -> [String] {
        guard appearanceOverrideBaseNames.contains(baseName) else { return [] }
        return (0...maxShortcutCount).map { indexToName(baseName, $0) }
    }

    /// Set once the user checks "do not ask again" on the override-reset confirmation dialog. `nil`
    /// means keep asking; otherwise the stored choice (remove vs. keep overrides) is replayed as-is.
    static var appearanceOverrideResetChoice: Bool? {
        guard CachedUserDefaults.bool("appearanceOverrideResetChoiceRemembered") else { return nil }
        return CachedUserDefaults.bool("appearanceOverrideResetRemovesOverrides")
    }

    static func rememberAppearanceOverrideResetChoice(removesOverrides: Bool) {
        set("appearanceOverrideResetChoiceRemembered", "true", false)
        set("appearanceOverrideResetRemovesOverrides", removesOverrides ? "true" : "false", false)
    }

    static func effectiveAppearanceStyle(_ index: Int) -> AppearanceStylePreference {
        guard hasOverride("appearanceStyleOverride", index) else { return appearanceStyle }
        return CachedUserDefaults.macroPref(indexToName("appearanceStyleOverride", index), AppearanceStylePreference.allCases)
    }

    static func effectiveAppearanceSize(_ index: Int) -> AppearanceSizePreference {
        guard hasOverride("appearanceSizeOverride", index) else { return appearanceSize }
        return CachedUserDefaults.macroPref(indexToName("appearanceSizeOverride", index), AppearanceSizePreference.allCases)
    }

    static func effectiveAppearanceTheme(_ index: Int) -> AppearanceThemePreference {
        guard hasOverride("appearanceThemeOverride", index) else { return appearanceTheme }
        return CachedUserDefaults.macroPref(indexToName("appearanceThemeOverride", index), AppearanceThemePreference.allCases)
    }

    static func effectiveShortcutStyle(_ index: Int) -> ShortcutStylePreference {
        guard hasOverride("shortcutStyleOverride", index) else { return shortcutStyle }
        return CachedUserDefaults.macroPref(indexToName("shortcutStyleOverride", index), ShortcutStylePreference.allCases)
    }

    /// key-above-tab is ` on US keyboard, but can be different on other keyboards
    static func keyAboveTabDependingOnInputSource() -> String {
        return LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: kVK_ANSI_Grave)) ?? "`"
    }

    static func returnKeyEquivalent() -> String {
        return LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: kVK_Return)) ?? "↩"
    }

    static func defaultExceptions() -> String {
        return jsonEncode([
            ExceptionEntry(bundleIdentifier: "com.apple.finder", hide: .whenNoOpenWindow, ignore: .none),
            ExceptionEntry(bundleIdentifier: "com.apple.ScreenSharing", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.microsoft.rdc.macos", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.teamviewer.TeamViewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "org.virtualbox.app.VirtualBoxVM", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.parallels.", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.citrix.XenAppViewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.citrix.receiver.icaviewer.mac", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.nicesoftware.dcvviewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.vmware.fusion", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.utmapp.UTM", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.McAfee.McAfeeSafariHost", hide: .always, ignore: .none),
        ])
    }

    static func jsonEncode<T>(_ value: T) -> String where T: Encodable {
        return String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
    }

    static func archiveShortcut(_ shortcut: Shortcut?) -> Data {
        if #available(macOS 10.13, *) {
            return try! NSKeyedArchiver.archivedData(withRootObject: shortcut ?? emptyShortcut, requiringSecureCoding: true)
        }
        return NSKeyedArchiver.archivedData(withRootObject: shortcut ?? emptyShortcut)
    }

    static func shortcutStorage(_ shortcut: Shortcut?, _ stringRepresentation: String?) -> [String: Any] {
        [
            shortcutStorageStringField: stringRepresentation ?? shortcut?.readableStringRepresentation(isASCII: true) ?? "",
            shortcutStorageDataField: archiveShortcut(shortcut),
        ]
    }

    static func decodeShortcutStorage(_ value: Any) -> (Bool, Shortcut?) {
        guard let storage = value as? [String: Any], let data = storage[shortcutStorageDataField] as? Data else { return (false, nil) }
        return unarchiveShortcut(data)
    }

    static func unarchiveShortcut(_ data: Data) -> (Bool, Shortcut?) {
        let shortcut: Shortcut?
        if #available(macOS 10.13, *) {
            shortcut = try? NSKeyedUnarchiver.unarchivedObject(ofClass: Shortcut.self, from: data)
        } else {
            shortcut = NSKeyedUnarchiver.unarchiveObject(with: data) as? Shortcut
        }
        guard let shortcut else { return (false, nil) }
        return (true, shortcut.keyCode == .none && shortcut.modifierFlags == [] ? nil : shortcut)
    }

    static func shortcutFromKeyEquivalent(_ keyEquivalent: String) -> Shortcut? {
        keyEquivalent.isEmpty ? nil : Shortcut(keyEquivalent: keyEquivalent)
    }

    static func indexToName(_ baseName: String, _ index: Int) -> String {
        return baseName + (index == 0 ? "" : String(index + 1))
    }

    static func nameToIndex(_ name: String) -> Int {
        let digits = String(name.reversed().prefix { $0.isNumber }.reversed())
        guard !digits.isEmpty, let number = Int(digits) else { return 0 }
        return number - 1
    }
}

class CachedUserDefaults {
    static var cache = ConcurrentMap<String, Any>()

    static func removeFromCache(_ key: String) {
        cache.withLock { $0.removeValue(forKey: key) }
    }

    /// retrieve strings in the globalDomain (e.g. defaults read -g KeyRepeat)
    /// these may be nil since we they don't have default values from ScryTab
    static func globalString(_ key: String) -> String? {
        if let cached = cache.withLock({ $0[key] }) {
            return cached as? String
        }
        if let string = UserDefaults.standard.string(forKey: key) {
            cache.withLock { $0[key] = string }
        }
        return nil
    }

    static func string(_ key: String) -> String {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as! String
        }
        let finalValue = UserDefaults.standard.string(forKey: key)!
        cache.withLock { $0[key] = finalValue }
        return finalValue
    }

    static func shortcut(_ key: String) -> Shortcut? {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as? Shortcut
        }
        guard let objectValue = UserDefaults.standard.object(forKey: key) else {
            cache.withLock { $0[key] = NSNull() }
            return nil
        }
        let (isValid, finalValue) = Preferences.decodeShortcutStorage(objectValue)
        if isValid {
            cache.withLock { $0[key] = finalValue ?? NSNull() }
            return finalValue
        }
        UserDefaults.standard.removeObject(forKey: key)
        return shortcut(key)
    }

    static func int(_ key: String) -> Int {
        return getThenConvertOrReset(key, { s in Int(s) })
    }

    static func bool(_ key: String) -> Bool {
        return getThenConvertOrReset(key, { s in Bool(s) })
    }

    static func double(_ key: String) -> Double {
        return getThenConvertOrReset(key, { s in Double(s) })
    }

    static func macroPref<A>(_ key: String, _ macroPreferences: [A]) -> A {
        return getThenConvertOrReset(key, { s in Int(s).flatMap { macroPreferences[safe: $0] } })
    }

    /// some UI elements (e.g. dropdown, radios) need an int. We find the right int from the MacroPreference index
    static func intFromMacroPref(_ key: String, _ macroPreferences: [MacroPreference]) -> Int {
        let macroPref = macroPref(key, macroPreferences)
        return macroPreferences.firstIndex { $0.localizedString == macroPref.localizedString }!
    }

    static func json<T>(_ key: String, _ type: T.Type) -> T where T: Decodable {
        return getThenConvertOrReset(key, { s in jsonDecode(s, type) })
    }

    private static func getThenConvertOrReset<T>(_ key: String, _ getterFn: (String) -> T?) -> T {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as! T
        }
        let stringValue = UserDefaults.standard.string(forKey: key)!
        if let finalValue = getterFn(stringValue) {
            cache.withLock { $0[key] = finalValue }
            return finalValue
        }
        // value couldn't be read properly; we remove it and work with the default
        UserDefaults.standard.removeObject(forKey: key)
        let defaultStringValue = UserDefaults.standard.string(forKey: key)!
        let defaultFinalValue = getterFn(defaultStringValue)!
        cache.withLock { $0[key] = defaultFinalValue }
        return defaultFinalValue
    }

    private static func jsonDecode<T>(_ value: String, _ type: T.Type) -> T? where T: Decodable {
        return value.data(using: .utf8).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

struct ExceptionEntry: Codable {
    var bundleIdentifier: String
    var hide: ExceptionHidePreference
    var ignore: ExceptionIgnorePreference
    var windowTitleContains: [String]?

    init(bundleIdentifier: String, hide: ExceptionHidePreference, ignore: ExceptionIgnorePreference, windowTitleContains: [String]? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.hide = hide
        self.ignore = ignore
        self.windowTitleContains = windowTitleContains
    }

    // Permissive decoder so we can read both the legacy single-string shape
    // (windowTitleContains: String?) and the current array shape ([String]?). Without this,
    // a decode failure on legacy data would cause `getThenConvertOrReset` in Preferences to
    // wipe the entry back to defaultExceptions(), losing the user's patterns.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIdentifier = try c.decode(String.self, forKey: .bundleIdentifier)
        self.hide = try c.decode(ExceptionHidePreference.self, forKey: .hide)
        self.ignore = try c.decode(ExceptionIgnorePreference.self, forKey: .ignore)
        if let array = try? c.decode([String].self, forKey: .windowTitleContains) {
            self.windowTitleContains = array.isEmpty ? nil : array
        } else if let string = try? c.decode(String.self, forKey: .windowTitleContains), !string.isEmpty {
            self.windowTitleContains = [string]
        } else {
            self.windowTitleContains = nil
        }
    }
}
