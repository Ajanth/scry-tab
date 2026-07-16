# PreferencesMigrations — Specs

> **Line coverage:** `PreferencesMigrations.swift` 49% — the per-migration transforms are covered; the `migratePreferences`/`updateToNewPreferences` orchestrator, `migrateLoginItem`, and `migrateShortcutPreferencesToSecureCoding` are intentionally excluded (see "Not covered" below). _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

`PreferencesMigrations` upgrades a user's stored `UserDefaults` from an older ScryTab version to the current schema. It runs once per launch (`migratePreferences()`), comparing the stored `preferencesVersion` to the app version and applying each registered migration whose version threshold the stored version is at or below. Most migrations are small, self-contained `UserDefaults` transforms (rename a key, remap an index, split one key into two, convert a Bool string to an enum index).

**Why this is the highest-value safety net:** these run on every upgrade against real users' data. A mistake silently corrupts settings for the entire installed base — and there's no UI signal when it goes wrong. The tests pin each transform's exact input→output.

## Behavior & edge cases

- **Version gating (`shouldRun`)** uses `String.compare(_, options: .numeric)`. A migration with threshold `T` runs iff the stored version is **≤ T** (i.e. compare is *not* `.orderedDescending`). The `.numeric` option is load-bearing: lexically `"9" > "10"`, but numerically `9 < 10`, so a user on `9.x` still gets a `10.x` migration.
- **Order matters**: `updateToNewPreferences` runs migrations newest-threshold-first; some depend on keys earlier ones leave behind. The per-migration tests isolate each, but the registration list in `updateToNewPreferences` is the integration contract.
- **Shared presentation migration** runs once behind `sharedPresentationDefaultsMigrated`. It seeds shared window ordering from shortcut 1, removes redundant equal values, and retains different shortcut values as explicit overrides.
- **Obsolete when-active shortcuts scrub** runs once behind `obsoleteWhenActiveShortcutsRemoved`. It `removeObject`s the five retired static shortcut keys (`lockSearchShortcut`, `minDeminWindowShortcut`, `toggleFullscreenWindowShortcut`, `quitAppShortcut`, `hideShowAppShortcut`) so stale UserDefaults cannot resurrect them.
- **Idempotency**: `migrateExceptionsTitleArray` must be safe to re-run — already-migrated (array-form) data fails to decode into the legacy (`String?`) shape, triggering an early return that leaves data untouched.
- **Testability**: production reads/writes `UserDefaults.standard`; the tests inject an isolated suite via `PreferencesMigrations.defaults` (reset in `tearDown`) so they never touch the dev machine's real prefs.
- **Not covered** (documented gaps): `migrateShortcutPreferencesToSecureCoding` (needs the real NSKeyedArchiver/ShortcutRecorder codec, stubbed compile-only) and `migrateLoginItem` (mutates real Login Items via deprecated LaunchServices APIs).

---

## Test scenarios

Mirrors `PreferencesMigrationsTests.swift` 1:1.

### A. Version gating (`shouldRun`)
- **testVersionGatingRunsForOlderStoredVersion** — stored `6.0.0` ≤ threshold `10.13.0` → runs.
- **testVersionGatingRunsForEqualVersion** — stored == threshold → runs.
- **testVersionGatingSkipsForNewerStoredVersion** — stored `11.0.0` > `10.13.0` → skipped.
- **testVersionGatingUsesNumericCompareNotLexical** — stored `9.0.0` < `10.0.0` numerically → runs (guards the `.numeric` option).

### B. Shared presentation defaults
- **testSharedPresentationDefaultsPreserveDistinctShortcutValues** — shortcut 1 seeds shared window ordering and a different shortcut value survives as an explicit override.
- **testSharedPresentationDefaultsUseNormalFallbacksAndRemoveEqualOverrides** — absent legacy values use the normal defaults and redundant equal stored values are removed.
- **testSharedPresentationDefaultsMigrationRunsOnlyOnce** — the persistent marker prevents a later launch from overwriting shared-setting edits.

### B2. Obsolete when-active shortcuts scrub
- **testObsoleteWhenActiveShortcutsRemovesKeysAndSetsMarker** — marker unset → five obsolete shortcut keys removed and marker set.
- **testObsoleteWhenActiveShortcutsMigrationRunsOnlyOnce** — marker already set → no-op (reintroduced keys left untouched).

### D. Blacklist → exceptions (key rename)
- **testBlacklistCopiedToExceptionsAndRemoved** — `blacklist` value copied to `exceptions`; `blacklist` removed.
- **testBlacklistDoesNotOverwriteExistingExceptions** — existing `exceptions` preserved; `blacklist` still removed.

### E. Legacy blacklists → structured exceptions (faithful JSON)
- **testExceptionsFromDontShowBlacklistBecomesHideAlways** — `dontShowBlacklist` entry → `ExceptionEntry(hide: .always, ignore: .none)`; old key removed.
- **testExceptionsFromDisableShortcutsOnlyFullscreenBecomesIgnoreWhenFullscreen** — `disableShortcutsBlacklist` + `…OnlyFullscreen` → `ignore: .whenFullscreen`.

### F. `windowTitleContains` String → [String]
- **testTitleArrayWrapsLegacyStringIntoArray** — legacy string `"abc"` → `["abc"]`.
- **testTitleArrayEmptyLegacyStringBecomesNil** — legacy empty string → `nil`.
- **testTitleArrayIsIdempotentOnAlreadyMigratedData** — already array-form → unchanged (early return).

### G. `showWindowlessApps` value remap
- **testShowWindowlessAppsOldShowAtEndBecomesTwo** — old `"0"` (showAtTheEnd) → `"2"`.
- **testShowWindowlessAppsOtherValueBecomesOne** — any other value → `"1"`.

### H. Show-windows checkbox → dropdown
- **testShowWindowsCheckboxTrueBecomesShow** — `"true"` → `"0"` (.show).
- **testShowWindowsCheckboxFalseBecomesHide** — `"false"` → `"1"` (.hide).

### I. Gestures split
- **testGesturesFourFingerRemapsToHorizontal** — `"2"` (4-finger) → `"3"` (4-finger-horizontal).
- **testGesturesOtherValueUnchanged** — other values untouched.

### K. Menubar icon hidden-value → shown toggle
- **testMenubarIconHiddenValueSplitsIntoShownToggle** — `menubarIcon == "3"` → `menubarIcon "0"` + `menubarIconShown "false"`.

### L/M. Width / size splits
- **testMinMaxWidthZeroBecomesOne** — `windowMinWidthInRow "0"` → `"1"`.
- **testMaxSizeOnScreenSplitsIntoWidthAndHeight** — `maxScreenUsage` → both `maxWidthOnScreen` + `maxHeightOnScreen`.

### N. Shortcut key cleanup + index move
- **testNextWindowShortcutStripsHoldModifierChars** — hold-modifier chars removed from `nextWindowShortcut` (`"⌥⇥"` → `"⇥"`).
- **testShortcutIndexesMoveSuffix4To10AndSetCount** — suffix `4` → `10`; `shortcutCount` set to `3` when a 3rd shortcut exists.

### P. Dropdowns: English text → indexes
- **testDropdownTextValuesBecomeIndexes** — `appsToShow "Active app"` → `"1"`; `theme "❖ Windows 10"` → `"1"`.
