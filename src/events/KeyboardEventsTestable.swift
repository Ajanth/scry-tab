import ShortcutRecorder

class KeyboardEventsTestable {
    private static let fixedGlobalShortcutIds: [String: Int] = {
        var ids = [String: Int]()
        (0..<Preferences.maxShortcutCount).forEach { ids[Preferences.indexToName("nextWindowShortcut", $0)] = $0 }
        (0..<Preferences.maxShortcutCount).forEach {
            ids[Preferences.indexToName("holdShortcut", $0)] = Preferences.maxShortcutCount + $0
        }
        ids["openFocusSetsShortcut"] = 2 * Preferences.maxShortcutCount
        return ids
    }()
    private static var dynamicGlobalShortcutIds = [String: Int]()
    private static var resolvedGlobalShortcutIds = fixedGlobalShortcutIds
    private static var actionIdentifierByGlobalShortcutId = Dictionary(
        uniqueKeysWithValues: fixedGlobalShortcutIds.map { ($0.value, $0.key) })
    private static var nextDynamicGlobalShortcutId = 2 * Preferences.maxShortcutCount + 1

    static var globalShortcutsIds: [String: Int] {
        resolvedGlobalShortcutIds
    }

    static func actionIdentifier(forGlobalShortcutId identifier: Int) -> String? {
        actionIdentifierByGlobalShortcutId[identifier]
    }

    static func reconcileDynamicGlobalShortcutIds(_ actionIdentifiers: [String]) {
        let desired = Set(actionIdentifiers)
        dynamicGlobalShortcutIds = dynamicGlobalShortcutIds.filter { desired.contains($0.key) }
        for actionIdentifier in desired.sorted() where dynamicGlobalShortcutIds[actionIdentifier] == nil {
            dynamicGlobalShortcutIds[actionIdentifier] = nextDynamicGlobalShortcutId
            nextDynamicGlobalShortcutId += 1
        }
        resolvedGlobalShortcutIds = fixedGlobalShortcutIds
        resolvedGlobalShortcutIds.merge(dynamicGlobalShortcutIds) { current, _ in current }
        actionIdentifierByGlobalShortcutId = Dictionary(
            uniqueKeysWithValues: resolvedGlobalShortcutIds.map { ($0.value, $0.key) })
    }
}

@discardableResult
func handleKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool, _ event: NSEvent? = nil) -> Bool {
    if let handled = handleFocusSetPickerKeyboardEvent(globalId, shortcutState, keyCode, modifiers, isARepeat, event) {
        return handled
    }
    if let event, shouldAbsorbSearchEditingKeyDown(event) {
        switch TilesView.handleSearchEditingKeyDown(event) {
        case .handled: return true
        case .passToField: return false
        case .passToShortcuts: break
        }
    }
    logKeyboardEvent(globalId, shortcutState, keyCode, modifiers, isARepeat)
    let someShortcutTriggered = triggerMatchingShortcuts(globalId, shortcutState, keyCode, modifiers, isARepeat)
    return someShortcutTriggered
}

private func handleFocusSetPickerKeyboardEvent(_ globalId: Int?,
                                               _ shortcutState: ShortcutState?,
                                               _ keyCode: UInt32?,
                                               _ modifiers: NSEvent.ModifierFlags?,
                                               _ isARepeat: Bool,
                                               _ event: NSEvent?) -> Bool? {
    guard SwitcherSession.current?.focusSetSessionState == .picker,
          TilesPanel.shared.isKeyWindow else { return nil }
    guard let event else {
        return globalId == nil && shortcutState == nil && keyCode == nil && modifiers != nil ? false : nil
    }
    guard event.type == .keyDown || event.type == .keyUp else { return nil }
    if event.type == .keyDown, FocusSetPickerPanel.shared.picker()?.hasMarkedText() == true { return false }
    if handleFocusSetPickerActionShortcut(event, isARepeat) { return true }
    return handleFocusSetPickerVimKeyEvent(event, isARepeat) ?? false
}

private func handleFocusSetPickerActionShortcut(_ event: NSEvent, _ isARepeat: Bool) -> Bool {
    let keyCode = event.type == .keyDown ? UInt32(event.keyCode) : nil
    for id in ["cancelShortcut"] {
        guard let shortcut = ControlsTab.shortcuts[id] else { continue }
        let matches = shortcut.matches(nil, nil, keyCode, event.modifierFlags)
        guard matches, shortcut.shouldTrigger() else {
            shortcut.redundantSafetyMeasures()
            continue
        }
        shortcut.executeAction(isARepeat)
        shortcut.redundantSafetyMeasures()
        return true
    }
    return false
}

