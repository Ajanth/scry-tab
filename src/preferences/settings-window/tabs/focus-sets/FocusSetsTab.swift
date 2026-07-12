import Cocoa

enum FocusSetsTab {
    private static weak var settingsView: FocusSetSettingsView?
    static var tabSegmentSearchableStrings = [ObjectIdentifier: [[String]]]()

    static func initTab() -> NSView {
        let view = FocusSetSettingsView(width: SettingsWindow.contentWidth)
        settingsView = view
        return view
    }

    static func refresh() {
        settingsView?.refresh()
    }

    static func registerSidebarRowsSearchContent() {
        settingsView?.registerSidebarRowsSearchContent()
    }

    static func cleanup() {
        settingsView = nil
        tabSegmentSearchableStrings.removeAll()
    }
}
