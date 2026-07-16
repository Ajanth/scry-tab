# Pro Gating Restoration Notes

This document captures the Pro gating architecture that existed before the Pro removal pass. It is intentionally implementation-facing: use it with PR history to restore the deleted files and then apply the same patterns to any future Pro-only feature.

## Core Model

`LicenseManager` is the only source of truth for entitlement state.

Restore these files as a coherent unit:

- `src/pro/license/LicenseState.swift`
- `src/pro/license/LicenseManager.swift`
- `src/pro/license/LicenseAPI.swift`
- `src/pro/license/RemoteLicenseClient.swift`
- `src/pro/license/LicenseCookie.swift`
- `src/pro/license/Keychain.swift`
- `src/pro/license/MachineFingerprint.swift`
- `src/pro/license/Clock.swift`
- `src/pro/license/LicenseManagerSpecs.md`
- `src/pro/license/LicenseManagerTests.swift`

The state shape was:

```swift
enum LicenseState: Equatable {
    case trial(daysRemaining: Int)
    case pro
    case proExpired
    case trialExpired
}
```

`isProAvailable` must mean "trial or valid Pro". `isProLocked` must mean "trial expired or Pro expired". Do not add a grace period unless the product decision explicitly asks for one; the previous implementation downgraded degradable preferences immediately when the state entered `.trialExpired` or `.proExpired`.

Keep the Keychain and identity invariants stable. `LicenseManager.keychainService` was `"\(App.bundleIdentifier).license"` and the defaults suite was `"\(App.bundleIdentifier).license"`. The stored Keychain accounts were `licenseKey`, `instanceId`, and `variantId`; `customerEmail` lived in the license defaults suite. Do not change the bundle id, Team ID, Developer ID, Keychain service, or access-group story casually, because stored license state is tied to those identifiers.

## Feature Registry

`src/pro/ProFeature.swift` was the single registry for every gated capability. Restore it before adding feature-specific gates.

The registry carried three responsibilities:

- It defined every gated feature as an enum case.
- It classified each feature with `GateKind`.
- It linked preference-backed gates to `ProGatedPreferences`.

The gate kinds were:

- `degradable`: a stored preference can hold a Pro value, but when Pro locks the app snapshots that value and writes a free equivalent. Runtime use is not blocked.
- `hardGated`: there is no stored preference to downgrade. A runtime action calls `attemptUse()` before executing.
- `degradableAndHardGated`: the preference degrades on lock, and the first post-expiration switcher session can trigger the free-pass/full-upgrade flow.

The previous enum cases were:

- `appIconsAndTitlesStyle`: degradable and hard-gated; Pro value was `AppearanceStylePreference.titles`.
- `autoSize`: degradable; Pro value was a removed adaptive appearance-size option that no longer exists.
- `searchOnReleaseShortcut`: degradable and hard-gated; Pro value was `ShortcutStylePreference.searchOnRelease`.
- `extraShortcut(index: Int)`: hard-gated; shortcut slots with index >= 1.
- `searchInSwitcher`: hard-gated.
- `lockSearchInSwitcher`: hard-gated.

When adding any future Pro feature, add a `ProFeature` case first, give it copy through `ProFeatureCopy`, classify its `gateKind`, and decide whether `gatedPreference` is nil or points at a `ProGatedPreferences` entry.

## Preference Gates

Preference-backed gates lived in `src/preferences/PreferenceDefinition.swift`. Restore this file and the related uses in `Preferences.swift` if preference degradation is needed.

The core type was:

```swift
struct PreferenceGate<T: MacroPreference & CaseIterable & Equatable> {
    let freeEquivalent: T
    let rememberedKey: String
    let isProValue: (T) -> Bool
}
```

`PreferenceDefinition<T>` owned the storage key, default value, and optional gate. Its required behavior:

- `read()` returns the stored value while Pro is available.
- `read()` returns the remembered Pro value during `ProTransitionManager.isFreePassSessionActive`.
- `read()` returns the free equivalent while Pro is locked and the stored value is still Pro.
- `snapshotAndDowngrade()` writes the free equivalent and returns the original enum index.
- `restore(from:)` writes the remembered enum index back with `notify: false`.
- `isStoredValuePro()` is used by Settings write interception.

`AnyProGatedPreference` type-erased these operations so `ProTransitionState` could iterate all gated preferences without knowing the enum type.

To add a new preference gate:

