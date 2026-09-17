import XCTest

final class LaunchIntentTests: XCTestCase {
    private let executablePath = "/Applications/ScryTab.app/Contents/MacOS/ScryTab"

    private func resolve(_ flags: String..., pendingSilentLaunch: Bool = false) -> LaunchIntent {
        LaunchIntent.resolve(arguments: [executablePath] + flags, pendingSilentLaunch: pendingSilentLaunch)
    }

    func testNoArgumentsIsAUserInitiatedLaunch() {
        XCTAssertEqual(resolve(), .userInitiated)
    }

    func testLoggingArgumentsAloneStayUserInitiated() {
        XCTAssertEqual(resolve("--logs=debug"), .userInitiated)
    }

    func testSilentArgumentIsSilent() {
        XCTAssertEqual(resolve(LaunchIntent.silentArgument), .silent)
    }

    func testBenchmarkArgumentIsSilent() {
        XCTAssertEqual(resolve("--benchmark", "benchmark-config.json"), .silent)
    }

    func testPendingSparkleMarkerIsSilent() {
        XCTAssertEqual(resolve(pendingSilentLaunch: true), .silent)
    }

    func testLoggingDoesNotSoftenTheSilentArgument() {
        XCTAssertEqual(resolve("--logs=debug", LaunchIntent.silentArgument), .silent)
        XCTAssertEqual(resolve(LaunchIntent.silentArgument, "--logs=debug"), .silent)
    }

    func testLoggingDoesNotSoftenTheBenchmarkArgument() {
        XCTAssertEqual(resolve("--logs=debug", "--benchmark", "benchmark-config.json"), .silent)
    }

    func testLoggingDoesNotSoftenThePendingSparkleMarker() {
        XCTAssertEqual(resolve("--logs=debug", pendingSilentLaunch: true), .silent)
    }
}
