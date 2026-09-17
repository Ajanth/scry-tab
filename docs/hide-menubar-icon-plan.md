# Hide ScryTab’s Menu Bar Icon — Implementation Plan

## Goal

Let users optionally remove ScryTab’s menu bar icon while keeping ScryTab running and making its Settings window reliably reachable from an app launcher.

## Product boundary

ScryTab is a separate new product. There is no ScryTab user setting to preserve from AltTab, and this feature must not read, migrate, or interpret AltTab preference keys such as `menubarIconShown`, `menubarIcon`, or `hideMenubarIcon`.

AltTab is relevant only as an implementation reference: its status item stayed alive while its visibility changed, and native Command-drag removal was persisted. Its preference data and product behavior are not compatibility requirements for ScryTab.

Commit `cac4e6b` deliberately removed the old icon-style enum `MenubarIconPreference`, the retained `Menubar.isVisibleObserver`, and `GeneralTab.menuIconShownToggle`. Consult its deleted implementation for observer ownership and switch lifecycle only; use the distinct name `MenubarVisibilityPreference` for the new visibility contract and do not restore the icon-style preference.

## Scope and decisions

- Add one new ScryTab preference: `showMenubarIcon`, stored in the project’s existing string-backed preference format and defaulting to `"true"`.
- Present it as a positive General-tab switch: “Show menu bar icon”.
- Keep the existing `NSStatusItem` and its menu alive; change only `statusItem.isVisible`.
- Restore native menu-bar removal with `NSStatusItem.Behavior.removalAllowed`; persist a Command-drag removal through `showMenubarIcon == "false"`.
- Keep the existing app-local `⌘,` menu shortcut, but wire it directly to ScryTab’s Settings window. It is not a global shortcut.
- Keep warm relaunch behavior: reopening a running ScryTab instance shows Settings.
- When the icon is hidden, make a user-initiated cold launch from Finder, Dock, or an app launcher show Settings after normal startup and permission gating. A normal cold launch while the icon is visible keeps its current behavior.
- Keep login-item, internal-restart, and all Sparkle-update relaunches silent by passing or recording an explicit one-shot silent-launch marker. Sparkle uses the same relaunch delegate hook for unattended updates and manual “Install and Relaunch”; suppressing automatic Settings in both cases is intentional. Existing first-launch onboarding and explicit pending Settings routes retain priority.
- Do not restore AltTab’s outlined/filled/colored icon selector.
- Do not add a new global Settings hotkey or a new URL scheme.

## Impact

This is a modest feature with low impact on switching, licensing, signing, and release packaging. The risk is concentrated in AppKit lifecycle behavior: a hidden status item must remain usable by Settings, native removal must update the preference exactly once, login startup must not open a window, and user cold launches must not be mistaken for background launches.

The new preference automatically participates in the existing export, import, reset, and preference-cache ownership paths because those paths derive their key set from `Preferences.defaultValues`.

## Architecture

**Smallest shared-boundary change:** Add one boolean preference to the existing `Preferences` boundary, route its change through the existing `PreferencesEvents` dispatcher to the existing `Menubar` owner, and add two tiny dependency-free contracts shared by the application and unit-tests targets. Reuse the existing Settings window and application reopen entry points.

**Shared structures:**

```swift
enum MenubarVisibilityPreference {
    static let key = "showMenubarIcon"
    static let defaultValue = "true"
}
```

```swift
enum LaunchIntent: Equatable {
    case userInitiated
    case silent

    static let silentArgument = "--scrytab-silent-launch"
    static let pendingSilentLaunchKey = "scrytab.pendingSilentLaunch"
    static func resolve(arguments: [String], pendingSilentLaunch: Bool) -> LaunchIntent
}
```

`MenubarVisibilityPreference` is the small testable part of the preference contract. `Preferences.swift` remains application-only; it uses these constants when registering and reading the real preference.

`LaunchIntent.resolve(arguments:pendingSilentLaunch:)` returns `.silent` for the explicit silent argument, `--benchmark`, or a consumed one-shot Sparkle marker. It returns `.userInitiated` for `--logs=…` so Debug-scheme launches (which always pass `--logs=debug`) are not misclassified: run-from-Xcode stays a normal user launch. Recognized CLI commands do not need classification: `main.swift` handles them and exits before `App.run()`.

