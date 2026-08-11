import Foundation

struct UpdatePolicyConsentState {
    private static let preferenceKey = "updatePolicy"
    private static let sparklePermissionKey = "SUEnableAutomaticChecks"
    let hasStoredPreference: Bool
    let hasSparklePermissionResponse: Bool

    init(persistentDomain: [String: Any]) {
        hasStoredPreference = persistentDomain[Self.preferenceKey] != nil
        hasSparklePermissionResponse = persistentDomain[Self.sparklePermissionKey] != nil
    }

    init(defaults: UserDefaults, domainName: String) {
        self.init(persistentDomain: defaults.persistentDomain(forName: domainName) ?? [:])
    }
}
