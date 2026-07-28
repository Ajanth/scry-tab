import ShortcutRecorder

class KeyboardEventsTestable {
    enum EscapeTapLifecycleState: Equatable {
        case inactive
        case activeWithoutTap
        case installed
        case failedForSession
    }

    enum EscapeTapLifecycleEvent {
        case sessionBegan(anyShortcutUsesEscape: Bool)
        case shortcutConfigurationChanged(anyShortcutUsesEscape: Bool)
        case tapDisabled
        case sessionEnded
    }

    enum EscapeTapLifecycleAction: Equatable {
        case none
        case install
        case remove
    }

    struct EscapeTapLifecycleDecision: Equatable {
        let nextState: EscapeTapLifecycleState
        let action: EscapeTapLifecycleAction
    }

    private static let fixedGlobalShortcutIds: [String: Int] = {
        var ids = [String: Int]()
        (0..<Preferences.maxShortcutCount).forEach { ids[Preferences.indexToName("nextWindowShortcut", $0)] = $0 }
        (0..<Preferences.maxShortcutCount).forEach {
            ids[Preferences.indexToName("holdShortcut", $0)] = Preferences.maxShortcutCount + $0
        }
        return ids
    }()
    private static var dynamicGlobalShortcutIds = [String: Int]()
    private static var resolvedGlobalShortcutIds = fixedGlobalShortcutIds
    private static var actionIdentifierByGlobalShortcutId = Dictionary(
        uniqueKeysWithValues: fixedGlobalShortcutIds.map { ($0.value, $0.key) })
    private static var nextDynamicGlobalShortcutId = 2 * Preferences.maxShortcutCount

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

    static func escapeTapCallbackIsCurrent(_ callbackToken: UInt, currentToken: UInt) -> Bool {
        callbackToken != 0 && callbackToken == currentToken
    }

    static func shouldRestoreNativeSymbolicHotkeys(ownsAdmission: Bool,
                                                    keyboardStateWasConfigured: Bool) -> Bool {
        ownsAdmission && keyboardStateWasConfigured
    }

    static func resolveEscapeTapLifecycle(_ state: EscapeTapLifecycleState,
                                          _ event: EscapeTapLifecycleEvent) -> EscapeTapLifecycleDecision {
        switch event {
        case let .sessionBegan(anyShortcutUsesEscape):
            return anyShortcutUsesEscape
                ? EscapeTapLifecycleDecision(nextState: .installed, action: .install)
                : EscapeTapLifecycleDecision(nextState: .activeWithoutTap, action: .none)
        case let .shortcutConfigurationChanged(anyShortcutUsesEscape):
            switch state {
            case .inactive, .failedForSession:
                return EscapeTapLifecycleDecision(nextState: state, action: .none)
            case .activeWithoutTap:
                return anyShortcutUsesEscape
                    ? EscapeTapLifecycleDecision(nextState: .installed, action: .install)
                    : EscapeTapLifecycleDecision(nextState: state, action: .none)
            case .installed:
                return anyShortcutUsesEscape
                    ? EscapeTapLifecycleDecision(nextState: state, action: .none)
                    : EscapeTapLifecycleDecision(nextState: .activeWithoutTap, action: .remove)
            }
        case .tapDisabled:
            guard state == .installed else {
                return EscapeTapLifecycleDecision(nextState: state, action: .none)
            }
            return EscapeTapLifecycleDecision(nextState: .failedForSession, action: .remove)
        case .sessionEnded:
            return EscapeTapLifecycleDecision(
                nextState: .inactive,
                action: state == .installed ? .remove : .none)
        }
    }
}

@discardableResult
func handleKeyboardEvent(_ globalId: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?, _ isARepeat: Bool, _ event: NSEvent? = nil) -> Bool {
    applyChordReleaseIfNeeded(shortcutState, modifiers)
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

private func applyChordReleaseIfNeeded(_ shortcutState: ShortcutState?,
                                       _ modifiers: NSEvent.ModifierFlags?) {
    guard modifiers != nil || shortcutState == .up,
          let session = SwitcherSession.current else { return }
    let modifierFlags = cocoaToCarbonFlags(modifiers ?? ModifierFlags.current)
    let decision = ShortcutChordLifecycleResolver.resolve(
        session.chordLifecycleState,
        .modifiersChanged(modifierFlags))
    session.chordLifecycleState = decision.nextState
    guard case let .release(owner) = decision.action else { return }
    switch owner {
    case let .shortcut(index):
        guard session.presentationSource == .shortcut(index),
              session.focusSetSessionState == .ordinaryGrid,
              !session.forceDoNothingOnRelease,
              Preferences.effectiveShortcutStyle(index) == .focusOnRelease else { return }
        ShortcutActions.execute(Preferences.indexToName("holdShortcut", index))
    case let .directFocusSet(identifier):
        App.handleDirectFocusSetChordRelease(identifier)
    }
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
        armChordAfterExecuting(shortcut)
        shouldAbsorb = !shortcut.id.starts(with: "holdShortcut")
    }
    shortcut.redundantSafetyMeasures()
    return shouldAbsorb
}

private func armChordAfterExecuting(_ shortcut: ATShortcut) {
    guard shortcut.state == .down, let session = SwitcherSession.current else { return }
    if shortcut.id.hasPrefix("nextWindowShortcut") {
        let index = Preferences.nameToIndex(shortcut.id)
        guard session.presentationSource == .shortcut(index),
              session.focusSetSessionState == .ordinaryGrid,
              let holdShortcut = ControlsTab.shortcuts[Preferences.indexToName("holdShortcut", index)] else { return }
        session.chordLifecycleState = ShortcutChordLifecycleResolver.resolve(
            session.chordLifecycleState,
            .press(owner: .shortcut(index), holdModifiers: holdShortcut.shortcut.carbonModifierFlags)
        ).nextState
        return
    }
    guard let identifier = FocusSetShortcutBindingResolver.focusSetIdentifier(from: shortcut.id) else { return }
    guard session.focusSetSessionState.directFocusSetIdentifier == identifier else {
        session.chordLifecycleState = nil
        return
    }
    session.chordLifecycleState = ShortcutChordLifecycleResolver.resolve(
        session.chordLifecycleState,
        .press(owner: .directFocusSet(identifier), holdModifiers: shortcut.shortcut.carbonModifierFlags)
    ).nextState
}
