# SentryCrashReporter - Specs

## Summary

`SentryCrashReporter` starts Sentry only when the persisted crash-report policy is Always and a
DSN is configured. Never and Ask leave Sentry uninitialized, so no automatic crash report is
retained before consent. A consent result is persisted as Always or Never. Handled Objective-C
exceptions are forwarded exactly once only while the current policy is Always.

## Test scenarios

### A. Consent routing

- **testNeverDoesNotStartOrCapture** - Never leaves the client untouched.
- **testAskDoesNotStartOrCapture** - Ask retains and sends nothing before a consent choice.
- **testConsentResultPersistsAlwaysOrNever** - Enable resolves to Always and Not now resolves to Never.

### B. Crash reporting

- **testAlwaysStartsReporterOnce** - Always starts the client once when a DSN is available.
- **testAlwaysWithoutDsnDoesNotStartReporter** - Always does not initialize an unconfigured client.
- **testHandledObjectiveCExceptionCapturesOnceOnlyWhenAlways** - Only Always forwards a handled exception, once.