1. Add a `PreferenceDefinition` in `ProGatedPreferences`.
2. Give it a stable preference key, a free equivalent, a `rememberedKey`, and an `isProValue` predicate.
3. Add its erased form to `ProGatedPreferences.all`.
4. Change the public `Preferences` getter to call `.read()` instead of reading `CachedUserDefaults` directly.
5. If the preference has per-shortcut overrides, repeat the same pattern for the reachable override keys. The previous implementation snapshotted only shortcut 0 overrides because shortcut indexes >= 1 were already hard-gated.
6. Make the UI intercept locked Pro selections before they write. Revert the control to the stored/free value and call `UpgradeTab.navigateToUpgradeTab()`.

Example shape:

```swift
static let futureMode = PreferenceDefinition<FutureModePreference>(
    key: "futureMode",
    default: .freeMode,
    gate: PreferenceGate(
        freeEquivalent: .freeMode,
        rememberedKey: "rememberedFutureMode",
        isProValue: { $0 == .proMode }))
```

Then:

```swift
static var futureMode: FutureModePreference { ProGatedPreferences.futureMode.read() }
```

## Runtime Gates

Runtime-only gates call `ProFeature.<case>.attemptUse()` at the point of action and abort if it returns false.

Previous call-site patterns:

- Extra shortcut slots: `ShortcutActions.execute(_:)` checked `ProFeature.extraShortcut(index: index).attemptUse()` before dispatching shortcut ids for `holdShortcut*` and `nextWindowShortcut*` where `index >= 1`.
- Search mode: `TilesView.enableSearchEditing()` passed `ProFeature.searchInSwitcher.attemptUse()` into `SearchModeResolver.enableEditing`.
- Locked search mode: `TilesView.lockSearchMode()` passed `ProFeature.lockSearchInSwitcher.attemptUse()` into `SearchModeResolver.lock`.

For a future runtime gate, put the check immediately before the behavior that must not execute:

```swift
guard ProFeature.futureAction.attemptUse() else { return }
performFutureAction()
```

If the action participates in the Day 15 contextual copy, add it to `HardGateReason.resolved`. Keep the priority deterministic. The previous priority was `extraShortcut > search > titlesStyle > nonEngaged`.

## Transition Flow

Restore the transition flow as a set:

- `src/pro/scheduling/ProTransitionManager.swift`
- `src/pro/scheduling/ProTransitionManagerTestable.swift`
- `src/pro/scheduling/ProTransitionScheduler.swift`
- `src/pro/scheduling/ProTransitionState.swift`
- `src/pro/scheduling/ProTransitionSpecs.md`
- `src/pro/scheduling/ProTransitionTests.swift`
- The Day X UI files in `src/pro/scheduling/Day*.swift`
- `src/pro/ui/ProPromptHost.swift`
- `src/pro/ui/ProPromptWindow.swift`
- `src/pro/ui/ProPromptPopover.swift`
- `src/pro/ui/ProPromptHeader.swift`

`ProTransitionState` persisted all flags under `LicenseManager.defaultsSuiteName` with `proTransition.` prefixes. It also owned the remembered preference indices. The important methods were:

- `onProLockEngaged()`: iterate `ProGatedPreferences.all`, snapshot Pro values, write free equivalents, persist remembered indices.
- `onProUnlocked()`: restore remembered indices through `AnyProGatedPreference.restoreFromIndex`, then clear remembered keys.
- `snapshot(...)`: build the pure `ProTransitionManagerTestable.State`.

`ProTransitionManager` coordinated side effects:

- `onLicenseStateChanged()` canceled scheduling and dismissed Pro prompts for `.pro`, and called `onProLockEngaged()` when locked.
- `onSwitcherShown()` handled Day 4 tour and the first post-expiration free-pass session.
- `onSwitcherDismissed()` ended the free-pass session and showed deferred prompts after the switcher closed.
- `attemptHardGatedFeature(_:)` applied the free-pass/full-upgrade/hard-gate-popover ladder.
- `proLockStateDidChangeNotification` told live Settings UI to repaint locked/ghost states.

`ProTransitionManagerTestable` must remain pure: no singletons, no `Date()`, no UI, no side effects. It decided timed actions, hard-gate actions, switcher-open actions, badge-dot visibility, and scheduling completion. Keep feature additions in pure decision functions when possible, then test them in `ProTransitionTests.swift`.

## Startup Wiring

Restore the app wiring in `App.applicationDidFinishLaunching` and launch continuation:

```swift
LicenseManager.shared.onBeforeProUnlock = { ProTransitionManager.shared.onProUnlocked() }
LicenseManager.shared.onStateChanged = { state in
    Menubar.refreshLicenseMenuItems()
    syncLicenseCookie(state: state)
    ProTransitionManager.shared.onLicenseStateChanged()
    UpgradeTab.refreshStatus()
    SettingsWindow.shared?.refreshUpgradeButton()
    if TilesPanel.shared != nil { App.resetPreferencesDependentComponents() }
    NotificationCenter.default.post(name: ProTransitionManager.proLockStateDidChangeNotification, object: nil)
}
LicenseManager.shared.initialize()
```