The Sparkle marker is an internal one-shot `UserDefaults` value, not a user preference. It must not enter `Preferences.defaultValues`, `ownedKeys`, import/export, or reset behavior.

The existing shared boundaries remain the owners of behavior:

- `Preferences.showMenubarIcon: Bool` reads `MenubarVisibilityPreference.key`.
- `Menubar.applyVisibilityPreference()` applies the stored value to the live status item.
- `PreferencesEvents.preferenceChanged(_:)` routes `showMenubarIcon` changes to `Menubar`.
- The existing `App.showSettingsWindow()` is the target for the main-menu Settings action.

## File map

Create:

- `src/preferences/MenubarVisibilityPreference.swift` — dependency-free preference key/default contract.
- `src/preferences/MenubarVisibilityPreferenceSpecs.md` — preference contract scenarios.
- `src/preferences/MenubarVisibilityPreferenceTests.swift` — pure preference contract tests.
- `src/macos/LaunchIntent.swift` — user-versus-silent launch classification and the shared silent-launch argument.
- `src/macos/LaunchIntentSpecs.md` — launch classification scenarios.
- `src/macos/LaunchIntentTests.swift` — pure launch classification tests.

Modify:

- `src/preferences/Preferences.swift` — register and expose `showMenubarIcon`.
- `src/preferences/settings-window/tabs/GeneralTab.swift` — add the Show menu bar icon switch and recovery guidance.
- `src/events/PreferencesEvents.swift` — apply visibility changes immediately.
- `src/Menubar.swift` — apply stored visibility, support native removal, and persist removal.
- `src/MainMenu.swift` — route the existing `⌘,` item to ScryTab Settings.
- `src/App.swift` — classify launch intent, open Settings for user cold launches, preserve warm reopen, and mark internal restarts silent.
- `src/macos/LoginItem.swift` — pass the silent-launch argument to the login LaunchAgent.
- `src/vendors/SparkleDelegate.swift` — mark any Sparkle update relaunch as the next silent launch.
- `scry-tab.xcodeproj/project.pbxproj` — add the new source/spec/test files to the appropriate groups and targets.
- `resources/l10n/Localizable.strings`, `resources/l10n/en.lproj/Localizable.strings`, and the six supported non-English localized outputs (`de`, `ja`, `fr`, `es`, `zh-CN`, `ru`) — generate and include all changed outputs in the eventual implementation commit. Do not hand-edit the source or generated English output before extraction.
- `PRODUCT_FEATURE_INVENTORY.md` — replace both stale icon-style claims, correct the stale first-launch Settings claim to onboarding, and document hidden-icon cold-launch recovery.
- `docs/FEATURES_MARKETING.md` — describe the menu bar icon as optional and remove the old style-selector claim.

Do not modify `src/preferences/PreferencesMigrations.swift` for this feature. No AltTab preference migration belongs in ScryTab.

## Task [1]: Add the ScryTab preference contract

**Description:** Add the new visibility preference to the existing preference registry and General Settings surface. The task does not change status-item behavior or launch behavior.

**Dependencies:** Blocked by none. Blocks Task 2 and Task 3.

**Files:** Create `src/preferences/MenubarVisibilityPreference.swift`, `src/preferences/MenubarVisibilityPreferenceSpecs.md`, `src/preferences/MenubarVisibilityPreferenceTests.swift`; Modify `src/preferences/Preferences.swift`, `src/preferences/settings-window/tabs/GeneralTab.swift`, `scry-tab.xcodeproj/project.pbxproj`.

**Interfaces:** Produces `MenubarVisibilityPreference.key`, `MenubarVisibilityPreference.defaultValue`, and `Preferences.showMenubarIcon: Bool`. Consumes the existing `Preferences.defaultValues`, derived `Preferences.ownedKeys`, `LabelAndControl.makeSwitch`, and General-tab design-system primitives.

**Execution Steps:**

