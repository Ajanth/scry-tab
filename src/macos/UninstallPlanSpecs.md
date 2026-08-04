# UninstallPlan

Resolves every trace ScryTab leaves outside its own bundle. `Uninstaller` carries the
removal out; this decides what is in it.

## Why it exists

`LoginItem` writes `~/Library/LaunchAgents/<bundle-id>.plist` when *Start at login* is on. That
plist is owned by launchd, not by the app bundle, so dragging ScryTab to the Trash leaves it
behind. On the next login launchd reads it, finds no binary at `Program`, and logs a failure —
permanently, until the user finds and deletes the plist by hand.

Preferences have the same problem in a quieter form: state lives in two suites, so a user who
"removes" ScryTab and later reinstalls it silently inherits their old settings and usage counts.

## Behaviour

- Confirmation is required. The alert is `.critical`, Cancel is the escape key, and *Uninstall*
  is marked destructive on macOS 11+.
- Both preference domains are cleared through `UserDefaults` *before* their backing files are
  trashed, because `cfprefsd` can rewrite those files from its in-memory copy during shutdown.
- Removal is a Trash move, never an unlink, so a mistaken uninstall stays recoverable.
- The app bundle is trashed last, then the app terminates.

## Removal set

Resolved by `leftoverPaths(homeUrl:bundleIdentifier:)`, relative to `~/Library`:

| Path | Written by |
| --- | --- |
| `LaunchAgents/<id>.plist` | `LoginItem` |
| `Preferences/<id>.plist` | `Preferences` |
| `Preferences/<id>.usage.plist` | `UsageStats` |
| `Caches/<id>` | URL loading system, Sparkle |
| `HTTPStorages/<id>` | Sparkle's update checks |
| `Saved Application State/<id>.savedState` | AppKit |

Plus `App.bundleURL`, trashed after the leftovers.

## Edge cases

- A path that does not exist is skipped, not reported as a failure. Most installs will never
  have a `savedState` directory, and `LaunchAgents` is absent whenever *Start at login* was
  never enabled.
- A path that exists but cannot be trashed (permissions, a file locked by another process) is
  logged and skipped; one failure must not abort the rest of the uninstall.
- `leftoverPaths` is pure: it derives paths from its arguments and touches no disk, so the
  removal set is asserted in tests without a real home directory. `usageDefaultsSuiteSuffix`
  is owned here rather than by `UsageStats`, which cannot be resolved without a loaded bundle.
- Trashing the running app bundle is permitted by macOS; the already-loaded process keeps
  running until `terminate` is called on the line after.
