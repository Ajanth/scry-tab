# Focus Sets agent map

## Rules
- Window result = selected profile filters AND Focus Set app membership; never fork filter/render pipeline.
- Direct set shortcut skips picker; picker confirm and direct invoke both end at `Windows -> TilesView -> TilesPanel`.
- Picker always titles UI; child grid keeps selected profile appearance.
- Run matching `*Specs.md` + `*Tests.swift`; run full `Test` scheme after keyboard/session work.

## File map
- Model/store: `FocusSet.swift`, `FocusSetsStore.swift`.
- Membership/counts: `FocusSetResolver.swift`, `FocusSetCandidateCounter.swift`, `Windows.swift`.
- State/invoke: `FocusSetSessionResolver.swift`, `SwitcherSession.swift`, `App.swift`.
- Settings/edit/delete: `FocusSetSettingsView.swift`, `FocusSetSettingsResolver.swift`.
- Picker data/UI: `FocusSetPickerResolver.swift`, `FocusSetPickerView.swift`, `FocusSetPickerPanel.swift`.
- Hotkeys: `ControlsTab.swift`, `KeyboardEventsTestable.swift`, `ShortcutAction.swift`, `ATShortcut.swift`.
- Shared picker chrome: `TileView.swift`, `TilePresentationResolver.swift`, `TilesView.swift`, `TilesPanel.swift`.

## Bugs hit -> fixes
- Deleted set stayed forever; delete depended on fragile button `identifier` and silently returned.
  Fix: `FocusSetSettingsView.swift`, `FocusSetSettingsResolver.swift` — capture UUID in action closure; exact-ID delete; write/readback; rebuild.
- Wrong RCA blamed 200 ms inventory throttle.
  Fix: `App.swift` — wrong synchronous-refresh workaround removed; do not revive.
- Picker looked like Settings, not switcher.
  Fix: `FocusSetPickerView.swift`, `FocusSetPickerPanel.swift` — pooled `TileView`; `TileUnderLayer`; shared search; cached switcher `EffectView`.
- Picker inherited app-icons geometry despite forced titles.
  Fix: `TileView.swift`, `TilePresentationResolver.swift` — retain supplied presentation style for all geometry/highlight decisions.
- Picker teardown changed ordinary appearance even when picker absent.
  Fix: `FocusSetPickerPanel.swift` — ownership guard; idempotent remove; restore captured search/appearance once.
- Shared search leaked delegate/text/placeholder/editability/frame/superview.
  Fix: `TilesView.swift`, `FocusSetPickerPanel.swift` — snapshot then exact restore.
- Tab focused picker row; row keyboard dead.
  Fix: `FocusSetPickerView.swift`, `FocusSetPickerResolver.swift` — picker tiles excluded from key loop; search owns keys.
- Row activated on mouse-down; drag-out still confirmed.
  Fix: `FocusSetPickerView.swift` — native click recognizer; confirm after completed click.
- Picker typing test failed; global search path consumed text.
  Fix: `TilesView.swift`, `KeyboardEventsTestable.swift` — picker state routes text/query to picker; IME stays field-owned.
- Direct Focus Set shortcuts missing.
  Fix: `FocusSet.swift`, `FocusSetsStore.swift`, `ControlsTab.swift`, `App.swift` — optional persisted chord; dynamic binding; direct normal-grid invoke.
- Shortcut edit could persist before Apply.
  Fix: `FocusSetSettingsView.swift`, `FocusSetSettingsResolver.swift` — recorder is sheet draft; Apply commits name/apps/chord; Cancel writes nothing.
- Deleted/stale direct shortcut could target wrong set.
  Fix: `FocusSetShortcutBindingResolver`, `FocusSetSessionResolver.swift` — UUID action IDs; unregister on config notification; stale UUID no-op/dismiss.
- O(1) Carbon dispatch broke missing/out-of-order hold release recovery.
  Fix: `KeyboardEventsTestable.swift` — fast matched dispatch plus bounded safety call for active numbered hold.
- Modifier-only direct chord collided with normal hold modifier.
  Fix: `CustomRecorderControlTestable.swift`, `FocusSetSettingsView.swift` — direct set shortcut requires non-modifier key.
- New shortcut field risked old/future JSON.
  Fix: `FocusSetsStore.swift` — config v2; optional tolerant parse; normalize; preserve unknown root/set/rule fields.
- Focus Set counting risked second filter implementation.
  Fix: `FocusSetCandidateCounter.swift`, `WindowFilterResolver.swift` — same profile predicate, then membership; no override.
- Direct invoke risked extra candidate-count work.
  Fix: `FocusSetPresentationSnapshotBuilder.swift`, `App.swift` — direct snapshot skips picker counts; existing window hot path stays.

## Last known verification
- Full `Test` scheme: 609 pass.
- Required signed Debug build: pass.
- Runtime visual/Carbon/VoiceOver QA still manual.
