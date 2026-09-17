import Foundation

/// Why ScryTab was launched, which decides whether a launch may surface a window by itself.
/// Dependency-free so argument precedence is pinned without a running NSApplication.
enum LaunchIntent: Equatable {
    case userInitiated
    case silent

    /// Carried by the launches that must not surface Settings on their own and can take arguments:
    /// the login item and an internal restart. Sparkle's relaunch cannot, so it uses the marker
    /// below, and benchmarks are recognized through `--benchmark` instead.
    static let silentArgument = "--scrytab-silent-launch"

    /// One-shot handoff for Sparkle's relaunch. Not a preference: it stays outside the registry,
    /// import/export, and reset, and the caller reads and removes it.
    static let pendingSilentLaunchKey = "scrytab.pendingSilentLaunch"

    /// `BenchmarkConfig` reads this flag plus a following value, so it is matched exactly.
    private static let benchmarkArgument = "--benchmark"
    private static let silentArguments = [silentArgument, benchmarkArgument]

    static func resolve(arguments: [String], pendingSilentLaunch: Bool) -> LaunchIntent {
        guard !pendingSilentLaunch else { return .silent }
        return arguments.contains(where: silentArguments.contains) ? .silent : .userInitiated
    }
}
