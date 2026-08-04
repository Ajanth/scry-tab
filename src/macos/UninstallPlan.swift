import Foundation

/// Pure resolution of everything ScryTab persists outside its own bundle, so the removal set can
/// be asserted without a real home directory. `Uninstaller` performs the removal.
enum UninstallPlan {
    /// Usage counters live outside the main preference domain so exporting settings doesn't carry
    /// them along. The suffix is owned here rather than in `UsageStats` so resolving the uninstall
    /// set stays free of any dependency on a loaded bundle.
    static let usageDefaultsSuiteSuffix = "usage"

    static func leftoverPaths(homeUrl: URL, bundleIdentifier: String) -> [URL] {
        let library = homeUrl.appendingPathComponent("Library", isDirectory: true)
        return [
            "LaunchAgents/\(bundleIdentifier).plist",
            "Preferences/\(bundleIdentifier).plist",
            "Preferences/\(bundleIdentifier).\(usageDefaultsSuiteSuffix).plist",
            "Caches/\(bundleIdentifier)",
            "HTTPStorages/\(bundleIdentifier)",
            "Saved Application State/\(bundleIdentifier).savedState",
        ].map { library.appendingPathComponent($0) }
    }
}