- **Step 1:** Load and follow `swift-appkit-development` before modifying Swift/AppKit. Define the tiny dependency-free `MenubarVisibilityPreference` contract, then use its key/default constants in `Preferences.defaultValues` and `Preferences.showMenubarIcon`. Do not add any AltTab key or fallback read.
- **Step 2:** Add a General-tab row labelled “Show menu bar icon” using the existing switch binding for `showMenubarIcon`. Store the returned `Switch` in `GeneralTab.menuIconShownToggle: Switch?`, clear it in `cleanup()`, and refresh it with `setSilently(Preferences.showMenubarIcon ? .on : .off)` in `refreshControlsFromPreferences()`. Reuse the shared table and note primitives for one short localized recovery note explaining that launching ScryTab again or pressing `⌘,` while ScryTab is active opens Settings when the icon is hidden.
- **Step 3:** Add pure scenarios for the exact ScryTab key and default-visible value. Do not create tests that import the application-only `Preferences` implementation: the current Test target compiles a stub `Preferences`, and the Test scheme does not build the app target. Verify the real registry’s ownership, import/export, and reset behavior through the application Debug build and Task 5 acceptance checks.
- **Step 4:** Add `MenubarVisibilityPreference.swift` to both the application and unit-tests Sources phases; add its spec file to the project group and its test file to the unit-tests target. Keep `Preferences.swift` and `GeneralTab.swift` application-only.
- **Step 5:** Run the focused pure test and then the app build:
  `set -o pipefail && xcodebuild test -project scry-tab.xcodeproj -scheme Test -configuration Release -only-testing:unit-tests/MenubarVisibilityPreferenceTests | scripts/xcbeautify`
  followed by the copied Debug build sequence from `ai/build.sh`.
  Expected: the pure contract tests pass and the application build exits 0 with `** BUILD SUCCEEDED **`.

## Task [2]: Restore status-item visibility behavior

**Description:** Make the existing status item honor the new ScryTab preference, remain alive when hidden, and persist native Command-drag removal. The task does not add Settings entry points or restore icon-style selection.

**Dependencies:** Blocked by Task 1. Blocks Task 3.

**Files:** Modify `src/Menubar.swift`, `src/events/PreferencesEvents.swift`, `src/preferences/settings-window/tabs/GeneralTab.swift`.

**Interfaces:** Produces `Menubar.applyVisibilityPreference()`. Consumes `Preferences.showMenubarIcon` and the existing status item/menu.

**Execution Steps:**

- **Step 1:** Load and follow `swift-appkit-development` before modifying Swift/AppKit. Set the status item’s behavior to `.removalAllowed` before any `isVisible` write, including the initial visibility application.
- **Step 2:** Keep `loadAppIcon()` responsible only for loading and sizing the image. Remove its unconditional “visible” result and apply `Preferences.showMenubarIcon` after the item is configured.
- **Step 3:** Add `Menubar.applyVisibilityPreference()` to set `statusItem.isVisible` from `Preferences.showMenubarIcon` without recreating the item or menu. It must safely no-op before initialization.
- **Step 4:** Add `private static var isVisibleObserver: NSKeyValueObservation?` to `Menubar` and retain the observation there for the status item's lifetime; invalidate an existing token before replacing it. Observe `statusItem.isVisible` with `[.old, .new]` only after initial visibility has been applied. Use `guard change.oldValue == true, change.newValue == false else { return }`. Refresh `GeneralTab.menuIconShownToggle?.setSilently(.off)` for that transition, but write `Preferences.set(MenubarVisibilityPreference.key, "false")` only if the stored preference is still true, avoiding a duplicate write when Settings already persisted false. Never persist false-to-true or unchanged transitions. The optional switch reference safely no-ops when General is not built; a later pane build reads the stored preference.
- **Step 5:** Add a `showMenubarIcon` branch to `PreferencesEvents.preferenceChanged(_:)` so changing the switch updates the status item immediately while Settings is open, and refresh the stored switch state silently when native removal changes it.
- **Step 6:** Verify the actual AppKit behavior manually: hide from Settings, confirm the switch and status item agree, show again from Settings, Command-drag the item away, confirm the switch turns off without firing its action, relaunch, and confirm the menu item is absent/present according to the stored preference. Do not add a feature-local status-item abstraction solely for testing.
- **Step 7:** Run the copied build sequence from `ai/build.sh`:
  `scripts/codesign/unlock_local_keychain.sh`
  `xcodebuild -project scry-tab.xcodeproj -scheme Debug -configuration Debug -derivedDataPath DerivedData`
  Expected: exit 0 and `** BUILD SUCCEEDED **`.

