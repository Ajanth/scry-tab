import Cocoa

class ScreenLockEvents {
    static func observe() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self, selector: #selector(handleUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, suspensionBehavior: .deliverImmediately)
    }

    @objc private static func handleUnlocked() {
        Logger.info { "" }
        // a locked/idle screen can let macOS disable our event taps (kCGEventTapDisabledByTimeout); re-enable on unlock (#5723)
        SleepWakeEvents.reEnableAllTaps()
    }
}
