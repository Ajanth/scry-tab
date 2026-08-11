import XCTest

final class UpdatePolicyConsentStateTests: XCTestCase {
    func testFreshDomainHasNoStoredChoices() {
        let state = UpdatePolicyConsentState(persistentDomain: [:])
        XCTAssertFalse(state.hasStoredPreference)
        XCTAssertFalse(state.hasSparklePermissionResponse)
    }

    func testRegisteredDefaultsDoNotCountAsStoredChoices() {
        let domainName = "test-update-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domainName)!
        defer { defaults.removePersistentDomain(forName: domainName) }
        defaults.register(defaults: ["updatePolicy": "0", "SUEnableAutomaticChecks": true])
        let state = UpdatePolicyConsentState(defaults: defaults, domainName: domainName)
        XCTAssertFalse(state.hasStoredPreference)
        XCTAssertFalse(state.hasSparklePermissionResponse)
    }

    func testStoredAppPreferenceCanBeApplied() {
        let state = UpdatePolicyConsentState(persistentDomain: ["updatePolicy": "1"])
        XCTAssertTrue(state.hasStoredPreference)
        XCTAssertFalse(state.hasSparklePermissionResponse)
    }

    func testAcceptedSparkleResponseCanBeSynchronized() {
        let state = UpdatePolicyConsentState(persistentDomain: ["SUEnableAutomaticChecks": true])
        XCTAssertFalse(state.hasStoredPreference)
        XCTAssertTrue(state.hasSparklePermissionResponse)
    }

    func testDeclinedSparkleResponseCanBeSynchronized() {
        let state = UpdatePolicyConsentState(persistentDomain: ["SUEnableAutomaticChecks": false])
        XCTAssertTrue(state.hasSparklePermissionResponse)
    }
}
