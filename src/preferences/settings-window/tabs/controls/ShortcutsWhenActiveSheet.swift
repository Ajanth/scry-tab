import Cocoa
import ShortcutRecorder

class ShortcutsWhenActiveSheet: SheetWindow {
    private static let title = NSLocalizedString("Shortcuts When Active", comment: "")
    // Row titles come from `ControlsTab.staticShortcutLabels` (single source of truth, also used by
    // the conflict dialog to name these actions).
    private static let labelFocus = ControlsTab.staticShortcutLabels["focusWindowShortcut"]!
    private static let labelPrevious = ControlsTab.staticShortcutLabels["previousWindowShortcut"]!
    private static let labelCancel = ControlsTab.staticShortcutLabels["cancelShortcut"]!
    private static let labelSearch = ControlsTab.staticShortcutLabels["searchShortcut"]!
    private static let labelLockSearch = ControlsTab.staticShortcutLabels["lockSearchShortcut"]!
    private static let labelClose = ControlsTab.staticShortcutLabels["closeWindowShortcut"]!
    private static let labelMinDemin = ControlsTab.staticShortcutLabels["minDeminWindowShortcut"]!
    private static let labelFullscreen = ControlsTab.staticShortcutLabels["toggleFullscreenWindowShortcut"]!
    private static let labelQuit = ControlsTab.staticShortcutLabels["quitAppShortcut"]!
    private static let labelHideShow = ControlsTab.staticShortcutLabels["hideShowAppShortcut"]!

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        title,
        labelFocus, labelPrevious, labelCancel,
        labelSearch, labelLockSearch,
        labelClose, labelMinDemin, labelFullscreen, labelQuit, labelHideShow,
    ]

    override func makeContentView() -> NSView {
        Self.makeContentView(width: SheetWindow.width)
    }

    static func makeContentView(width: CGFloat) -> NSView {
        let section = SettingsSectionView(title: Self.title)
        section.addRow(makeRecorderRow(Self.labelFocus, "focusWindowShortcut", Preferences.focusWindowShortcut))
        section.addRow(makeRecorderRow(Self.labelPrevious, "previousWindowShortcut", Preferences.previousWindowShortcut))
        section.addRow(makeRecorderRow(Self.labelCancel, "cancelShortcut", Preferences.cancelShortcut))
        section.addRow(makeRecorderRow(Self.labelSearch, "searchShortcut", Preferences.searchShortcut))
        section.addRow(makeRecorderRow(Self.labelLockSearch, "lockSearchShortcut", Preferences.lockSearchShortcut))
        section.addRow(makeRecorderRow(Self.labelClose, "closeWindowShortcut", Preferences.closeWindowShortcut))
        section.addRow(makeRecorderRow(Self.labelMinDemin, "minDeminWindowShortcut", Preferences.minDeminWindowShortcut))
        section.addRow(makeRecorderRow(Self.labelFullscreen, "toggleFullscreenWindowShortcut", Preferences.toggleFullscreenWindowShortcut))
        section.addRow(makeRecorderRow(Self.labelQuit, "quitAppShortcut", Preferences.quitAppShortcut))
        section.addRow(makeRecorderRow(Self.labelHideShow, "hideShowAppShortcut", Preferences.hideShowAppShortcut))
        let form = SettingsFormView()
        form.addSection(section)
        return form
    }

    private static func makeRecorderRow(_ title: String, _ rawName: String, _ shortcut: Shortcut?) -> SettingsRowView {
        let recorder = LabelAndControl.makeLabelWithRecorder(title, rawName, shortcut, labelPosition: .right)[0]
        let row = SettingsRowView(title: title, content: [recorder])
        SettingsSearchIndex.registerString(title)
        SettingsSearchIndex.registerTarget(SettingsSearchHighlight.highlightTarget(row.titleLabel))
        return row
    }

}
