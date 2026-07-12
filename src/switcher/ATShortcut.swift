import Cocoa
import ShortcutRecorder

class ATShortcut {
    static var lastEventIsARepeat = false
    var shortcut: Shortcut
    var id: String
    var scope: ShortcutScope
    var triggerPhase: ShortcutTriggerPhase
    var state: ShortcutState = .up
    var index: Int?

    init(_ shortcut: Shortcut, _ id: String, _ scope: ShortcutScope, _ triggerPhase: ShortcutTriggerPhase, _ index: Int? = nil) {
        self.shortcut = shortcut
        self.id = id
        self.scope = scope
        self.triggerPhase = triggerPhase
        self.index = index
    }

    func matches(_ id: Int?, _ shortcutState: ShortcutState?, _ keyCode: UInt32?, _ modifiers: NSEvent.ModifierFlags?) -> Bool {
        if let id,
           let shortcutState,
           let shortcutId = KeyboardEventsTestable.actionIdentifier(forGlobalShortcutId: id) {
            if shortcutId == self.id {
                state = shortcutState
                if triggers(on: state) {
                    return true
                }
            }
        }
        if let modifiers {
            let modifiersMatch_ = modifiersMatch(cocoaToCarbonFlags(modifiers))
            let newState: ShortcutState = ((shortcut.keyCode == .none || keyCode == shortcut.carbonKeyCode) && modifiersMatch_) ? .down : .up
            let flipped = state != newState
            state = newState
            // state == down is unambiguous; state == up is hard to match with a particular shortcut, unless it's been flipped
            if (triggerPhase == .down && state == .down)
                || ((triggerPhase == .up || triggerPhase == .both) && state == .up && flipped)
                || (triggerPhase == .both && state == .down) {
                return true
            }
        }
        return false
    }

    private func triggers(on state: ShortcutState) -> Bool {
        triggerPhase == .both || (triggerPhase == .down && state == .down) || (triggerPhase == .up && state == .up)
    }

    private func modifiersMatch(_ modifiers: CarbonModifierFlags) -> Bool {
        let modifiersCleaned = modifiers.cleaned()
        let shortcutModifiersCleaned = shortcut.carbonModifierFlags.cleaned()
        // holdShortcut: contains at least
        if id.hasPrefix("holdShortcut") {
            return modifiersCleaned == (modifiersCleaned | shortcutModifiersCleaned)
        }
        let session = SwitcherSession.current
        // other shortcuts: contains exactly or exactly + holdShortcut modifiers
        let holdModifiersCleaned = Self.activeHoldModifiers(session)
        // nextWindowShortcut when panel is open: also match base key without holdShortcut modifiers
        if session != nil && id.hasPrefix("nextWindowShortcut") {
            let baseModifiersCleaned = shortcutModifiersCleaned & ~holdModifiersCleaned
            if modifiersCleaned == baseModifiersCleaned {
                return true
            }
        }
        return modifiersCleaned == shortcutModifiersCleaned || modifiersCleaned == (shortcutModifiersCleaned | holdModifiersCleaned)
    }

    static func activeHoldModifiers(_ session: SwitcherSession?) -> CarbonModifierFlags {
        guard let session else { return 0 }
        if let shortcutIndex = session.presentationSource.shortcutIndex {
            return ControlsTab.shortcuts[Preferences.indexToName("holdShortcut", shortcutIndex)]?.shortcut.carbonModifierFlags.cleaned() ?? 0
        }
        guard let chord = session.chordLifecycleState else { return 0 }
        switch chord.owner {
        case let .directFocusSet(identifier):
            return session.focusSetSessionState.directFocusSetIdentifier == identifier ? chord.holdModifiers.cleaned() : 0
        case .shortcut:
            return 0
        }
    }

    func shouldTrigger() -> Bool {
        let session = SwitcherSession.current
        if scope == .global {
            if triggerPhase == .both {
                return true
            }
            if triggerPhase == .down, session == nil || index == nil || index == session?.presentationSource.shortcutIndex {
                return true
            }
        }
        if scope == .local {
            if let session, index == nil || index == session.presentationSource.shortcutIndex {
                return true
            }
        }
        return false
    }

    func executeAction(_ isARepeat: Bool) {
        Logger.info { self.id }
        ATShortcut.lastEventIsARepeat = isARepeat
        ShortcutActions.execute(id)
    }

    func redundantSafetyMeasures() {
        if state == .up {
            KeyRepeatTimer.stopTimerForRepeatingKey(id)
        }
    }
}

enum ShortcutTriggerPhase {
    case down
    case up
    case both
}

enum ShortcutState {
    case down
    case up
}

enum ShortcutScope {
    case global
    case local
}

enum ShortcutChordOwner: Equatable {
    case shortcut(Int)
    case directFocusSet(UUID)
}

struct ShortcutChordLifecycleState: Equatable {
    let owner: ShortcutChordOwner
    let holdModifiers: CarbonModifierFlags
}

enum ShortcutChordLifecycleEvent: Equatable {
    case press(owner: ShortcutChordOwner, holdModifiers: CarbonModifierFlags)
    case modifiersChanged(CarbonModifierFlags)
}

enum ShortcutChordLifecycleAction: Equatable {
    case none
    case release(ShortcutChordOwner)
}

struct ShortcutChordLifecycleDecision: Equatable {
    let nextState: ShortcutChordLifecycleState?
    let action: ShortcutChordLifecycleAction
}

enum ShortcutChordLifecycleResolver {
    static func resolve(_ state: ShortcutChordLifecycleState?,
                        _ event: ShortcutChordLifecycleEvent) -> ShortcutChordLifecycleDecision {
        switch event {
        case let .press(owner, holdModifiers):
            let cleaned = holdModifiers.cleaned()
            return ShortcutChordLifecycleDecision(
                nextState: cleaned == 0 ? nil : ShortcutChordLifecycleState(owner: owner, holdModifiers: cleaned),
                action: .none)
        case let .modifiersChanged(modifiers):
            guard let state else {
                return ShortcutChordLifecycleDecision(nextState: nil, action: .none)
            }
            guard modifiers.cleaned() & state.holdModifiers == 0 else {
                return ShortcutChordLifecycleDecision(nextState: state, action: .none)
            }
            return ShortcutChordLifecycleDecision(nextState: nil, action: .release(state.owner))
        }
    }
}

extension NSEvent.ModifierFlags {
    // NSEvent.addLocalMonitorForEvents may return events with broken modifiers (e.g. [.NSEventModifierFlagOption, .NSEventModifierFlagFunction, 0x120])
    // we filter modifiers to only include valid modifiers; which doesn't include fn as we don't support it as a modifier
    func cleaned() -> Self {
        return self.intersection([.command, .shift, .option, .control, .capsLock])
    }
}

typealias CarbonModifierFlags = UInt32

extension CarbonModifierFlags {
    // cocoaToCarbonFlags may remove NSEventModifierFlagFunction
    // we filter modifiers to only include valid modifiers; which doesn't include fn as we don't support it as a modifier
    func cleaned() -> Self {
        return self & (UInt32(cmdKey) | UInt32(shiftKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(alphaLock))
    }
}
