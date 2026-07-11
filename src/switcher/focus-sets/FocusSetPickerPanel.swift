import Cocoa

final class FocusSetPickerPanel {
    static let shared = FocusSetPickerPanel()

    private var pickerView: FocusSetPickerView?
    private var background: NSView?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?

    private init() {}

    func picker() -> FocusSetPickerView? {
        pickerView
    }

    var isShowing: Bool {
        guard let background, let contentView = TilesPanel.shared.contentView else { return false }
        return background === contentView
    }

    func show(_ picker: FocusSetPickerView) {
        requireMainThread()
        remove()
        pickerView = picker
        let content = NSView()
        let background = DesignSystemWindowContentView(content: content)
        self.background = background
        picker.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: content.topAnchor, constant: Appearance.windowPadding),
            picker.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Appearance.windowPadding),
            picker.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Appearance.windowPadding),
            picker.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Appearance.windowPadding),
        ])
        TilesPanel.shared.contentView = background
        TilesPanel.shared.hasCustomContent = true
        MainMenu.toggleEditMenu(true)
        updateLayout()
    }

    func refreshAppearance() {
        requireMainThread()
        guard let pickerView else { return }
        DesignSystemControlStyler.refreshEditableFields(in: pickerView)
    }

    func updateLayout() {
        requireMainThread()
        guard let pickerView else { return }
        heightConstraint?.isActive = false
        widthConstraint?.isActive = false
        let panelWidth = min(SheetWindow.width, NSScreen.preferred.frame.width * Appearance.maxWidthOnScreen).rounded()
        let pickerWidth = max(0, panelWidth - Appearance.windowPadding * 2)
        let separatorHeight = TableGroupView.borderWidth * CGFloat(max(0, pickerView.visibleItemCount - 1))
        let contentHeight = DesignSystem.Metrics.standardControlMinHeight * CGFloat(max(1, pickerView.visibleItemCount + 1)) + separatorHeight + DesignSystem.Metrics.headerFooterGap
        let panelHeight = min(TilesPanel.maxRowHeight(), contentHeight + Appearance.windowPadding * 2)
        let width = pickerView.widthAnchor.constraint(equalToConstant: pickerWidth)
        let height = pickerView.heightAnchor.constraint(equalToConstant: max(0, panelHeight - Appearance.windowPadding * 2))
        width.isActive = true
        height.isActive = true
        widthConstraint = width
        heightConstraint = height
        TilesPanel.shared.contentView?.layoutSubtreeIfNeeded()
        TilesPanel.shared.setContentSize(NSSize(width: panelWidth, height: panelHeight))
        NSScreen.preferred.repositionPanel(TilesPanel.shared)
        TilesPanel.shared.resetFrozenPosition()
    }

    func remove() {
        requireMainThread()
        heightConstraint?.isActive = false
        widthConstraint?.isActive = false
        heightConstraint = nil
        widthConstraint = nil
        pickerView = nil
        background = nil
        TilesPanel.shared.hasCustomContent = false
        if !TilesView.isSearchEditing {
            MainMenu.toggleEditMenu(false)
        }
        TilesPanel.shared.contentView = TilesView.contentView
        TilesPanel.shared.resetFrozenPosition()
    }

    private func requireMainThread() {
        precondition(Thread.isMainThread, "FocusSetPickerPanel must be used on the main thread.")
    }
}