## Task [3]: Make Settings reachable on every supported launch path

**Description:** Add explicit launch-source classification, wire `⌘,` to the custom Settings window, and distinguish user cold launches from login and internal-restart launches. The task does not create a global hotkey or change the existing warm reopen contract.

**Dependencies:** Blocked by Tasks 1 and 2. Blocks Task 4.

**Files:** Create `src/macos/LaunchIntent.swift`, `src/macos/LaunchIntentSpecs.md`, `src/macos/LaunchIntentTests.swift`; Modify `src/App.swift`, `src/MainMenu.swift`, `src/macos/LoginItem.swift`, `src/vendors/SparkleDelegate.swift`, `scry-tab.xcodeproj/project.pbxproj`.

**Interfaces:** Produces `LaunchIntent.resolve(arguments:pendingSilentLaunch:)`, `LaunchIntent.silentArgument`, `LaunchIntent.pendingSilentLaunchKey`, and the existing `App.showSettingsWindow()` as the main-menu target. Consumes `applicationShouldHandleReopen`, the existing `LoginItem` LaunchAgent, `App.restart()`, and the Sparkle updater delegate.

**Execution Steps:**

- **Step 1:** Load and follow `swift-appkit-development` before modifying Swift/AppKit. Implement `LaunchIntent.resolve(arguments:pendingSilentLaunch:)`: no arguments and logging-only arguments such as `--logs=debug` are `.userInitiated`; the exact silent argument, `--benchmark`, and a pending one-shot marker take precedence and yield `.silent`. Logging configures diagnostics, not launch intent. Recognized CLI commands exit through `CliClient.sendCommandAndProcessResponse` before `App.run()` and stay outside this contract. Cover no arguments, logging-only, each silent cause, and logging combined with each silent cause in the specs and tests. Add `LaunchIntent.swift` to both application and unit-tests Sources phases, `LaunchIntentTests.swift` to unit-tests Sources only, and the spec to the project group. Keep `App.swift` and the Sparkle delegate application-only.
- **Step 2:** In `applicationDidFinishLaunching`, after successful `CliEvents.claimAdmission()` and preference initialization, consume and remove the pending Sparkle marker and resolve launch intent once into app-owned state, before permission gating. An instance rejected by admission must not consume it. After runtime initialization, capture `hadPendingSettingsRoute = pendingSettingsRoute != nil` before `showInitialTourIfNeeded()` or `showPendingSettingsWindowIfNeeded()` can consume it. Preserve the existing tour and pending-route handling. Only when no initial tour was shown, `hadPendingSettingsRoute == false`, intent is `.userInitiated`, and the icon preference is hidden, call `App.showSettingsWindow(route: .general)` once. Do not defer this automatic fallback until tour completion. Keep no-argument `showSettingsWindow()` opening Appearance for existing menu and warm-reopen callers.
- **Step 3:** Change the LoginAgent plist from a bare `Program` launch to `ProgramArguments` containing the executable path and `LaunchIntent.silentArgument`. This makes login startup explicitly silent.
- **Step 4:** Change `App.restart()` to pass the same marker through `/usr/bin/open -n ... --args --scrytab-silent-launch`. The marker suppresses only automatic Settings; it must not disable existing onboarding, reset, import, or language-change behavior.
- **Step 5:** Read `docs/RELEASE_BLOCKERS.md` before touching Sparkle. In `SparkleDelegate.updaterWillRelaunchApplication(_:)`, set `LaunchIntent.pendingSilentLaunchKey` in `UserDefaults.standard` for every update relaunch, including manual “Install and Relaunch”. Call `synchronize()` at this handoff before returning; check its result and log failure without blocking the update or claiming durable success. At the next admitted startup, read and remove the marker, synchronizing the removal as well. Keep these bounded handoff flushes out of routine preference writes. Normal persistence must suppress Settings for one launch only. Accepted failure boundary: a failed flush can miss or repeat suppression, and an aborted update after the callback can leave the marker for the next user launch. Document these limits rather than claiming an atomic handoff or adding a separate persistence service. Keep the marker outside the preference registry, import/export, and reset ownership.
- **Step 6:** Replace the dead `orderFrontPreferencesPanel:` action using a `MainMenu.item` overload that accepts `Selector`, preserving the existing String overload for unrelated menu items. Pass `#selector(App.showSettingsWindow as () -> Void)` and target `App.self`, following the existing Menubar call's overload disambiguation. Do not use `Selector("showSettingsWindow")`. Keep the existing `⌘,` equivalent and no-argument method; do not add a forwarding action wrapper.
- **Step 7:** Retain `applicationShouldHandleReopen` as the warm-relaunch path to `App.showSettingsWindow()`. Confirm that this path also works when `statusItem.isVisible == false`, because the status item object remains initialized.
- **Step 8:** Run the focused LaunchIntent tests and the copied Debug build sequence from `ai/build.sh`.
  Expected: all pure launch-classification tests pass and the application build exits 0 with `** BUILD SUCCEEDED **`.

