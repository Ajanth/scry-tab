import Cocoa

struct ShortcutAction {
    let id: String
    let perform: () -> Void
}

enum ShortcutActions {
    static let all: [ShortcutAction] = [
        ShortcutAction(id: "focusWindowShortcut", perform: { App.focusTarget() }),
        ShortcutAction(id: "openFocusSetsShortcut", perform: { App.showFocusSetPicker() }),
        ShortcutAction(id: "previousWindowShortcut", perform: { App.previousWindowShortcutWithRepeatingKey() }),
        ShortcutAction(id: "→", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "←", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "↑", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "↓", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "vimCycleRight", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "vimCycleLeft", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "vimCycleUp", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "vimCycleDown", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "cancelShortcut", perform: { App.handleCancelShortcut() }),
        ShortcutAction(id: "closeWindowShortcut", perform: { selectedWindowForShortcutAction()?.close() }),
        ShortcutAction(id: "minDeminWindowShortcut", perform: { selectedWindowForShortcutAction()?.minDemin() }),
        ShortcutAction(id: "toggleFullscreenWindowShortcut", perform: { selectedWindowForShortcutAction()?.toggleFullscreen() }),
        ShortcutAction(id: "quitAppShortcut", perform: { selectedWindowForShortcutAction()?.application.quit() }),
        ShortcutAction(id: "hideShowAppShortcut", perform: { selectedWindowForShortcutAction()?.application.hideOrShow() }),
        ShortcutAction(id: "searchShortcut", perform: { App.toggleSearchMode() }),
        ShortcutAction(id: "lockSearchShortcut", perform: {
            guard SwitcherSession.isActive, TilesView.isSearchModeOn else { return }
            TilesView.lockSearchMode()
        }),
    ]

    private static let byId: [String: ShortcutAction] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func find(_ id: String) -> ShortcutAction? {
        byId[id]
    }

    static func execute(_ id: String) {
        if let action = find(id) {
            action.perform()
            return
        }
        if id.hasPrefix("holdShortcut") {
            guard SwitcherSession.current?.focusSetSessionState != .picker else { return }
            App.focusTarget()
            return
        }
        if id.hasPrefix("nextWindowShortcut") {
            App.showUiOrCycleSelection(Preferences.nameToIndex(id), false)
        }
    }

    private static func selectedWindowForShortcutAction() -> Window? {
        guard SwitcherSession.current?.focusSetSessionState != .picker else { return nil }
        return Windows.selectedWindow()
    }
}
