import Cocoa

enum FocusSetsTab {
    private static weak var settingsView: FocusSetSettingsView?

    static func initTab() -> NSView {
        let view = FocusSetSettingsView(width: SettingsWindow.contentWidth)
        settingsView = view
        return view
    }

    static func refresh() {
        settingsView?.refresh()
    }

    static func cleanup() {
        settingsView = nil
    }
}
