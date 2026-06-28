import Cocoa

/// Single source of truth for control-granularity search focus across migrated Settings pages.
///
/// Each migrated `SettingsRowView` registers itself under a stable, descriptor-aligned anchor
/// identifier (e.g. `"general-startAtLogin"`). Search descriptors use the same identifier as
/// their `id`, so selecting a result lets `SettingsWindow` resolve the anchor view, scroll it
/// into view, apply a temporary semantic highlight, and focus its focal control when one exists.
///
/// Anchor identifiers are globally unique and self-describing (`"<page>-<control>"`), so the
/// registry never retains an `NSView` keyed by anything but the descriptor id — there is no
/// ambiguity when two pages register overlapping control names.
final class SettingsFocusRegistry {
    static let shared = SettingsFocusRegistry()
    private var anchors = [String: WeakBox]()

    private init() {}

    func register(_ id: String, _ view: NSView) {
        anchors[id] = WeakBox(view)
    }

    func unregister(_ id: String) {
        anchors.removeValue(forKey: id)
    }

    func unregisterPrefix(_ prefix: String) {
        anchors = anchors.filter { !$0.key.hasPrefix(prefix) }
    }

    func view(for id: String) -> NSView? {
        anchors[id]?.view
    }

    func clear() {
        anchors.removeAll()
    }

    private final class WeakBox {
        weak var view: NSView?
        init(_ view: NSView) { self.view = view }
    }
}

enum SettingsFocusAnchorID {
    static let controlsGesture = "controls-gesture"
    static let controlsActive = "controls-active"
    static let controlsNavigationPointer = "controls-navigation-pointer"
    static let exceptions = "exceptions"

    static func shortcut(_ id: String) -> String {
        "shortcut-\(id)"
    }

    static func exception(_ bundleIdentifier: String) -> String {
        "exception-\(bundleIdentifier)"
    }
}

extension SettingsRowView {
    /// Stable identifier shared with the matching `SettingsSearchDescriptor`. Registering the row
    /// through this setter links the descriptor to the live row view so search-result routing can
    /// scroll, highlight, and focus it.
    func registerFocusAnchor(_ id: String, focalControl: NSView? = nil) {
        anchorIdentifier = id
        self.focalControl = focalControl
        SettingsFocusRegistry.shared.register(id, self)
    }
}
