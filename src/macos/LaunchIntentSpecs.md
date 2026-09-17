# LaunchIntent

## Purpose

Decides whether a launch may surface ScryTab's Settings window by itself. Login, internal restart,
and Sparkle's update relaunch must stay silent; a user opening ScryTab from Finder, Dock, or an app
launcher stays user-initiated, which is the recovery path once the menu bar icon is hidden.

## Behavior

- Silent causes, each sufficient on its own: the silent argument, `--benchmark`, or a pending
  one-shot Sparkle marker.
- Everything else is user-initiated, including no arguments and logging-only arguments (`--logs=`).
  Logging configures diagnostics; it never expresses launch intent.
- Precedence is "any silent cause wins": logging passing alongside a silent cause does not soften it,
  and the silent argument is not order-dependent.
- Resolution is pure. The caller reads and removes the marker; this type never touches `UserDefaults`.
- The marker is an internal handoff, not a preference: it stays out of `Preferences.defaultValues`,
  import/export, and reset.

## Edge cases

- `CommandLine.arguments` always carries argv[0], the executable path. Matching is by exact
  containment, so that path can never decide the intent.
- `--benchmark` is matched exactly because `BenchmarkConfig` requires a separate following value.
- Recognized CLI commands (`--list`, `--focus=…`, …) never reach this type: `main.swift` handles them
  and exits before `App.run()`.
- The silent argument is not one of the CLI command forms `CliClient.detectCommand()` recognizes, so
  a launch carrying it proceeds to a normal app run.

## Test scenarios

- **testNoArgumentsIsAUserInitiatedLaunch** — a plain double-click stays user-initiated.
- **testLoggingArgumentsAloneStayUserInitiated** — `--logs=debug` does not suppress the window.
- **testSilentArgumentIsSilent** — the login/restart argument yields silent.
- **testBenchmarkArgumentIsSilent** — benchmark launches yield silent.
- **testPendingSparkleMarkerIsSilent** — a consumed marker yields silent even with no arguments.
- **testLoggingDoesNotSoftenTheSilentArgument** — logging plus the silent argument stays silent.
- **testLoggingDoesNotSoftenTheBenchmarkArgument** — logging plus benchmark stays silent.
- **testLoggingDoesNotSoftenThePendingSparkleMarker** — logging plus the marker stays silent.
