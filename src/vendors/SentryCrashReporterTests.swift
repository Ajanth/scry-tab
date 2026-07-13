import XCTest

final class SentryCrashReporterTests: XCTestCase {
    /// Never leaves the client untouched.
    func testNeverDoesNotStartOrCapture() {
        let client = CrashReportingClientSpy()
        let reporter = SentryCrashReporter(client: client)

        reporter.startIfAllowed(policy: .never, dsn: "https://key@example.ingest.sentry.io/1")
        reporter.captureHandledException(exception(), policy: .never)

        XCTAssertEqual(client.startCount, 0)
        XCTAssertEqual(client.capturedExceptions.count, 0)
    }

    /// Ask retains and sends nothing before a consent choice.
    func testAskDoesNotStartOrCapture() {
        let client = CrashReportingClientSpy()
        let reporter = SentryCrashReporter(client: client)

        reporter.startIfAllowed(policy: .ask, dsn: "https://key@example.ingest.sentry.io/1")
        reporter.captureHandledException(exception(), policy: .ask)

        XCTAssertEqual(client.startCount, 0)
        XCTAssertEqual(client.capturedExceptions.count, 0)
    }

    /// Enable resolves to Always and Not now resolves to Never.
    func testConsentResultPersistsAlwaysOrNever() {
        XCTAssertEqual(CrashReportPolicy.afterConsent(true), .always)
        XCTAssertEqual(CrashReportPolicy.afterConsent(false), .never)
    }

    /// Always starts the client once when a DSN is available.
    func testAlwaysStartsReporterOnce() {
        let client = CrashReportingClientSpy()
        let reporter = SentryCrashReporter(client: client)

        reporter.startIfAllowed(policy: .always, dsn: "https://key@example.ingest.sentry.io/1")
        reporter.startIfAllowed(policy: .always, dsn: "https://key@example.ingest.sentry.io/1")

        XCTAssertEqual(client.startCount, 1)
    }

    /// Always does not initialize an unconfigured client.
    func testAlwaysWithoutDsnDoesNotStartReporter() {
        let client = CrashReportingClientSpy()
        let reporter = SentryCrashReporter(client: client)

        reporter.startIfAllowed(policy: .always, dsn: nil)

        XCTAssertEqual(client.startCount, 0)
    }

    /// Only Always forwards a handled exception, once.
    func testHandledObjectiveCExceptionCapturesOnceOnlyWhenAlways() {
        let client = CrashReportingClientSpy()
        let reporter = SentryCrashReporter(client: client)

        reporter.captureHandledException(exception(), policy: .never)
        reporter.captureHandledException(exception(), policy: .ask)
        reporter.captureHandledException(exception(), policy: .always)

        XCTAssertEqual(client.capturedExceptions.count, 1)
    }

    private func exception() -> NSException {
        NSException(name: NSExceptionName("SentryCrashReporterTests"), reason: "Expected test exception", userInfo: nil)
    }
}

private final class CrashReportingClientSpy: CrashReportingClient {
    private(set) var startCount = 0
    private(set) var capturedExceptions = [NSException]()

    func start(dsn: String) {
        startCount += 1
    }

    func capture(exception: NSException) {
        capturedExceptions.append(exception)
    }
}
