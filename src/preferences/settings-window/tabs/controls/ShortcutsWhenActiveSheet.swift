import Cocoa

class ShortcutsWhenActiveSheet: SheetWindow {
    private static let title = NSLocalizedString("Shortcuts When Active", comment: "")
    // Row titles come from `ControlsTab.staticShortcutLabels` (single source of truth, also used by
    // the conflict dialog to name these actions).
    private static let labelFocus = ControlsTab.staticShortcutLabels["focusWindowShortcut"]!
    private static let labelPrevious = ControlsTab.staticShortcutLabels["previousWindowShortcut"]!
    private static let labelCancel = ControlsTab.staticShortcutLabels["cancelShortcut"]!
    private static let labelSearch = ControlsTab.staticShortcutLabels["searchShortcut"]!
    private static let labelClose = ControlsTab.staticShortcutLabels["closeWindowShortcut"]!

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        title,
        labelFocus, labelPrevious, labelCancel,
        labelSearch, labelClose,
    ]

    override func makeContentView() -> NSView {
        Self.makeContentView(width: SheetWindow.width)
    }

    static func makeContentView(width: CGFloat) -> NSView {
        let focusWindowShortcut = TableGroupView.Row(leftTitle: Self.labelFocus,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelFocus, "focusWindowShortcut", Preferences.focusWindowShortcut, labelPosition: .right)[0]])
        let previousWindowShortcut = TableGroupView.Row(leftTitle: Self.labelPrevious,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelPrevious, "previousWindowShortcut", Preferences.previousWindowShortcut, labelPosition: .right)[0]])
        let cancelShortcut = TableGroupView.Row(leftTitle: Self.labelCancel,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelCancel, "cancelShortcut", Preferences.cancelShortcut, labelPosition: .right)[0]])
        let closeWindowShortcut = TableGroupView.Row(leftTitle: Self.labelClose,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelClose, "closeWindowShortcut", Preferences.closeWindowShortcut, labelPosition: .right)[0]])
        let table = TableGroupView(title: Self.title, width: width)
        _ = table.addRow(focusWindowShortcut)
        _ = table.addRow(previousWindowShortcut)
        _ = table.addRow(cancelShortcut)
        _ = table.addRow(leftText: Self.labelSearch,
            rightViews: [LabelAndControl.makeLabelWithRecorder(Self.labelSearch, "searchShortcut", Preferences.searchShortcut, labelPosition: .right)[0]])
        _ = table.addRow(closeWindowShortcut)
        return table
    }

}
