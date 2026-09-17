import Cocoa
import Sparkle

class SparkleDelegate: NSObject, SPUUpdaterDelegate {
    /// Outcome of a Sparkle update check from the app's point of view. We collapse "no update
    /// found" and "check failed" into `.upToDate` because every caller wants the same
    /// fallthrough behavior in both cases.
    enum UpdateCheckResult {
        case updateAvailable(SUAppcastItem)
        case upToDate
    }

    /// Session-scoped cache of the most recent update-check outcome. `nil` until the first
    /// check (any kind — feedback preflight, manual Preferences click, scheduled background)
    /// completes. Memory-only by design: a fresh app launch should re-check once.
    /// Always written through the Sparkle delegate callbacks below, so even a check we
    /// initiated for one purpose populates the cache for any later caller.
    var cachedResult: UpdateCheckResult?

    /// One-shot completion handler used by callers that want to drive UI (e.g. the feedback
    /// window's spinner). Cleared as soon as it fires, so each request gets exactly one
    /// callback. The cache update is independent of this listener — even if no one's
    /// subscribed, the result still lands in `cachedResult`.
    var onNextCheckCompletion: ((UpdateCheckResult) -> Void)?

    func feedURLString(for updater: SPUUpdater) -> String? {
        return Endpoints.appcastUrl
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        store(.updateAvailable(item))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        store(.upToDate)
    }

    /// Sparkle relaunches the app without a chance to pass launch arguments, so the next launch is
    /// marked silent through a one-shot default instead. Suppressing Settings for a manual
    /// "Install and Relaunch" too is intentional: neither relaunch should surface a window.
    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: LaunchIntent.pendingSilentLaunchKey)
        if !defaults.synchronize() {
            Logger.error { "Couldn't flush the Sparkle silent-launch marker; the relaunch may open Settings" }
        }
    }

    private func store(_ result: UpdateCheckResult) {
        cachedResult = result
        let cb = onNextCheckCompletion
        onNextCheckCompletion = nil
        cb?(result)
    }
}