private func handleFocusSetPickerVimKeyEvent(_ event: NSEvent, _ isARepeat: Bool) -> Bool? {
    guard let vimShortcut = focusSetPickerVimShortcut(for: event) else { return nil }
    if event.type == .keyDown, vimShortcut.shouldTrigger() {
        vimShortcut.state = .down
        vimShortcut.executeAction(isARepeat)
        return true
    }
    if event.type == .keyUp {
        vimShortcut.state = .up
        return false
    }
    return nil
}

private func focusSetPickerVimShortcut(for event: NSEvent) -> ATShortcut? {
    guard SwitcherSession.current?.focusSetSessionState == .picker,
          TilesPanel.shared.isKeyWindow,
          event.type == .keyDown || event.type == .keyUp,
          event.modifierFlags.cleaned().isEmpty else { return nil }
    let keyCode = UInt32(event.keyCode)
    return ControlsTab.shortcuts.values.first {
        $0.id.starts(with: "vimCycle") &&
        $0.scope == .local &&
        $0.triggerPhase == .down &&
        $0.shortcut.carbonModifierFlags.cleaned() == 0 &&
        $0.shortcut.carbonKeyCode == keyCode
    }
}

extension KeyboardEventsTestable {
    static func shouldAbsorbEscapeAtHidTap(anyShortcutUsesEscape: Bool,
                                           sessionState: FocusSetSessionState?) -> Bool {
        anyShortcutUsesEscape && sessionState != nil && sessionState != .picker
    }
}

private func logKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool) {
    if let globalId, let shortcutState {
        Logger.debug {
            let shortcut = KeyboardEventsTestable.actionIdentifier(forGlobalShortcutId: globalId)
            return "globalShortcut:\(shortcut ?? "") state:\(shortcutState)"
        }
        return
    }
    // TODO: use proper pattern from SwiftBeaver to not compute SymbolicModifierFlagsTransformer when logs are off
    Logger.debug {
        let modifiersAsString = modifiers.flatMap { SymbolicModifierFlagsTransformer.shared.transformedValue(NSNumber(value: $0.rawValue)) }
        let keyCodeAsString = keyCode.flatMap { SymbolicKeyCodeTransformer.shared.transformedValue(NSNumber(value: $0)) }
        return "keys:\(modifiersAsString ?? "")\(keyCodeAsString ?? "") isARepeat:\(isARepeat)"
    }
}

private func shouldAbsorbSearchEditingKeyDown(_ event: NSEvent?) -> Bool {
    guard let event, event.type == .keyDown, SwitcherSession.isActive, TilesPanel.shared.isKeyWindow, TilesView.isSearchEditing else {
        return false
    }
    return true
}

private func triggerMatchingShortcuts(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool) -> Bool {
    if let globalId {
        guard let actionIdentifier = KeyboardEventsTestable.actionIdentifier(forGlobalShortcutId: globalId),
              let shortcut = ControlsTab.shortcuts[actionIdentifier] else { return false }
        let shouldAbsorb = triggerShortcut(shortcut, globalId, shortcutState, keyCode, modifiers, isARepeat)
        applyActiveHoldReleaseSafety(afterDispatching: actionIdentifier)
        return shouldAbsorb
    }
    var someShortcutTriggered = false
    for shortcut in ControlsTab.shortcuts.values {
        someShortcutTriggered = triggerShortcut(
            shortcut,
            globalId,
            shortcutState,
            keyCode,
            modifiers,
            isARepeat) || someShortcutTriggered
    }
    // TODO if we manage to move all keyboard listening to the background thread, we'll have issues returning this boolean
    // this function uses many objects that are also used on the main-thread. It also executes the actions
    // we'll have to rework this whole approach. Today we rely on somewhat in-order events/actions
    // special attention should be given to SwitcherSession.current which is being set when executing the nextWindowShortcut action
    return someShortcutTriggered
}

private func applyActiveHoldReleaseSafety(afterDispatching actionIdentifier: String) {
    guard actionIdentifier.hasPrefix("nextWindowShortcut"),
          let session = SwitcherSession.current,
          let holdShortcut = ControlsTab.shortcuts[
              Preferences.indexToName("holdShortcut", session.shortcutIndex)
          ] else { return }
    holdShortcut.redundantSafetyMeasures()
}

private func triggerShortcut(_ shortcut: ATShortcut,
                             _ globalId: Int?,
                             _ shortcutState: ShortcutState?,
                             _ keyCode: UInt32?,
                             _ modifiers: NSEvent.ModifierFlags?,
                             _ isARepeat: Bool) -> Bool {
    var shouldAbsorb = false
    if shortcut.matches(globalId, shortcutState, keyCode, modifiers) && shortcut.shouldTrigger() {
        shortcut.executeAction(isARepeat)
        shouldAbsorb = !shortcut.id.starts(with: "holdShortcut")
    }
    shortcut.redundantSafetyMeasures()
    return shouldAbsorb
}
