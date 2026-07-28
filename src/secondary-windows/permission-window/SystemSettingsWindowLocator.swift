import Cocoa

struct SystemSettingsWindowSnapshot: Equatable {
    let pid: pid_t
    let frame: CGRect
    let visibleFrame: CGRect
}

enum SystemSettingsWindowLocator {
    static let bundleIdentifier = "com.apple.systempreferences"

    static func frontmostWindow() -> SystemSettingsWindowSnapshot? {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier else { return nil }
        return onScreenWindow()
    }

    static func onScreenWindow() -> SystemSettingsWindowSnapshot? {
        guard let app = preferredRunningApplication() else { return nil }
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let windows = windowInfo.compactMap { snapshot(from: $0, ownerPID: app.processIdentifier) }
        return windows.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
    }

    private static func preferredRunningApplication() -> NSRunningApplication? {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .max(by: { ($0.activationPolicy == .prohibited ? 0 : 1) < ($1.activationPolicy == .prohibited ? 0 : 1) })
    }

    private static func snapshot(from info: [String: Any], ownerPID: pid_t) -> SystemSettingsWindowSnapshot? {
        guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == ownerPID else { return nil }
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
        guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        let cgFrame = CGRect(
            x: bounds["X"] ?? 0,
            y: bounds["Y"] ?? 0,
            width: bounds["Width"] ?? 0,
            height: bounds["Height"] ?? 0)
        let converted = SystemSettingsWindowGeometry.appKitGeometry(from: cgFrame, screens: screenDescriptors())
        guard SystemSettingsWindowGeometry.isEligibleSettingsWindowFrame(converted.frame) else { return nil }
        return SystemSettingsWindowSnapshot(pid: pid, frame: converted.frame, visibleFrame: converted.visibleFrame)
    }

    private static func screenDescriptors() -> [SystemSettingsScreenDescriptor] {
        let descriptors = NSScreen.screens.compactMap { descriptor(for: $0) }
        guard let main = NSScreen.main.flatMap(descriptor(for:)),
              let mainIndex = descriptors.firstIndex(where: {
                  $0.frame == main.frame && $0.cgBounds == main.cgBounds
              }) else {
            return descriptors
        }
        var ordered = descriptors
        ordered.remove(at: mainIndex)
        ordered.insert(main, at: 0)
        return ordered
    }

    private static func descriptor(for screen: NSScreen) -> SystemSettingsScreenDescriptor? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        return SystemSettingsScreenDescriptor(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            cgBounds: CGDisplayBounds(displayID))
    }
}
