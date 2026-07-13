# Focus Sets agent map

## Rules
- Window result = normal safety exclusions AND Focus Sets visibility policy AND Focus Set app membership; never fork the filter or render pipeline.
- Direct set shortcuts open the standard switcher grid scoped to that saved set. No runtime Focus Sets browser or parent return flow exists.
- The Add/Edit Settings sheet owns application search and remains transactional.
- Run matching `*Specs.md` + `*Tests.swift`; run the full `Test` scheme after keyboard/session work.

## File map
- Model/store: `FocusSet.swift`, `FocusSetsStore.swift`.
- Membership: `FocusSetResolver.swift`, `Windows.swift`.
- State/invoke: `FocusSetSessionResolver.swift`, `FocusSetPresentationSnapshotBuilder.swift`, `SwitcherSession.swift`, `App.swift`.
- Settings/edit/delete: `FocusSetSettingsView.swift`, `FocusSetSettingsResolver.swift`.
- Hotkeys: `ControlsTab.swift`, `KeyboardEventsTestable.swift`, `ShortcutAction.swift`, `ATShortcut.swift`.

## Direct shortcut invariants
- Each configured binding is keyed by its saved set UUID. A stale UUID must not target another set.
- Repeating the active set's shortcut cycles that scoped grid.
- A direct shortcut requires a non-modifier key. Its chord remains active until all bound modifiers release, then applies the Focus Sets-global Focus, Hold, or Search setting.
