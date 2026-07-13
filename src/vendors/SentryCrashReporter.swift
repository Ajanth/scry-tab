import Cocoa
import Sentry

enum CrashReportPolicy: String {
    case never = "0"
    case ask = "1"
    case always = "2"

    static func afterConsent(_ enabled: Bool) -> CrashReportPolicy {
        enabled ? .always : .never
    }
}

protocol CrashReportingClient {
    func start(dsn: String)
    func capture(exception: NSException)
}

final class SentryCrashReporter {
    static let shared = SentryCrashReporter(client: SentryClient())

    private let client: CrashReportingClient
    private var started = false

    init(client: CrashReportingClient) {
        self.client = client
    }

    func startIfAllowed(policy: CrashReportPolicy, dsn: String?) {
        guard policy == .always, !started, let dsn, !dsn.isEmpty else { return }
        client.start(dsn: dsn)
        started = true
    }

    func captureHandledException(_ exception: NSException, policy: CrashReportPolicy) {
        guard policy == .always else { return }
        client.capture(exception: exception)
    }
}

private final class SentryClient: CrashReportingClient {
    func start(dsn: String) {
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.enableCrashHandler = true
            options.enableUncaughtNSExceptionReporting = false
            options.enableSigtermReporting = false
            options.maxBreadcrumbs = 0
            options.enableNetworkBreadcrumbs = false
            options.enableLogs = false
            options.sampleRate = 1
            options.enableAutoSessionTracking = false
            options.enableGraphQLOperationTracking = false
            options.enableWatchdogTerminationTracking = false
            options.attachAllThreads = false
            options.sendDefaultPii = false
            options.enableAutoPerformanceTracing = false
            options.enablePersistingTracesWhenCrashing = false
            options.enableNetworkTracking = false
            options.enableFileIOTracing = false
            options.enableDataSwizzling = false
            options.enableFileManagerSwizzling = false
            options.enableCoreDataTracing = false
            options.enableSwizzling = false
            options.configureProfiling = nil
            options.sendClientReports = false
            options.enableAppHangTracking = false
            options.enableAutoBreadcrumbTracking = false
            options.enablePropagateTraceparent = false
            options.enableCaptureFailedRequests = false
            options.enableMetricKit = false
            options.enableMetricKitRawPayload = false
            options.swiftAsyncStacktraces = false
            options.enableSpotlight = false
            options.enableMetrics = false
            options.tracesSampleRate = 0
        }
    }

    func capture(exception: NSException) {
        SentrySDK.capture(exception: exception)
    }
}