## Task [4]: Localize and correct product documentation

**Description:** Add the user-facing copy and update repository documentation so it describes ScryTab’s visibility-only feature accurately. No AltTab compatibility language is added.

**Dependencies:** Blocked by Tasks 1 and 3. Blocks Task 5.

**Files:** Modify the Swift source that introduces the strings, `resources/l10n/Localizable.strings`, `resources/l10n/en.lproj/Localizable.strings`, the localized outputs for `de`, `ja`, `fr`, `es`, `zh-CN`, and `ru`, `PRODUCT_FEATURE_INVENTORY.md`, and `docs/FEATURES_MARKETING.md`. English is generated by the workflow but is still a changed file to inspect and include in the eventual implementation commit.

**Interfaces:** Produces localized strings for the General-tab label and recovery note. Consumes the project’s existing localization workflow and product-surface documentation.

**Execution Steps:**

- **Step 1:** Add `NSLocalizedString` source strings for “Show menu bar icon” and the Settings-recovery note in `GeneralTab.swift`. Then run the repository extraction step. Do not hand-edit `resources/l10n/Localizable.strings` or the generated English output before extraction.
- **Step 2:** Translate the missing entries for the six supported languages (`de`, `ja`, `fr`, `es`, `zh-CN`, `ru`) and apply them with `scripts/l10n/apply_translations.ts`, following `translate-missing-l10n`. Keep `⌘,` and any format specifiers unchanged in every translation.
- **Step 3:** Correct all three stale `PRODUCT_FEATURE_INVENTORY.md` claims: the status-item entry and General Settings entry describe optional visibility and persisted Command-drag removal without an icon-style selector; the first-launch entry describes the onboarding tour guarded by `initialExperienceShown`, not Settings guarded by the retained `settingsWindowShownOnFirstLaunch` key. Add the new rule that a user cold launch opens General Settings only while the icon is hidden and no onboarding or explicit pending route takes precedence. Document silent login, internal restart, and both automatic/manual Sparkle update relaunches.
- **Step 4:** Update `docs/FEATURES_MARKETING.md` to remove the outlined/filled/colored claim and describe the icon as optional.
- **Step 5:** Run `git diff --check` and inspect all localization diffs. Expected: no whitespace errors, no missing supported-language entries, and no AltTab preference names introduced into ScryTab-facing copy.

## Task [5]: Verify lifecycle, persistence, and regression boundaries

**Description:** Verify the complete feature across preference, status-item, Settings, launch, localization, and documentation boundaries. Resolve findings before implementation is considered complete.

**Dependencies:** Blocked by Tasks 2, 3, and 4. Blocks completion.

**Files:** Modify only files needed to resolve verified defects; do not broaden the feature.

**Interfaces:** Consumes the complete implementation and produces build/test evidence plus a lifecycle QA result.

**Execution Steps:**

