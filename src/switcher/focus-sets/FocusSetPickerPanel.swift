import Cocoa

final class FocusSetPickerPanel {
    static let shared = FocusSetPickerPanel()

    private var pickerView: FocusSetPickerView?
    private var background: EffectView?
    private var ownership = FocusSetPickerPanelOwnership.unowned

    private init() {}

    func picker() -> FocusSetPickerView? {
        pickerView
    }

    var isShowing: Bool {
        guard ownership == .owned else { return false }
        guard let background, let contentView = TilesPanel.shared.contentView else { return false }
        return background === contentView
    }

    func show(_ picker: FocusSetPickerView) {
        requireMainThread()
        remove()
        Appearance.update(style: .titles)
        picker.refreshAppearance()
        pickerView = picker
        let background = TilesView.focusSetPickerEffectView()
        background.addSubview(picker)
        self.background = background
        TilesPanel.shared.contentView = background
        TilesPanel.shared.hasCustomContent = true
        ownership = .owned
        MainMenu.toggleEditMenu(true)
        picker.activateSearchField()
        updateLayout()
    }

    func refreshAppearance() {
        requireMainThread()
        background?.updateAppearance()
        pickerView?.refreshAppearance()
    }

    func updateLayout() {
        requireMainThread()
        guard let pickerView, let background else { return }
        let size = pickerView.preferredPanelSize()
        background.frame.size = size
        pickerView.frame = NSRect(origin: .zero, size: size)
        pickerView.layoutSubtreeIfNeeded()
        TilesPanel.shared.setContentSize(size)
        NSScreen.preferred.repositionPanel(TilesPanel.shared)
        TilesPanel.shared.resetFrozenPosition()
    }

    @discardableResult
    func remove() -> Bool {
        requireMainThread()
        let decision = FocusSetPickerPresentationPolicy.remove(ownership)
        guard decision.shouldRestoreOrdinaryState else { return false }
        ownership = decision.nextOwnership
        pickerView?.detachSearchField()
        pickerView?.removeFromSuperview()
        pickerView = nil
        background = nil
        TilesPanel.shared.hasCustomContent = false
        if !TilesView.isSearchEditing {
            MainMenu.toggleEditMenu(false)
        }
        Appearance.update()
        TilesView.swapBackgroundViewIfNeeded()
        TilesPanel.shared.contentView = TilesView.contentView
        TilesPanel.shared.resetFrozenPosition()
        return true
    }

    private func requireMainThread() {
        precondition(Thread.isMainThread, "FocusSetPickerPanel must be used on the main thread.")
    }
}
