import Cocoa
import Darwin
import ShortcutRecorder
import Sparkle

class App: ScryTabApplication {
    /// periphery:ignore
    static let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
        reason: "Prevent App Nap to preserve responsiveness")
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    static let bundleURL = Bundle.main.bundleURL
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    static let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String).flatMap { $0.isEmpty ? nil : $0 } ?? name
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    static let licence = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as! String
    static let repository = "https://github.com/Ajanth/scry-tab"
    static let appIconReps = CGImage.allNamed("app.icns")

    static func appIcon(for size: NSSize) -> CGImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let scaled = NSSize(width: size.width * scale, height: size.height * scale)
        return CGImage.bestMatch(appIconReps, for: scaled)
    }
    override class var shared: App { super.shared as! App }
    private static var isVeryFirstSummon = true
    private static var pendingShowSettingsWindow = false
    private static let sentryCrashReporter = SentryCrashReporter.shared
    // periphery:ignore
    static var sparkleDelegate: SparkleDelegate?
    static var updaterController: SPUStandardUpdaterController?
    private static let switcherUiRefreshThrottler = Throttler(delayInMs: 200)

    override init() {
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        super.init()
        delegate = self
    }

    private static var crashReportPolicy: CrashReportPolicy {
        CrashReportPolicy(rawValue: Preferences.crashPolicy.indexAsString) ?? .ask
    }

    static func captureHandledException(_ exception: NSException) {
        sentryCrashReporter.captureHandledException(exception, policy: crashReportPolicy)
    }

    private static func presentCrashReportConsentIfNeeded() {
        guard crashReportPolicy == .ask else { return }
        App.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Enable automatic crash reports?", comment: "")
        alert.informativeText = NSLocalizedString("Help improve ScryTab by automatically sending crash reports. You can change this later in Settings.", comment: "")
        let notNowButton = alert.addButton(withTitle: NSLocalizedString("Not now", comment: ""))
        notNowButton.keyEquivalent = "\u{1b}"
        let enableButton = alert.addButton(withTitle: NSLocalizedString("Enable", comment: ""))
        enableButton.keyEquivalent = "\r"
        let policy = CrashReportPolicy.afterConsent(alert.runModal() == .alertSecondButtonReturn)
        Preferences.set("crashPolicy", policy.rawValue)
        sentryCrashReporter.startIfAllowed(policy: policy, dsn: Secrets.sentryDsn)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    /// we put application code here which should be executed on init() and Preferences change
    static func resetPreferencesDependentComponents() {
        TilesView.reset()
        guard let session = SwitcherSession.current else { return }
        guard session.focusSetSessionState.directFocusSetIdentifier != nil else { return }
        refreshFocusSetGridAfterExternalEvent(session)
    }

    private static func directFocusSetSnapshot() -> FocusSetPresentationSnapshot {
        FocusSetPresentationSnapshotBuilder.make()
    }

    private static func updateFocusSetSession(_ snapshot: FocusSetPresentationSnapshot,
                                              session: SwitcherSession) {
        session.focusSetPresentationSnapshot = snapshot
        session.presentationSource = .focusSets
    }

    static func restart() {
        // we use -n to open a new instance, to avoid calling applicationShouldHandleReopen
        // we use Bundle.main.bundlePath in case of multiple ScryTab versions on the machine
        printStackTrace()
        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-n", Bundle.main.bundlePath])
        App.shared.terminate(nil)
    }

    static func hideUi() {
        Logger.info { "active:\(SwitcherSession.isActive)" }
        guard SwitcherSession.current != nil else { return } // already hidden
        KeyRepeatTimer.stopCurrentTimer()
        SwitcherSession.current = nil
        UsageStats.resetSession()
        TilesView.endSearchSession()
        ContextMenuEvents.toggle(false)
        CursorEvents.toggle(false)
        TrackpadEvents.reset()
        Tooltips.hideAll()
        hideTilesPanelWithoutChangingKeyWindow()
        MainMenu.toggle(true)
    }

    /// we don't want another window to become key when the TilesPanel is hidden
    static func hideTilesPanelWithoutChangingKeyWindow() {
        allSecondaryWindowsCanBecomeKey(false)
        TilesPanel.shared.orderOut(nil)
        allSecondaryWindowsCanBecomeKey(true)
    }

    private static func allSecondaryWindowsCanBecomeKey(_ canBecomeKey_: Bool) {
        SettingsWindow.canBecomeKey_ = canBecomeKey_
        AboutWindow.canBecomeKey_ = canBecomeKey_
        PermissionsWindow.canBecomeKey_ = canBecomeKey_
        FeedbackWindow.canBecomeKey_ = canBecomeKey_
        DebugWindow.canBecomeKey_ = canBecomeKey_
    }

    static func focusTarget() {
        guard SwitcherSession.isActive else { return }
        let selectedWindow = Windows.selectedWindow()
        if let selectedWindow { Logger.info { selectedWindow.debugId } }
        focusSelectedWindow(selectedWindow)
    }

    @objc static func checkForUpdatesNow(_ sender: NSMenuItem) {
        GeneralTab.checkForUpdatesNow(sender)
    }

    @objc static func checkPermissions(_ sender: NSMenuItem) {
        showPermissionsWindow()
    }

    @objc static func showFeedbackPanel() {
        let wasFresh = FeedbackWindow.shared == nil
        initializeFeedbackWindowIfNeeded()
        // Fresh init already runs reset(); skip the redundant second call so we don't
        // double-fire the Sparkle preflight on the first ever open.
        if !wasFresh { FeedbackWindow.shared?.reset() }
        showSecondaryWindow(FeedbackWindow.shared!)
    }

    @objc static func showDebugWindow() {
        initializeDebugWindowIfNeeded()
        showSecondaryWindow(DebugWindow.shared!)
    }

    @objc static func showSettingsWindow() {
        showSettingsWindow(route: .appearance)
    }

    static func showSettingsWindow(route: SettingsRoute) {
        guard Menubar.statusItem != nil else {
            pendingShowSettingsWindow = true
            return
        }
        initializeSettingsWindowIfNeeded(route: route)
        SettingsWindow.shared?.navigate(to: route)
        showSecondaryWindow(SettingsWindow.shared!)
        if SettingsWindow.shared!.isVisible != true {
            let window = SettingsWindow(initialRoute: route)
            window.navigate(to: route)
            showSecondaryWindow(window)
            window.orderFrontRegardless()
        }
    }

    @objc static func showAboutWindow() {
        showSettingsWindow(route: .about)
    }

    static func showSecondaryWindow(_ window: NSWindow) {
        NSScreen.updatePreferred()
        App.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // if the window was resized/repositioned by the user, restore the window the way it was.
        // ObjCExceptionCatcher guards a corrupt persisted frame (non-finite / out of Int32 bounds):
        // applying it throws NSInternalInconsistencyException and would abort the app (f481d5b0).
        var restored = false
        ObjCExceptionCatcher.catching { restored = window.setFrameUsingName(window.frameAutosaveName) }
        if !restored {
            NSScreen.preferred.repositionPanel(window)
            // Use the center function to continue to center, the `repositionPanel` function cannot center, it may be a system bug
            window.center()
        }
    }

    private static func initializeSettingsWindowIfNeeded(route: SettingsRoute = .appearance) {
        if SettingsWindow.shared == nil { _ = SettingsWindow(initialRoute: route) }
    }

    private static func initializeAboutWindowIfNeeded() {
        if AboutWindow.shared == nil { _ = AboutWindow() }
    }

    private static func initializeFeedbackWindowIfNeeded() {
        if FeedbackWindow.shared == nil { _ = FeedbackWindow() }
    }

    private static func initializeDebugWindowIfNeeded() {
        if DebugWindow.shared == nil { _ = DebugWindow() }
    }

    private static func initializePermissionsWindowIfNeeded() {
        if PermissionsWindow.shared == nil { _ = PermissionsWindow() }
    }

    @discardableResult
    private static func showSettingsWindowOnFirstLaunchIfNeeded() -> Bool {
        guard !Preferences.settingsWindowShownOnFirstLaunch else { return false }
        showAndCenterSettingsWindowOnFirstLaunch()
        return true
    }

    /// `showSettingsWindow()` relies on a saved autosave frame to position the window. On first
    /// launch there's no saved frame, and `showSecondaryWindow`'s fallback centering doesn't always
    /// stick (the window has been observed at the lower-left corner). Force a center pass after
    /// showing so the user sees the window in the middle of the screen.
    private static func showAndCenterSettingsWindowOnFirstLaunch() {
        showSettingsWindow()
        if let window = SettingsWindow.shared {
            NSScreen.preferred.repositionPanel(window)
            window.center()
        }
        Preferences.markSettingsWindowShownOnFirstLaunch()
    }

    static func showPermissionsWindow() {
        initializePermissionsWindowIfNeeded()
        PermissionsWindow.show()
    }

    static func showUi(_ shortcutIndex: Int) {
        showUiOrCycleSelection(shortcutIndex, true)
    }

    @objc static func showUiFromShortcut0() {
        showUi(0)
    }

    static func cycleSelection(_ direction: Direction, allowWrap: Bool = true) {
        (TilesView.scrollView?.documentView as? TilesDocumentView)?.cancelDraggingTimer()
        CursorEvents.resetDeadzone()
        if direction == .up || direction == .down {
            TilesView.navigateUpOrDown(direction, allowWrap: allowWrap)
        } else {
            Windows.cycleSelectedWindowIndex(direction.step(), allowWrap: allowWrap)
        }
    }

    static func handleDirectFocusSetShortcut(_ identifier: UUID, state: ShortcutState) {
        guard state == .down else { return }
        let snapshot = directFocusSetSnapshot()
        let currentState = SwitcherSession.current?.focusSetSessionState ?? .idle
        let decision = FocusSetSessionResolver.resolve(
            FocusSetSessionInput(
                state: currentState,
                event: .directFocusSetShortcut(identifier),
                availableFocusSetIdentifiers: Set(snapshot.configuration.sets.map(\.id))))
        guard decision.action != .noOp else { return }
        guard let session = SwitcherSession.current ?? makeSwitcherSession(for: decision) else { return }
        NSScreen.updatePreferred()
        if isVeryFirstSummon {
            Windows.sortByLevel()
            isVeryFirstSummon = false
        }
        session.forceDoNothingOnRelease = false
        applyFocusSetDecision(decision, snapshot: snapshot, session: session)
    }

    private static func makeSwitcherSession(for decision: FocusSetSessionDecision) -> SwitcherSession? {
        guard decision.action == .showDirectFocusSetGrid else { return nil }
        let session = SwitcherSession()
        SwitcherSession.current = session
        return session
    }

    static func handleDirectFocusSetChordRelease(_ identifier: UUID) {
        guard let session = SwitcherSession.current,
              session.focusSetSessionState.directFocusSetIdentifier == identifier else { return }
        switch FocusSetSessionResolver.directFocusSetReleaseAction(
                  state: session.focusSetSessionState,
                  shortcutIdentifier: identifier,
                  forceDoNothingOnRelease: session.forceDoNothingOnRelease,
                  shortcutStyle: Preferences.shortcutStyle(.focusSets)) {
        case .focus: focusTarget()
        case .search: TilesView.enableSearchEditing()
        case .none: break
        }
    }

    static func handleCancelShortcut() {
        guard let session = SwitcherSession.current else { return }
        let entry: SearchEntryStyle = Preferences.shortcutStyle(session.presentationSource) == .searchOnRelease ? .startedInSearch : .toggledMidSession
        switch SearchModeResolver.escape(mode: TilesView.searchMode, entry: entry) {
        case .exitSearch:
            TilesView.disableSearchMode()
        case .closeSwitcher:
            let decision = FocusSetSessionResolver.resolve(
                FocusSetSessionInput(
                    state: session.focusSetSessionState,
                    event: .escape))
            applyFocusSetDecision(decision, snapshot: session.focusSetPresentationSnapshot, session: session)
        }
    }

    static func toggleSearchMode() {
        guard SwitcherSession.isActive else { return }
        TilesView.toggleSearchModeFromShortcut()
    }

    static func handleNavigationGesture(_ direction: Direction) {
        guard FeatureFlags.gestures else { return }
        if let session = SwitcherSession.current,
           session.focusSetSessionState != .ordinaryGrid {
            showUiOrCycleSelection(Preferences.gestureIndex, false)
            return
        }
        cycleSelection(direction, allowWrap: false)
    }

    private static func applyFocusSetDecision(_ decision: FocusSetSessionDecision,
                                              snapshot: FocusSetPresentationSnapshot?,
                                              session: SwitcherSession) {
        session.focusSetSessionState = decision.nextState
        if let snapshot { updateFocusSetSession(snapshot, session: session) }
        discardInvalidChordLifecycleState(session)
        switch decision.action {
        case .showDirectFocusSetGrid:
            guard (snapshot ?? session.focusSetPresentationSnapshot) != nil else { return }
            showDirectFocusSetGrid(session: session)
        case .cycleFocusSetSelection:
            cycleSelection(.leading)
        case .showOrdinaryGrid:
            session.isFirstSummon = true
        case .dismissSwitcherUi:
            hideUi()
        case .noOp:
            break
        }
    }

    private static func discardInvalidChordLifecycleState(_ session: SwitcherSession) {
        guard let chord = session.chordLifecycleState else { return }
        switch chord.owner {
        case let .shortcut(index):
            guard session.presentationSource == .shortcut(index),
                  session.focusSetSessionState == .ordinaryGrid else {
                session.chordLifecycleState = nil
                return
            }
        case let .directFocusSet(identifier):
            guard session.focusSetSessionState.directFocusSetIdentifier == identifier else {
                session.chordLifecycleState = nil
                return
            }
        }
    }

    private static func showDirectFocusSetGrid(session: SwitcherSession) {
        KeyRepeatTimer.stopCurrentTimer()
        TilesPanel.shared.alphaValue = 0
        session.isFirstSummon = false
        TilesView.startSearchSession(false)
        if !Windows.updatesBeforeShowing() {
            hideUi()
            return
        }
        Windows.setInitialSelectedAndHoveredWindowIndex()
        buildUiAndShowPanel()
    }

    static func previousWindowShortcutWithRepeatingKey() {
        cycleSelection(.trailing)
        KeyRepeatTimer.startRepeatingKeyPreviousWindow()
    }

    static func focusSelectedWindow(_ selectedWindow: Window?) {
        guard SwitcherSession.isActive else { return } // already hidden
        hideUi()
        if let window = selectedWindow, MissionControl.state() == .inactive || MissionControl.state() == .showDesktop {
            window.focus()
            moveCursorToSelectedWindow(window)
        }
    }

    static func moveCursorToSelectedWindow(_ window: Window) {
        let referenceWindow = window.referenceWindowForTabbedWindow()
        guard let position = referenceWindow?.position, let size = referenceWindow?.size else { return }
        let point = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        CGWarpMouseCursorPosition(point)
    }

    private static func refreshFocusSetGridAfterExternalEvent(_ session: SwitcherSession) {
        let snapshot = directFocusSetSnapshot()
        updateFocusSetSession(snapshot, session: session)
        let decision = FocusSetSessionResolver.resolve(
            FocusSetSessionInput(
                state: session.focusSetSessionState,
                event: .availableFocusSetsChanged,
                availableFocusSetIdentifiers: Set(snapshot.configuration.sets.map(\.id))))
        if decision.action == .dismissSwitcherUi {
            applyFocusSetDecision(decision, snapshot: snapshot, session: session)
            return
        }
        if !Windows.updatesBeforeShowing() {
            hideUi()
            return
        }
        refreshUi(true)
    }

    static func refreshOpenUiAfterExternalEvent() {
        refreshOpenUiAfterFocusSetConfigurationChange()
    }

    static func refreshOpenUiAfterFocusSetConfigurationChange() {
        switcherUiRefreshThrottler.throttleOrProceed {
            guard let session = SwitcherSession.current else { return }
            switch session.focusSetSessionState {
            case .directFocusSetGrid:
                refreshFocusSetGridAfterExternalEvent(session)
                return
            case .idle, .ordinaryGrid:
                break
            }
            if !Windows.updatesBeforeShowing() { hideUi(); return }
            refreshUi(true)
        }
    }

    static func refreshUi(_ preserveScrollPosition: Bool = false) {
        guard SwitcherSession.current != nil else { return }
        let preservedScrollOrigin = preserveScrollPosition ? TilesView.currentScrollOrigin() : nil
        Windows.updateSelectedWindow()
        guard SwitcherSession.isActive else { return }
        TilesPanel.shared.updateContents(preservedScrollOrigin)
        guard SwitcherSession.isActive else { return }
        Windows.voiceOverWindow() // at this point TileViews are assigned to the window, and ready
        guard SwitcherSession.isActive else { return }
        Applications.refreshBadgesAsync()
    }

    static func showUiOrCycleSelection(_ shortcutIndex: Int, _ forceDoNothingOnRelease_: Bool) {
        let source = SwitcherPresentationSource.shortcut(shortcutIndex)
        let replacesFocusSetFlow = SwitcherSession.current.map { $0.focusSetSessionState != .ordinaryGrid } ?? false
        let session = SwitcherSession.current ?? {
            let new = SwitcherSession()
            SwitcherSession.current = new
            return new
        }()
        if replacesFocusSetFlow {
            let decision = FocusSetSessionResolver.resolve(
                FocusSetSessionInput(state: session.focusSetSessionState, event: .ordinaryShortcutOrGesture))
            session.focusSetSessionState = decision.nextState
            session.focusSetPresentationSnapshot = nil
            session.isFirstSummon = true
            KeyRepeatTimer.stopCurrentTimer()
        }
        session.forceDoNothingOnRelease = forceDoNothingOnRelease_
        Logger.debug { "isFirstSummon:\(session.isFirstSummon) shortcutIndex:\(shortcutIndex)" }
        UsageStats.recordTrigger(shortcutIndex)
        if session.isFirstSummon || source != session.presentationSource {
            NSScreen.updatePreferred()
            if isVeryFirstSummon {
                Windows.sortByLevel()
                isVeryFirstSummon = false
            }
            session.isFirstSummon = false
            session.presentationSource = source
            // Hide instantly so the rebuild for a different shortcut (Appearance change, layout
            // recalc) is invisible. `TilesPanel.show()` flips alpha back to 1 once everything is
            // in its final state. No-op on first summon (panel was orderOut'd with alpha=0).
            TilesPanel.shared.alphaValue = 0
            let shouldStartInSearchMode = Preferences.effectiveShortcutStyle(shortcutIndex) == .searchOnRelease
            TilesView.startSearchSession(shouldStartInSearchMode)
            if shouldStartInSearchMode {
                session.forceDoNothingOnRelease = true
            }
            if !Windows.updatesBeforeShowing() { hideUi(); return }
            Windows.setInitialSelectedAndHoveredWindowIndex()
            buildUiAndShowPanel()
        } else {
            cycleSelection(.leading)
            KeyRepeatTimer.startRepeatingKeyNextWindow()
        }
    }

    static func buildUiAndShowPanel() {
        guard SwitcherSession.isActive else { return }
        Appearance.update()
        guard SwitcherSession.isActive else { return }
        TilesView.swapBackgroundViewIfNeeded()
        guard SwitcherSession.isActive else { return }
        refreshUi()
        guard SwitcherSession.isActive else { return }
        TilesPanel.shared.show()
        if TilesView.isSearchEditing {
            TilesView.enableSearchEditing()
        }
        KeyRepeatTimer.startRepeatingKeyNextWindow()
    }

    static func checkIfShortcutsShouldBeDisabled(_ activeWindow: Window?, _ activeApp: Application?) {
        let app = activeWindow?.application ?? activeApp!
        let shortcutsShouldBeDisabled = ExceptionMatcher.disablesShortcuts(
            app.state,
            isFullscreen: activeWindow?.isFullscreen ?? false,
            exceptions: Preferences.exceptions)
        KeyboardEvents.toggleGlobalShortcuts(shortcutsShouldBeDisabled)
        if shortcutsShouldBeDisabled && SwitcherSession.isActive {
            hideUi()
        }
    }

    static func continueAppLaunchAfterPermissionsAreGranted() {
        Logger.info { "System permissions are granted; continuing launch" }
        BackgroundWork.start()
        NSScreen.updatePreferred()
        Appearance.update()
        TilesPanel.updateMaxPossibleAppIconSize()
        Menubar.initialize()
        MainMenu.create()
        _ = TilesPanel()
        Spaces.refresh()
        Screens.refresh()
        SpacesEvents.observe()
        ScreensEvents.observe()
        SystemAppearanceEvents.observe()
        SystemScrollerStyleEvents.observe()
        InputSourceEvents.observe()
        ScreenLockEvents.observe()
        SleepWakeEvents.observe()
        Applications.initialDiscovery()
        KeyboardEvents.addEventHandlers()
        CursorEvents.observe()
        TrackpadEvents.observe()
        CliEvents.observe()
        App.sparkleDelegate = SparkleDelegate()
        App.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: App.sparkleDelegate!,
            userDriverDelegate: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            App.updaterController?.startUpdater()
        }
        PreferencesEvents.initialize()
        BenchmarkRunner.startIfNeeded()
        showSettingsWindowOnFirstLaunchIfNeeded()
        if pendingShowSettingsWindow {
            pendingShowSettingsWindow = false
            showSettingsWindow()
        }
        #if DEBUG
        QAMenu.shared = QAMenu()
        QAMenu.shared?.orderFront(nil)
        if QAMenu.openSettingsOnLaunch { App.showSettingsWindow() }
        if QAMenu.graphEnabled { DebugMenu.setEnabled(true) }
        #endif
        UsageStats.prune()
        DispatchQueue.main.async { presentCrashReportConsentIfNeeded() }
        Logger.info { "Finished launching ScryTab" }
    }
}

extension App: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        App.shared.disableRelaunchOnLogin()
        Logger.initialize()
        Logger.info { "Launching ScryTab \(App.version)" }
        #if !DEBUG
        MoveToApplicationsFolder.promptIfNeeded()
        #endif
        AXUIElement.setGlobalTimeout()
        Preferences.initialize()
        App.sentryCrashReporter.startIfAllowed(policy: App.crashReportPolicy, dsn: Secrets.sentryDsn)
        BackgroundWork.preStart()
        SystemPermissions.ensurePermissionsAreGranted()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        App.showSettingsWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // symbolic hotkeys state persist after the app is quit; we restore this shortcut before quitting
        setNativeCommandTabEnabled(true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Logger.info { "" }
        return .terminateNow
    }
}

@objc(SentryCrashReporterBridge)
final class SentryCrashReporterBridge: NSObject {
    @objc(captureException:)
    static func captureException(_ exception: NSException) {
        App.captureHandledException(exception)
    }
}