- **Step 1:** Run the spec/test consistency audit for the new preference and launch-intent triads. Expected: no orphan files, orphan scenarios, or scenario/comment drift.
- **Step 2:** Run `scripts/run_tests.sh`. Remember that the Test scheme validates the unit-tests target only; it is not evidence that application-only files compile. Expected: exit 0 and the Test scheme succeeds.
- **Step 3:** Run the exact build sequence copied from `ai/build.sh`:
  `scripts/codesign/unlock_local_keychain.sh`
  `xcodebuild -project scry-tab.xcodeproj -scheme Debug -configuration Debug -derivedDataPath DerivedData`
  Expected: exit 0 and `** BUILD SUCCEEDED **`.
- **Step 4:** Have the user exercise this acceptance matrix on a clean preference domain and an existing domain, or obtain explicit permission before launching or controlling the app for QA. No-window expectations refer to the new automatic Settings fallback, not existing permission/onboarding/consent windows. Disable the separate Debug QA `openSettingsOnLaunch` override when checking these cases; logging alone must not suppress recovery.
  - New install: the icon is visible by default.
  - General switch off: the icon disappears immediately while Settings remains open.
  - General switch on: the same icon and menu reappear immediately.
  - Command-drag removal: the preference becomes hidden and remains hidden after relaunch.
  - User cold launch from an app launcher while the icon is hidden: Settings opens after startup completes.
  - User cold launch while the icon is visible: existing no-window launch behavior is unchanged.
  - User warm relaunch while ScryTab is running: Settings opens.
  - `⌘,` while ScryTab is active: Settings opens even when the icon is hidden.
  - Login-item launch: no Settings window appears; existing background startup remains intact.
  - Import/export/reset: the new ScryTab key is accepted, exported, and restored to visible on reset.
  - First-launch onboarding and internal restart: no duplicate or stray Settings window appears.
  - Automatic Sparkle-update relaunch: no Settings window appears after the update restarts ScryTab.
  - All supported languages: the switch and recovery note are present, readable, and accessible.
- **Step 5:** Confirm the implementation references only the new ScryTab key. Existing historical migration code may still contain AltTab-derived names, but the new preference, Menubar behavior, Settings UI, and launch logic must not read them.
- **Step 6:** Apply `swift-appkit-code-review` to the final Swift/AppKit diff. Resolve lifecycle, KVO, target/action, macOS compatibility, accessibility, persistence, and test findings before completion.
- **Step 7:** Inspect `git diff --stat`, `git diff`, and `git status --short`. Expected: only the planned files are changed, no release-blocker file is modified, and no app launch or server-management command was added to the development workflow.

## Plan simplicity review

**Goal:** Let users hide ScryTab’s menu bar icon without losing a reliable path to Settings.

**Smallest path:** One new ScryTab boolean, one tiny shared preference contract, existing `PreferencesEvents` and `Menubar` boundaries, existing warm reopen, a direct `⌘,` action, and one explicit/one-shot silent-launch marker for login, restart, and automatic-update paths.

**Plan shape:** lean

**Highest-leverage cut:** none — native Command-drag persistence is part of restoring the old behavior properly, the tiny preference contract is required by the split test target, and `LaunchIntent` is the smallest shared contract that keeps login/restart/update behavior deterministic and testable.

**Why this cut:** No additional feature-local service, global hotkey system, URL scheme, icon-style model, or AltTab migration is included.

**Also defer:**

- AltTab preference compatibility and data migration.
- Restoring outlined, filled, or colored menu bar icon choices.
- A configurable global Settings hotkey.
- Any change to ScryTab’s core switcher shortcuts or licensing/release configuration.

**Keep:**

- Default-visible behavior for new ScryTab installs.
- Live hide/show while Settings is open.
- Native removal persistence.
- User cold-launch, warm-reopen, `⌘,`, login, and internal-restart coverage.

**Verdict:** approve

**Required before coding:**

- Confirm the exact user-facing label and recovery note translations during implementation.
- Preserve the clean ScryTab product boundary: do not reuse or migrate AltTab preference keys.
- Build the application target after every task that changes application-only Swift; a passing Test scheme alone is insufficient.
