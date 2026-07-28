import Cocoa

final class AccessibilitySettingsGuide {
    static let shared = AccessibilitySettingsGuide()
    static let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    private var overlayController: AccessibilityGuideOverlayController?
    private var trackingTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var sourceFrameInScreen: CGRect?
    private var isSessionActive = false
    private var didPresentOverlay = false
    private var consecutiveMisses = 0

    func begin(sourceFrameInScreen: CGRect? = nil) {
        dismiss()
        isSessionActive = true
        consecutiveMisses = 0
        self.sourceFrameInScreen = sourceFrameInScreen
        NSWorkspace.shared.open(Self.accessibilitySettingsURL)
        startTracking()
    }

    func dismiss() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        overlayController?.close()
        overlayController = nil
        sourceFrameInScreen = nil
        isSessionActive = false
        didPresentOverlay = false
        consecutiveMisses = 0
    }

    private func startTracking() {
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.refreshPosition()
        }
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleApplicationActivation(notification)
        }
        refreshPosition()
    }

    private func handleApplicationActivation(_ notification: Notification) {
        refreshPosition()
        guard isSessionActive else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        guard app.processIdentifier == NSRunningApplication.current.processIdentifier else { return }
        PermissionsWindow.shared?.makeKeyAndOrderFront(nil)
    }

    private func refreshPosition() {
        guard isSessionActive else { return }
        let result = AccessibilitySettingsGuideTracking.tick(
            settingsPresent: SystemSettingsWindowLocator.onScreenWindow() != nil,
            didPresentOverlay: didPresentOverlay,
            consecutiveMisses: consecutiveMisses)
        switch result {
        case .trackSettings:
            consecutiveMisses = 0
            guard let snapshot = SystemSettingsWindowLocator.frontmostWindow() else {
                overlayController?.hide()
                return
            }
            let controller = ensureOverlayController()
            if didPresentOverlay {
                controller.updatePosition(settingsFrame: snapshot.frame, visibleFrame: snapshot.visibleFrame)
                return
            }
            controller.present(
                settingsFrame: snapshot.frame,
                visibleFrame: snapshot.visibleFrame,
                from: sourceFrameInScreen,
                animated: true)
            didPresentOverlay = true
            sourceFrameInScreen = nil
        case .awaitSettings(let missCount):
            consecutiveMisses = missCount
        case .hideOverlay(let missCount):
            consecutiveMisses = missCount
            overlayController?.hide()
        case .endSession:
            handleGuideDone()
        }
    }

    private func ensureOverlayController() -> AccessibilityGuideOverlayController {
        if let overlayController { return overlayController }
        let controller = AccessibilityGuideOverlayController { [weak self] in
            self?.handleGuideDone()
        }
        overlayController = controller
        return controller
    }

    private func handleGuideDone() {
        dismiss()
        SystemPermissions.recheckNow()
        guard AccessibilityPermission.update() != .granted else { return }
        App.shared.activate(ignoringOtherApps: true)
        PermissionsWindow.shared?.makeKeyAndOrderFront(nil)
    }
}
