import Cocoa

class Menubar {
    static var statusItem: NSStatusItem!
    static var menu: NSMenu!
    private static var isVisibleObserver: NSKeyValueObservation?

    @discardableResult
    static func addMenuItem(_ title: String, _ action: Selector, _ keyEquivalent: String, _ symbolName: String?, _ color: NSColor? = nil, _ target: AnyObject? = nil) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        if #available(macOS 26.0, *), let symbolName {
            item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            if let color {
                item.image = item.image?.withSymbolConfiguration(.init(paletteColors: [color]))
            }
        }
        return item
    }

    static func initialize() {
        menu = NSMenu()
        menu.title = App.name // perf: prevent going through expensive code-path within appkit
        addMenuItem(NSLocalizedString("Show", comment: "Menubar option"), #selector(App.showUiFromShortcut0), "", "eye", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(NSLocalizedString("Settings…", comment: "Menubar option"), #selector(App.showSettingsWindow as () -> Void), ",", "gear", nil, App.self)
        addMenuItem(NSLocalizedString("Take ScryTab Tour…", comment: "Menubar option"), #selector(App.showOnboardingTour), "", "sparkles", nil, App.self)
        addMenuItem(NSLocalizedString("Check for updates…", comment: "Menubar option"), #selector(App.checkForUpdatesNow), "", "checkmark.arrow.trianglehead.clockwise", nil, App.self)
        addMenuItem(NSLocalizedString("Check permissions…", comment: "Menubar option"), #selector(App.checkPermissions), "", "hand.raised", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(String(format: NSLocalizedString("About %@", comment: "Menubar option. %@ is ScryTab"), App.name), #selector(App.showAboutWindow), "", "info.circle", nil, App.self)
        addMenuItem(NSLocalizedString("Debug tools", comment: "Menubar option"), #selector(App.showDebugWindow), "", "scope", nil, App.self)
        addMenuItem(NSLocalizedString("Send feedback…", comment: "Menubar option"), #selector(App.showFeedbackPanel), "", "text.bubble", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(String(format: NSLocalizedString("Quit %@", comment: "%@ is ScryTab"), App.name), #selector(NSApplication.terminate(_:)), "q", nil) // "xmark.rectangle" is not necessary; macos automatically recognizes Quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Must precede any `isVisible` write, so the user can Command-drag the icon away and
        // `observeVisibility` can persist that removal.
        statusItem.behavior = .removalAllowed
        statusItem.button!.target = self
        statusItem.button!.action = #selector(statusItemOnClick)
        statusItem.button!.sendAction(on: [.leftMouseDown, .rightMouseDown])
        // Load the app icon eagerly here, while the status item is still being added to the
        // menubar. Doing it later sets `button.image` after the WindowServer has already laid
        // the menubar out at its imageless default size, then invalidates NSStatusBarContentView
        // mid-FBS-scene-update — `_NSDetectedLayoutRecursion`.
        loadAppIcon()
        applyVisibilityPreference()
        observeVisibility()
        #if DEBUG
        installQAMenuMiddleClickMonitor()
        #endif
    }

    #if DEBUG
    private static var qaMenuMiddleClickMonitor: Any?

    // NSStatusBarButton doesn't forward `.otherMouseDown` to its action even when added to
    // `sendAction(on:)`. A local event monitor sees the click before the button can swallow it.
    private static func installQAMenuMiddleClickMonitor() {
        qaMenuMiddleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
            guard event.buttonNumber == 2,
                  let buttonWindow = statusItem?.button?.window,
                  event.window === buttonWindow else { return event }
            QAMenu.toggleVisibility()
            return nil
        }
    }
    #endif

    @objc static func statusItemOnClick() {
        // NSApp.currentEvent == nil if the icon is "clicked" through VoiceOver
        if let type = NSApp.currentEvent?.type, type != .leftMouseDown {
            App.showUiFromShortcut0()
        } else {
            guard let button = statusItem.button else { return }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }

    /// The app icon is loaded eagerly in `initialize`; whether it is *shown* is the preference's
    /// decision, applied by `applyVisibilityPreference`.
    static private func loadAppIcon() {
        guard let button = statusItem.button else { return }
        let image = MenubarStatusIcon.makeImage(from: App.appIcon(for: MenubarStatusIcon.pointSize))
        button.image = image
        button.imageScaling = .scaleProportionallyUpOrDown
    }

    /// Show or hide the live status item without recreating it or its menu, so a hidden icon stays
    /// usable by Settings and `applicationShouldHandleReopen`.
    static func applyVisibilityPreference() {
        guard statusItem != nil else { return }
        statusItem.isVisible = Preferences.showMenubarIcon
    }

    /// Native Command-drag removal hides the item outside ScryTab's control; persist it once and
    /// let the Settings switch follow, without firing the switch's own action.
    private static func observeVisibility() {
        isVisibleObserver?.invalidate()
        isVisibleObserver = statusItem.observe(\.isVisible, options: [.old, .new]) { _, change in
            guard change.oldValue == true, change.newValue == false else { return }
            GeneralTab.menuIconShownToggle?.setSilently(.off)
            guard Preferences.showMenubarIcon else { return }
            Preferences.set(MenubarVisibilityPreference.key, "false")
        }
    }
}