After permissions and UI initialization:

```swift
ProTransitionManager.shared.onAction = { ProPromptHost.shared.dispatch($0) }
ProTransitionManager.shared.onAppLaunchComplete()
```

Switcher lifecycle hooks are also required:

- `App.showUiOrCycleSelection(...)` must call `ProTransitionManager.shared.onSwitcherShown()` at the start of a fresh switcher session.
- `App.hideUi()` must call `ProTransitionManager.shared.onSwitcherDismissed()`.

Custom URL activation was handled in `App.application(_:open:)` by reading `scry-tab://activate?license_key=...`, showing the Upgrade tab, calling `LicenseManager.shared.activate`, and refreshing UI or presenting activation failure.

## Settings And Menu Surfaces

Restore `src/preferences/settings-window/tabs/UpgradeTab.swift` for purchase, activation, deactivation, account links, and license status. `UpgradeTab.navigateToUpgradeTab()` was the common redirect for locked Pro clicks.

Restore `src/pro/ui/ProBadgeView.swift` and `ProBadgeViewSegmentSpecs/Tests` for Settings badges. Badges were used in:

- `AppearanceTab` for Pro appearance styles, size options, and search-on-release.
- `ShortcutEditor` for per-shortcut override panes.
- `ShortcutsWhenActiveSheet` for search and lock-search rows.
- `SidebarList` for extra shortcut rows.

UI interception rules:

- A locked Pro click must not write the Pro value.
- The control must snap back to the stored/free value.
- The app should navigate to the Upgrade tab.
- Existing live Settings windows must repaint after `proLockStateDidChangeNotification`.

Restore the menu integration in `Menubar`:

- `Get Pro` menu item opened checkout.
- `My Account` was shown for valid/expired Pro users.
- `Support this project` was shown for non-Pro states according to the previous state switch.
- `UpgradeMenuItemView` rendered trial/pro-expired copy.
- Badge dot visibility came from `ProTransitionManager.shared.shouldShowBadgeDot`.

Restore `SettingsWindow.refreshUpgradeButton()` behavior from PR history so Settings' sidebar/header reflects `.trial`, `.pro`, `.proExpired`, and `.trialExpired` consistently.

## Usage Stats And Copy

Restore these copy/stat helpers if Day X prompts or upgrade messaging return:

- `src/pro/ProFeatureCopy.swift`
- `src/pro/ProConversionCopy.swift`
- `src/pro/ui/UsageStatHeroView.swift`
- `src/util/UsageStats.swift` Pro-use counters

When adding a new feature, update the copy once in `ProFeature.copy`/`ProFeatureCopy`. Do not scatter feature labels across prompt views.

## Tests To Bring Back Or Update

For licensing:

- `LicenseManagerTests.swift` should cover trial creation, expiration, activation, deactivation, validation, variant/version cutoffs, Keychain write failure rollback, and `onBeforeProUnlock`.

For transition behavior:

- `ProTransitionTests.swift` should cover Day 1, Day 4, Day 12, Day 15, Day 21, Day 35, badge dot, free pass, post-C hard gate popover, opted-out behavior, and the full flow for both degradable-only and hard-gated users.

For preference gates:

- Add tests around `snapshotAndDowngrade`, remembered index persistence, `read()` during locked state, `read()` during free-pass session, and restore on unlock.
- If using the triad pattern, update the matching `*Specs.md` scenario lines when adding tests.

For UI:

- Keep `ProBadgeViewSegmentTests.swift` for segment overlay behavior.
- Keep row badge idempotence tests in `SidebarListTests.swift` if extra shortcut badges return.
- Add narrow tests around pure resolvers where UI click interception is factored into testable helpers.

After code restoration or new gating work, run the commands from `ai/build.sh` rather than inventing a different build path.

## Minimal Checklist For A New Pro Feature

1. Add a `ProFeature` case.
2. Choose `GateKind`.
3. Add marketing copy through `ProFeatureCopy`.
4. For a preference feature, add a `ProGatedPreferences` definition, include it in `.all`, and route the `Preferences` getter through `.read()`.
5. For a runtime feature, call `attemptUse()` at the action boundary.
6. Add Settings badges and click interception for any visible Pro-only control.
7. Add remembered snapshot/restore handling for any stored Pro value.
8. Update `HardGateReason.resolved` only if the full-upgrade/hard-gate copy needs a feature-specific header.
9. Update usage stats if the feature should affect conversion copy.
10. Update specs and tests before shipping.
