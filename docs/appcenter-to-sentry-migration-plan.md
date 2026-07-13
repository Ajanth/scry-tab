# AppCenter to Sentry migration plan

## Decision

Replace the retired AppCenter crash service with an owner-controlled Sentry project. ScryTab has not shipped and has no users, so this is a clean replacement, not a data migration. Do not preserve, upload, or ship code to delete AppCenter crash caches. Remove any developer-machine cache manually while testing if needed.

ScryTab will send **crash reports only**. It will not send performance data, profiles, replay, broad breadcrumbs, user identity, or `DebugProfile` automatically.

## Crash-report consent

Keep the existing General-tab choices, with this simpler behavior:

| Choice | Behavior |
| --- | --- |
| **Never** | Do not initialize Sentry. Do not retain or send crash reports. |
| **Ask** | Do not initialize Sentry. On a suitable launch, ask whether to enable automatic crash reports. **Enable** persists Always; **Not now** persists Never. |
| **Always** | Initialize Sentry with its crash-only configuration. It may retain and send crash reports according to Sentry's normal crash-report lifecycle. |

This deliberately replaces the former post-crash prompt. It is a better fit for a pre-release app: consent happens before collection, there is no consent-gated crash cache, and no custom transport, `URLProtocol` gate, retry policy, or live reconfiguration state machine is needed.

Direct changes in the General tab take effect on the next launch. An Ask prompt that enables Always may start Sentry after consent in the same launch. Exception capture must check the current preference before recording a handled Objective-C exception, so a switch to Never also suppresses those reports in the current process.

## Owner setup

1. Create a Sentry organization and one ScryTab project in the selected data region. Do not reuse the former AltTab account.
2. Enable Sentry's data scrubber, configure a new-issue email alert, and disable project features ScryTab will not use.
3. Create a least-privilege CI token for debug-symbol uploads.
4. Configure these GitHub Actions production-environment values: `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT`. The DSN is shipped with the app and is not a secret; the auth token is.

Never put the auth token, crash reports, or debug profiles in source control, build logs, or chat.

## Implementation

1. Before changing Swift, AppKit, project, or test files, read `AGENTS.md` and the required Swift/AppKit development skill. Keep Swift 5.8 and the owner-approved macOS 11 deployment target.
2. Use the current official Sentry Apple/macOS instructions to choose an SDK release compatible with the repository's Xcode/Swift toolchain and macOS 11.
3. Add Sentry as a dependency and put all SDK interaction in one owner, for example `src/vendors/SentryCrashReporter.swift`.
4. Initialize preferences before creating the reporter. The current AppCenter reporter starts before `Preferences.initialize()` and works around that by registering its own default; remove that workaround.
5. Start Sentry only when the launch snapshot is Always. Configure the selected SDK explicitly for crash reporting, disabling every unwanted telemetry feature exposed by that exact version. Do not rely on SDK defaults and do not pin this document to a version-specific property list.
6. When the snapshot is Ask, show a single native consent alert after normal launch UI is ready. Its result persists Never or Always; Sentry starts only after an Always result. If the app is not ready to show the alert, defer it to a later launch rather than building a prompt queue.
7. Replace `AppCenterApplication` with a small `ScryTabApplication : NSApplication` subclass and update `NSPrincipalClass`. Preserve the existing `sendEvent:` exception boundary. Its bridge calls the isolated reporter once, and the reporter is a no-op unless the current policy is Always. Do not use Sentry swizzling or a second uncaught-exception capture path.
8. Do not attach `DebugProfile` to automatic reports. It remains part of the separate, explicit manual-feedback workflow.
9. Replace the AppCenter dSYM script with Sentry's current supported CLI upload command. Use `SENTRY_AUTH_TOKEN`, fail CI on upload failure, and upload the app plus embedded-framework dSYMs produced by the release build.
10. Remove all AppCenter code and plumbing in the same change: the Swift/Objective-C reporter and application subclass, bridging-header imports, `Info.plist` secret and principal class, `Secrets.appCenterSecret`, AppCenter package/vendor files, environment injection, upload script, CI variables and workflow step, and now-unused crash queue.
11. Before the first public release, update the privacy policy for the direct-download app. State that crash reports are optional, what Sentry may receive when Always is selected, that `DebugProfile` is not automatically attached, and how to turn reporting off. App Store privacy material is out of scope unless distribution changes.

## Verification

1. Run the complete command sequence from `ai/build.sh`, plus the affected tests and the full test suite.
2. Add focused tests for policy routing: Never does not start or capture; Ask does not start or retain a crash report until the user chooses; Always starts the reporter; handled Objective-C exceptions reach the reporter once only when Always.
3. On a clean local test account, manually verify the Ask alert, both answers, a controlled non-production crash under Always, and that the uploaded crash is symbolicated in Sentry.
4. Confirm automatic reports omit `DebugProfile` and unwanted telemetry options are disabled for the chosen SDK version.
5. Confirm the release workflow has no `APPCENTER_SECRET`, `APPCENTER_TOKEN`, `upload_symbols_to_appcenter.sh`, `AppCenter`, or `AppCenterCrashes` references.

## Out of scope

Repairing the manual-feedback endpoint or adding a Cloudflare Worker is a separate project. It is unrelated to automatic crash reporting.
