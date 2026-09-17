# Menubar visibility preference

## Purpose

ScryTab's menu bar icon is optional. `MenubarVisibilityPreference` owns the persisted half of that
contract so `Preferences` (application-only) and the Test target agree on the key and its default.
The Test target compiles a stub `Preferences`, so these values are the only part of the registry a
unit test can pin.

## Behavior

- `key` is the single stored flag: `"true"` shows the status item, `"false"` keeps the status item
  alive but hidden from the menu bar.
- The default is `"true"`, so a new install and a reset both show the icon.
- The default is a *string*. `CachedUserDefaults.bool` reads through `UserDefaults.string(forKey:)`,
  which returns nothing for a natively typed boolean and would leave its forced unwrap empty.
- Native Command-drag removal persists `"false"`. The General-tab switch is the only interactive path
  back to `"true"`; reset and import also restore it, because the key is an owned preference.

## Test scenarios

- **testKeyStaysStableBecauseRenamingItOrphansTheStoredSetting** — the key is exactly `showMenubarIcon`.
- **testDefaultShowsTheMenuBarIcon** — the default value means visible.
- **testDefaultIsALiteralTheStringBackedReaderCanParse** — the default is one of the two literals `Bool(_:)` accepts.
