import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

class KeyboardEvents {
    private static let signature = "altt".utf16.reduce(0) { ($0 << 8) + OSType($1) }
    // GetEventMonitorTarget/GetApplicationEventTarget also work, but require Accessibility Permission
    private static let shortcutEventTarget = GetEventDispatcherTarget()
    private static var eventHotKeyRefs = [String: EventHotKeyRef?]()
    private static var hotKeyPressedEventHandler: EventHandlerRef?
    private static var hotKeyReleasedEventHandler: EventHandlerRef?
    private static var globalShortcutsAreDisabled = false
    private static var modifierEventTap: CFMachPort?
    private static var modifierEventTapSource: CFRunLoopSource?
    private static var escapeEventTap: CFMachPort?
    private static var escapeEventTapSource: CFRunLoopSource?
    private static var currentEscapeTapToken: UInt = 0
    private static var lastEscapeTapToken: UInt = 0
    private static var escapeTapLifecycleState = KeyboardEventsTestable.EscapeTapLifecycleState.inactive
    private static var anyShortcutUsesEscape = false
    private static var localEventMonitor: Any?

    private static let modifierEventHandler: CGEventTapCallBack = { _, type, cgEvent, _ in
        switch type {
        case .flagsChanged:
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(cgEvent.flags.rawValue))
            DispatchQueue.main.async {
                handleKeyboardEvent(nil, nil, nil, modifiers, false)
            }
            return Unmanaged.passUnretained(cgEvent)
        case .tapDisabledByUserInput, .tapDisabledByTimeout:
            DispatchQueue.main.async { reEnableModifierTapIfNeeded() }
            return Unmanaged.passUnretained(cgEvent)
        default:
            return Unmanaged.passUnretained(cgEvent)
        }
    }

    private static let escapeEventHandler: CGEventTapCallBack = { _, type, cgEvent, userInfo in
        guard let callbackToken = escapeTapToken(userInfo) else {
            return Unmanaged.passUnretained(cgEvent)
        }
        switch type {
        case .keyDown:
            guard cgEvent.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape) else {
                return Unmanaged.passUnretained(cgEvent)
            }
            let modifiers = NSEvent.ModifierFlags(rawValue: UInt(cgEvent.flags.rawValue))
            let isARepeat = cgEvent.getIntegerValueField(.keyboardEventAutorepeat) != 0
            DispatchQueue.main.async {
                guard KeyboardEventsTestable.escapeTapCallbackIsCurrent(
                    callbackToken,
                    currentToken: currentEscapeTapToken) else { return }
                handleKeyboardEvent(nil, nil, UInt32(kVK_Escape), modifiers, isARepeat, nil)
            }
            return nil
        case .tapDisabledByUserInput, .tapDisabledByTimeout:
            DispatchQueue.main.async {
                guard KeyboardEventsTestable.escapeTapCallbackIsCurrent(
                    callbackToken,
                    currentToken: currentEscapeTapToken) else { return }
                handleDisabledEscapeTap()
            }
            return Unmanaged.passUnretained(cgEvent)
        default:
            return Unmanaged.passUnretained(cgEvent)
        }
    }

    static func addGlobalShortcut(_ controlId: String, _ shortcut: Shortcut) {
        addGlobalHandlerIfNeeded(shortcut)
        registerHotKeyIfNeeded(controlId, shortcut)
    }

    static func removeGlobalShortcut(_ controlId: String, _ shortcut: Shortcut) {
        unregisterHotKeyIfNeeded(controlId, shortcut)
        removeHandlerIfNeeded()
    }

    static func toggleGlobalShortcuts(_ shouldDisable: Bool) {
        if shouldDisable != globalShortcutsAreDisabled {
            let fn = shouldDisable ? unregisterHotKeyIfNeeded : registerHotKeyIfNeeded
            for shortcutId in KeyboardEventsTestable.globalShortcutsIds.keys {
                if let shortcut = ControlsTab.shortcuts[shortcutId]?.shortcut {
                    fn(shortcutId, shortcut)
                }
            }
            Logger.info { "disabled:\(shouldDisable)" }
            globalShortcutsAreDisabled = shouldDisable
        }
    }

    static func reEnableTapIfNeeded() {
        guard reEnableModifierTapIfNeeded() else { return }
        Logger.warning { "" }
    }

    @discardableResult
    private static func reEnableModifierTapIfNeeded() -> Bool {
        guard let modifierEventTap, !CGEvent.tapIsEnabled(tap: modifierEventTap) else { return false }
        CGEvent.tapEnable(tap: modifierEventTap, enable: true)
        return true
    }

    static func addEventHandlers() {
        addLocalMonitorForKeyDownAndKeyUp()
        addModifierEventTap()
    }

    static func removeEventHandlers() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        removeEscapeEventTap()
        removeModifierEventTap()
    }

    static func removeGlobalShortcutHandlers() {
        for (controlId, reference) in eventHotKeyRefs {
            guard let reference else { continue }
            let status = UnregisterEventHotKey(reference)
            if status != noErr {
                Logger.error { "UnregisterEventHotKey failed during shutdown for \(controlId) status:\(status)" }
            }
        }
        eventHotKeyRefs.removeAll()
        removeGlobalEventHandler(hotKeyPressedEventHandler, name: "pressed")
        removeGlobalEventHandler(hotKeyReleasedEventHandler, name: "released")
        hotKeyPressedEventHandler = nil
        hotKeyReleasedEventHandler = nil
        globalShortcutsAreDisabled = false
    }

    static func configureEscapeAbsorption(anyShortcutUsesEscape: Bool) {
        self.anyShortcutUsesEscape = anyShortcutUsesEscape
        applyEscapeTapLifecycle(.shortcutConfigurationChanged(anyShortcutUsesEscape: anyShortcutUsesEscape))
    }

    static func switcherSessionDidBegin() {
        removeEscapeEventTap()
        escapeTapLifecycleState = .inactive
        applyEscapeTapLifecycle(.sessionBegan(anyShortcutUsesEscape: anyShortcutUsesEscape))
    }

    static func switcherSessionDidEnd() {
        applyEscapeTapLifecycle(.sessionEnded)
        removeEscapeEventTap()
    }

    private static func unregisterHotKeyIfNeeded(_ controlId: String, _ shortcut: Shortcut) {
        if shortcut.keyCode != .none {
            let key = shortcut.carbonKeyCode
            let mods = shortcut.carbonModifierFlags
            if let ref = eventHotKeyRefs[controlId] {
                let status = UnregisterEventHotKey(ref)
                if status == noErr {
                    Logger.debug { "unregistered \(controlId) keyCode:\(key) modifiers:\(mods)" }
                } else {
                    Logger.error { "UnregisterEventHotKey failed for \(controlId) keyCode:\(key) modifiers:\(mods) status:\(status)" }
                }
                eventHotKeyRefs[controlId] = nil
            }
        }
    }

    private static func removeGlobalEventHandler(_ handler: EventHandlerRef?, name: String) {
        guard let handler else { return }
        let status = RemoveEventHandler(handler)
        if status != noErr {
            Logger.error { "RemoveEventHandler failed during shutdown for \(name) handler status:\(status)" }
        }
    }

    private static func registerHotKeyIfNeeded(_ controlId: String, _ shortcut: Shortcut) {
        if shortcut.keyCode != .none {
            guard let id = KeyboardEventsTestable.globalShortcutsIds[controlId] else { return }
            let hotkeyId = EventHotKeyID(signature: signature, id: UInt32(id))
            let key = shortcut.carbonKeyCode
            let mods = shortcut.carbonModifierFlags
            let options = UInt32(kEventHotKeyNoOptions)
            var shortcutsReference: EventHotKeyRef?
            let status = RegisterEventHotKey(key, mods, hotkeyId, shortcutEventTarget, options, &shortcutsReference)
            if status == noErr {
                Logger.debug { "registered \(controlId) keyCode:\(key) modifiers:\(mods)" }
            } else {
                Logger.error { "RegisterEventHotKey failed for \(controlId) keyCode:\(key) modifiers:\(mods) status:\(status)" }
            }
            eventHotKeyRefs[controlId] = shortcutsReference
        }
    }

    // TODO: handle this on a background thread?
    private static func addLocalMonitorForKeyDownAndKeyUp() {
        guard localEventMonitor == nil else { return }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { (event: NSEvent) in
            let keyCode = event.type == .keyDown ? UInt32(event.keyCode) : nil
            let isARepeat = event.type == .keyDown ? event.isARepeat : false
            let shouldAbsorbEvent = handleKeyboardEvent(nil, nil, keyCode, event.modifierFlags, isARepeat, event)
            return shouldAbsorbEvent ? nil : event
        }
    }

    private static func addModifierEventTap() {
        guard modifierEventTap == nil else { return }
        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: modifierEventHandler,
            userInfo: nil) else {
            SystemPermissions.handleEventTapCreationFailure("Keyboard")
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            SystemPermissions.handleEventTapCreationFailure("Keyboard")
            return
        }
        guard let runLoop = BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop else {
            CFRunLoopSourceInvalidate(source)
            CFMachPortInvalidate(tap)
            SystemPermissions.handleEventTapCreationFailure("Keyboard")
            return
        }
        modifierEventTap = tap
        modifierEventTapSource = source
        CFRunLoopAddSource(runLoop, source, .commonModes)
    }

    private static func removeModifierEventTap() {
        removeEventTap(
            &modifierEventTap,
            source: &modifierEventTapSource,
            runLoop: BackgroundWork.keyboardAndMouseAndTrackpadEventsThread?.runLoop)
    }

    private static func addEscapeEventTap() {
        guard escapeEventTap == nil else { return }
        let token = nextEscapeTapToken()
        guard let userInfo = UnsafeMutableRawPointer(bitPattern: token) else {
            applyEscapeTapLifecycle(.tapDisabled)
            return
        }
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: escapeEventHandler,
            userInfo: userInfo) else {
            applyEscapeTapLifecycle(.tapDisabled)
            Logger.error { "Keyboard Escape event tap unavailable; continuing without Escape absorption for this switcher session" }
            return
        }
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            applyEscapeTapLifecycle(.tapDisabled)
            Logger.error { "Keyboard Escape run-loop source unavailable; continuing without Escape absorption for this switcher session" }
            return
        }
        guard let runLoop = BackgroundWork.keyboardAndMouseAndTrackpadEventsThread.runLoop else {
            CFRunLoopSourceInvalidate(source)
            CFMachPortInvalidate(tap)
            applyEscapeTapLifecycle(.tapDisabled)
            Logger.error { "Keyboard Escape run loop unavailable; continuing without Escape absorption for this switcher session" }
            return
        }
        currentEscapeTapToken = token
        escapeEventTap = tap
        escapeEventTapSource = source
        CFRunLoopAddSource(runLoop, source, .commonModes)
    }

    private static func removeEscapeEventTap() {
        currentEscapeTapToken = 0
        removeEventTap(
            &escapeEventTap,
            source: &escapeEventTapSource,
            runLoop: BackgroundWork.keyboardAndMouseAndTrackpadEventsThread?.runLoop)
    }

    private static func removeEventTap(_ tap: inout CFMachPort?,
                                       source: inout CFRunLoopSource?,
                                       runLoop: CFRunLoop?) {
        if let source {
            if let runLoop { CFRunLoopRemoveSource(runLoop, source, .commonModes) }
            CFRunLoopSourceInvalidate(source)
        }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }

    private static func handleDisabledEscapeTap() {
        applyEscapeTapLifecycle(.tapDisabled)
    }

    private static func escapeTapToken(_ userInfo: UnsafeMutableRawPointer?) -> UInt? {
        guard let userInfo else { return nil }
        let token = UInt(bitPattern: userInfo)
        return token == 0 ? nil : token
    }

    private static func nextEscapeTapToken() -> UInt {
        lastEscapeTapToken &+= 1
        if lastEscapeTapToken == 0 { lastEscapeTapToken = 1 }
        return lastEscapeTapToken
    }

    private static func applyEscapeTapLifecycle(_ event: KeyboardEventsTestable.EscapeTapLifecycleEvent) {
        let decision = KeyboardEventsTestable.resolveEscapeTapLifecycle(escapeTapLifecycleState, event)
        escapeTapLifecycleState = decision.nextState
        switch decision.action {
        case .install: addEscapeEventTap()
        case .remove: removeEscapeEventTap()
        case .none: break
        }
    }

    private static func addGlobalHandlerIfNeeded(_ shortcut: Shortcut) {
        if shortcut.keyCode != .none && hotKeyPressedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))]
            InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                handleKeyboardEvent(Int(id.id), .down, nil, nil, false)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyPressedEventHandler)
        }
        if shortcut.keyCode != .none && hotKeyReleasedEventHandler == nil {
            var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))]
            InstallEventHandler(shortcutEventTarget, { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                handleKeyboardEvent(Int(id.id), .up, nil, nil, false)
                return noErr
            }, eventTypes.count, &eventTypes, nil, &hotKeyReleasedEventHandler)
        }
    }

    private static func removeHandlerIfNeeded() {
        let globalShortcuts = ControlsTab.shortcuts.values.filter { $0.scope == .global }
        if let hotKeyPressedEventHandler_ = hotKeyPressedEventHandler, let hotKeyReleasedEventHandler_ = hotKeyReleasedEventHandler,
           (globalShortcuts.allSatisfy { $0.shortcut.keyCode == .none }) {
            RemoveEventHandler(hotKeyPressedEventHandler_)
            hotKeyPressedEventHandler = nil
            RemoveEventHandler(hotKeyReleasedEventHandler_)
            hotKeyReleasedEventHandler = nil
        }
    }
}
