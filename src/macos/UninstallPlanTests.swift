import XCTest

class UninstallPlanTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
    private let bundleId = "com.perpro.scry-tab"

    private func paths() -> [String] {
        UninstallPlan.leftoverPaths(homeUrl: home, bundleIdentifier: bundleId).map(\.path)
    }

    func testIncludesTheLaunchAgentPlistThatSurvivesDraggingTheAppToTheTrash() {
        XCTAssertTrue(paths().contains("/Users/test/Library/LaunchAgents/com.perpro.scry-tab.plist"))
    }

    func testIncludesBothPreferenceSuites() {
        XCTAssertTrue(paths().contains("/Users/test/Library/Preferences/com.perpro.scry-tab.plist"))
        XCTAssertTrue(paths().contains("/Users/test/Library/Preferences/com.perpro.scry-tab.usage.plist"))
    }

    func testUsagePlistNameTracksTheSuiteUsageStatsActuallyWritesTo() {
        XCTAssertTrue(UninstallPlan.usageDefaultsSuiteSuffix == "usage")
        XCTAssertTrue(paths().contains { $0.hasSuffix("\(UninstallPlan.usageDefaultsSuiteSuffix).plist") })
    }

    func testIncludesCachesHttpStoragesAndSavedState() {
        XCTAssertTrue(paths().contains("/Users/test/Library/Caches/com.perpro.scry-tab"))
        XCTAssertTrue(paths().contains("/Users/test/Library/HTTPStorages/com.perpro.scry-tab"))
        XCTAssertTrue(paths().contains("/Users/test/Library/Saved Application State/com.perpro.scry-tab.savedState"))
    }

    func testEveryPathStaysInsideTheUsersLibrary() {
        XCTAssertTrue(paths().allSatisfy { $0.hasPrefix("/Users/test/Library/") })
    }

    func testDoesNotIncludeTheAppBundleWhichIsTrashedSeparatelyAndLast() {
        XCTAssertFalse(paths().contains { $0.hasSuffix(".app") })
    }

    func testResolvesAgainstTheGivenHomeRatherThanTheRunningUsers() {
        let other = UninstallPlan.leftoverPaths(homeUrl: URL(fileURLWithPath: "/Users/other", isDirectory: true),
            bundleIdentifier: bundleId).map(\.path)
        XCTAssertTrue(other.allSatisfy { $0.hasPrefix("/Users/other/Library/") })
    }

    func testResolvesAgainstTheGivenBundleIdentifier() {
        let renamed = UninstallPlan.leftoverPaths(homeUrl: home, bundleIdentifier: "com.example.other").map(\.path)
        XCTAssertTrue(renamed.allSatisfy { !$0.contains("scry-tab") })
    }

    func testRemovalSetHasNoDuplicates() {
        XCTAssertEqual(Set(paths()).count, paths().count)
    }
}
