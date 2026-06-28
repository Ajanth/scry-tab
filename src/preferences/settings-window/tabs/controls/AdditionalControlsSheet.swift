import Cocoa

class AdditionalControlsSheet: SheetWindow {
    // Localized labels live here once. `searchableStrings` and `makeContentView` both reference
    // these constants so changing a string takes one edit, and search can't silently miss a row
    // because of a typo divergence between the two paths.
    private static let title = NSLocalizedString("Additional controls", comment: "")
    private static let titleMiscellaneous = NSLocalizedString("Miscellaneous", comment: "")
    private static let labelArrows = NSLocalizedString("Select windows using arrow keys", comment: "")
    private static let labelVim = NSLocalizedString("Select windows using vim keys", comment: "")
    private static let labelMouse = NSLocalizedString("Select windows on mouse hover", comment: "")
    private static let labelCursorFollow = NSLocalizedString("Cursor follows focus", comment: "")
    private static let labelTrackpad = NSLocalizedString("Trackpad haptic feedback", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        title, titleMiscellaneous,
        labelArrows, labelVim, labelMouse,
        labelCursorFollow, labelTrackpad,
    ] + CursorFollowFocus.allCases.map { $0.localizedString }

    override func makeContentView() -> NSView {
        Self.makeContentView(width: SheetWindow.width)
    }

    static func makeContentView(width: CGFloat) -> NSView {
        let arrowsSwitch = LabelAndControl.makeSwitch("arrowKeysEnabled", extraAction: ControlsTab.arrowKeysEnabledCallback)
        let vimSwitch = LabelAndControl.makeSwitch("vimKeysEnabled", extraAction: ControlsTab.vimKeysEnabledCallback)
        let mouseSwitch = LabelAndControl.makeSwitch("mouseHoverEnabled")
        let cursorDropdown = LabelAndControl.makeDropdown("cursorFollowFocus", CursorFollowFocus.allCases)
        let trackpadSwitch = LabelAndControl.makeSwitch("trackpadHapticFeedbackEnabled")
        ControlsTab.arrowKeysCheckbox = arrowsSwitch
        ControlsTab.vimKeysCheckbox = vimSwitch
        ControlsTab.arrowKeysEnabledCallback(ControlsTab.arrowKeysCheckbox)
        ControlsTab.vimKeysEnabledCallback(ControlsTab.vimKeysCheckbox)
        let form = SettingsFormView()
        let selection = SettingsSectionView(title: Self.title)
        selection.addRow(makeRow(Self.labelArrows, arrowsSwitch))
        selection.addRow(makeRow(Self.labelVim, vimSwitch))
        selection.addRow(makeRow(Self.labelMouse, mouseSwitch))
        form.addSection(selection)
        let misc = SettingsSectionView(title: Self.titleMiscellaneous)
        misc.addRow(makeRow(Self.labelCursorFollow, cursorDropdown))
        misc.addRow(makeRow(Self.labelTrackpad, trackpadSwitch))
        form.addSection(misc)
        return form
    }

    private static func makeRow(_ title: String, _ control: NSView) -> SettingsRowView {
        let row = SettingsRowView(title: title, content: [control])
        SettingsSearchIndex.registerString(title)
        SettingsSearchIndex.registerTarget(SettingsSearchHighlight.highlightTarget(row.titleLabel))
        return row
    }
}
