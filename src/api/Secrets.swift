import Foundation

// Values are substituted into Info.plist from xcconfig at build time.
// Defaults: config/base.xcconfig. Per-dev or CI overrides: config/local.xcconfig.
enum Secrets {
    static var sentryDsn: String? {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String else { return nil }
        guard !dsn.isEmpty, !dsn.hasPrefix("$(") else { return nil }
        return dsn
    }
}
