# ShortcutDefaultsResolver — Specs

## Summary

`ShortcutDefaultsResolver` defines the registered shortcut profiles used when no persisted user
choice exists. Shortcut 1 replaces the native app switcher with an all-window Command–Tab view;
Shortcut 2 provides an Option–Tab view scoped to every window of the active app. Additional slots
remain unbound until the user configures them.

## Behavior

- Registered defaults never overwrite a persisted shortcut or filter choice.
- Shortcut 1 uses Command–Tab and the all-app scope.
- Shortcut 2 uses Option–Tab and the active-app scope.
- The existing third-slot non-active-app scope and later all-app scopes remain unchanged.

## Test scenarios

- **testShortcutOneDefaultsToCommandTabAcrossAllApps** — index 0 resolves to Command–Tab with all apps.
- **testShortcutTwoDefaultsToOptionTabForTheActiveApp** — index 1 resolves to Option–Tab with only the active app.
- **testUnusedShortcutsPreserveLegacyScopeDefaults** — unused slots remain unbound and retain their established app scopes.
