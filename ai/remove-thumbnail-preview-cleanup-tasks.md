# Remove Window-Screenshot (Thumbnails) Style And Screen Recording

Last mapped: 2026-06-21. Revised scope: keep BOTH the **App Icons** grid view and the **Titles** list view as top-level appearance options. Remove ONLY the `thumbnails` window-screenshot style and the entire screen-capture / Screen Recording pipeline that fed it.

## Target UX

The switcher keeps two appearance styles, selectable from the top of the Appearance tab exactly as today:

- **App Icons** — grid of large app icons (the "thumbnail view" the user wants to keep).
- **Titles** — dense list rows: app icon, title, status indicators.

Both keep the existing supporting options:

- title-display choices (Window Title / Application Name / Application Name - Window Title) via `showTitles`
- `titleTruncation`
- per-shortcut tab grouping (`showTabsAsWindows`)
- per-shortcut appearance overrides (style, size, theme, shortcut style)
- size and theme

What is removed:

- the `thumbnails` appearance style (window screenshots) and any UI that selects it
- all Screen Recording permission requests, prompts, callouts, and skip state
- the screenshot capture pipeline (ScreenCaptureKit / SkyLight capture, background capture)
- the selected-window preview overlay (`PreviewPanel`) and preview-fade animation
- thumbnail-only rendering (thumbnail images, thumbnail shadows, traffic-light hover controls)

The app should not request, probe, or mention Screen Recording, and should never capture window screenshots or render window previews.

## Constraints

- Follow `AGENTS.md`: no browser automation, no server commands, no Xcode UI.
- Keep Developer ID, Team ID, bundle ID, signing, and keychain behavior stable.
- Use pure AppKit Swift code, no SwiftUI or Interface Builder.
- Keep the triad pattern where code/spec/test coverage exists.
- Copy and run the command from `ai/build.sh` after code changes. For final verification, also run `scripts/run_tests.sh` unless the task only changes docs.

## What Stays (do NOT remove)

- `AppearanceStylePreference` enum — but reduced from three cases to two (`appIcons`, `titles`). It remains a real runtime enum.
- The appearance-style selector in `AppearanceTab` (now two options instead of three).
- Per-shortcut `appearanceStyleOverride*` keys and the override row in `ShortcutEditor.AppearancePane`.
- The Pro feature `ProFeature.appIconsAndTitlesStyle` and its monetization/prompt stack (`ProTransitionManager`, `ResolvedReason.titlesStyle`, `rememberedAppearanceStyle`, usage stat `triggersTitles`, Day 1/Day 15/Upgrade copy). **Resolved gating model:** removing `thumbnails` removed the only free style, so **App Icons is now the free default and only Titles is Pro-gated** (`PreferenceGate(freeEquivalent: .appIcons, isProValue: { $0 == .titles })`). App Icons usage is therefore NOT a Pro-usage signal — `triggersAppIcons` / `usedAppIconsOrTitles()` and the dead `ResolvedReason.appIconsStyle` path were removed. The Pro layer otherwise stays, minus copy that references thumbnails/previews.
- App-icon image loading (the background queue that decodes icons).

## Compilation-Safe Sequencing

`thumbnails` was removed before ScryTab had production users. Do not carry a legacy migration for old
`appearanceStyle` indexes or old exported settings plists. Removing the enum case requires, in one
compile-safe change set:

1. Change the default style to `.appIcons` and override defaults to `.appIcons`.
2. Remove the `.thumbnails` enum case and every `== .thumbnails` / `!= .thumbnails` branch in the renderer.
3. Delete the capture pipeline and preview panel.

## Current Coupling Map

- Defaults and effective preferences: `src/preferences/Preferences.swift` (default `.thumbnails`, `effectiveAppearanceStyle`, `effectivePreviewSelectedWindow`, `usesThumbnails`)
- Preference-change reset dispatch: `src/events/PreferencesEvents.swift`
- Macro enums: `src/preferences/MacroPreferences.swift` (`AppearanceStylePreference` three cases)
- Pro-gated appearance style: `src/preferences/PreferenceDefinition.swift`, `src/pro/ProFeature.swift`, `src/pro/scheduling/ProTransitionManager.swift`, `src/pro/scheduling/ProTransitionState.swift`
- Startup permission gate: `src/macos/SystemPermissions.swift`, `src/secondary-windows/permission-window/PermissionsWindow.swift`, `src/secondary-windows/permission-window/PermissionView.swift`
- Menubar Screen Recording callout: `src/Menubar.swift`, `src/macos/PermissionCalloutResolver.swift`
- Screenshot capture and preview: `src/switcher/state/WindowThumbnails.swift`, `src/events/WindowCaptureEvents.swift`, `src/switcher/PreviewPanel.swift`
- Tile and panel rendering: `src/switcher/Appearance.swift`, `src/switcher/main-window/TilesPanel.swift`, `src/switcher/main-window/TilesPanelBackgroundView.swift`, `src/switcher/main-window/TilesView.swift`, `src/switcher/main-window/TileView.swift`, `src/switcher/main-window/TileOverView.swift`, `src/switcher/main-window/TileFontIconView.swift`, `src/events/CursorEvents.swift`, `src/kit/TrafficLightButton.swift`
- Settings UI: `src/preferences/settings-window/tabs/appearance/AppearanceTab.swift`, `src/preferences/settings-window/tabs/appearance/CustomizeStyleSheet.swift`, `src/preferences/settings-window/tabs/appearance/AnimationsSheet.swift`, `src/preferences/settings-window/tabs/GeneralTab.swift`, `src/preferences/settings-window/tabs/controls/ShortcutEditor.swift`, `src/preferences/settings-window/tabs/controls/ControlsTab.swift`
- Tests/specs to update: `src/macos/PermissionCalloutResolverSpecs.md`, `src/macos/PermissionCalloutResolverTests.swift`, `src/switcher/AppearanceSpecs.md`, `src/switcher/AppearanceTests.swift`, `src/preferences/PreferencesMigrationsSpecs.md`, `src/preferences/PreferencesMigrationsTests.swift`
- Resources and docs: `resources/illustrations/thumbnails_*`, `resources/l10n/**/Localizable.strings`, `PRODUCT_FEATURE_INVENTORY.md`, `docs/contributing.md`

## Task 1 - Freeze The New Product Contract

Objective: make the desired behavior explicit before deleting code.

Work:

- Update `src/switcher/AppearanceSpecs.md` and `src/switcher/AppearanceTests.swift` to describe two styles only (App Icons grid, Titles list). Remove any sizing/spec scenarios specific to `.thumbnails`.
- Do not add migration scenarios for the removed thumbnails style. There are no production installs or
  supported legacy settings exports to preserve.
- Update `PRODUCT_FEATURE_INVENTORY.md` to remove the window-screenshot/thumbnail/preview/Screen Recording claims while keeping App Icons and Titles styles documented.

Acceptance:

- Specs describe two appearance styles (App Icons, Titles) and no window-screenshot style.
- No spec promises thumbnail screenshots, selected-window previews, or Screen Recording recovery.
- No thumbnail-removal migration tests or compatibility behavior remain.

## Task 2 - Reduce Appearance Preferences To Two Styles

Objective: remove the `thumbnails` style value and all preview/capture preferences while keeping the App Icons + Titles selection model.

Files:

- `src/preferences/MacroPreferences.swift`
- `src/preferences/Preferences.swift`
- `src/preferences/PreferenceDefinition.swift`
- `src/events/PreferencesEvents.swift`

Work:

- In `AppearanceStylePreference`, remove the `thumbnails` case. Keep `appIcons` and `titles` (in that order). Update `image(...)` / localized titles accordingly. Keep the enum as a live runtime preference.
- Change the `appearanceStyle` default from `.thumbnails` to `.appIcons` in `Preferences.defaultValues`, and change the `appearanceStyleOverride*` defaults from `.thumbnails` to `.appIcons`.
- Remove default keys and getters for the preview/capture-only preferences:
  - `previewFocusedWindow`
  - `previewFocusedWindowOverride*`
  - `previewFadeInAnimation`
  - `hideThumbnails`
  - `captureWindowsInBackground`
  - `screenRecordingPermissionSkipped`
- Keep `appearanceStyle`, `appearanceStyleOverride*`, `hideColoredCircles`, `showTitles`, `titleTruncation`, `showTabsAsWindows`, `showAppsOrWindows`, size, theme, and shortcut-style preferences.
- Remove `previewFocusedWindow` from `appearanceOverrideBaseNames` and `overrideToGlobalKey`; keep `appearanceStyleOverride`, size, theme, and after-release shortcut style.
- Remove `effectivePreviewSelectedWindow(_:)` and the `usesThumbnails` computed flag. Keep `effectiveAppearanceStyle(_:)` (it now returns `.appIcons` or `.titles`).
- Do not add a migration for the removed thumbnails style or its removed preview/capture preferences.
  Fresh defaults and `Preferences.ownedKeys` are the only supported settings shape.
- Keep `ProGatedPreferences.appearanceStyle` and `appearanceStyleOverride0` (Titles is Pro-gated; App Icons is the free equivalent).
- Keep `appearanceStyle` in `PreferencesEvents.preferencesRequiringUiReset`; remove `previewFocusedWindow`/`previewFadeInAnimation` from any reset lists.

Acceptance:

- `AppearanceStylePreference.allCases` has exactly two cases (`appIcons`, `titles`).
- `rg -n "previewFocusedWindow|previewFadeInAnimation|screenRecordingPermissionSkipped|captureWindowsInBackground|hideThumbnails|usesThumbnails|migrateAppearanceStyleDropThumbnails" src/preferences src/events/PreferencesEvents.swift` returns no references.
- Imported settings cannot re-enable removed preview/capture keys because those keys are not owned preferences.

## Task 3 - Make Startup Accessibility-Only

Objective: remove all Screen Recording permission requirements and prompts.

Files:

- `src/macos/SystemPermissions.swift`
- `src/secondary-windows/permission-window/PermissionsWindow.swift`
- `src/secondary-windows/permission-window/PermissionView.swift`
- `src/Menubar.swift`
- `src/macos/PermissionCalloutResolver.swift`
- `src/macos/PermissionCalloutResolverSpecs.md`
- `src/macos/PermissionCalloutResolverTests.swift`

Work:

- Delete `ScreenRecordingPermission` and the `ScreenCaptureKit.SCShareableContent` import from `SystemPermissions.swift`.
- Change pre-startup gating to require Accessibility only.
- Remove Screen Recording rows, status updates, skip checkbox, and Screen Recording deep link from `PermissionsWindow` / `PermissionView`.
- Remove `PermissionCalloutResolver.swift`, its tests/spec, and all project file references (it exists only to recover Screen Recording).
- Remove the menubar permission callout custom view and "Grant permission" restart path from `Menubar.swift`.
- Keep "Check permissions..." if it still opens the Accessibility permission window; adjust copy so it does not imply multiple permissions.

Acceptance:

- First launch cannot display a Screen Recording permission row.
- Startup proceeds when Accessibility is granted, regardless of Screen Recording state.
- `rg -n "ScreenRecordingPermission|Screen Recording|Privacy_ScreenCapture|PermissionCalloutResolver|screenRecordingPermissionSkipped" src scry-tab.xcodeproj/project.pbxproj` has no live references.

## Task 4 - Delete The Screenshot Capture And Preview Pipeline

Objective: remove all APIs and state used only for window screenshots and selected-window previews. (App Icons and Titles never used these.)

Files:

- `src/switcher/state/WindowThumbnails.swift`
- `src/events/WindowCaptureEvents.swift`
- `src/switcher/PreviewPanel.swift`
- `src/App.swift`
- `src/main.swift`
- `src/switcher/state/Window.swift`
- `src/switcher/state/Windows.swift`
- `src/switcher/state/Applications.swift`
- `src/util/BackgroundWork.swift`
- `src/secondary-windows/DebugMenu.swift`
- `src/events/ScreenLockEvents.swift`
- `src/macos/api-wrappers/SkyLight.framework.swift`
- `scry-tab.xcodeproj/project.pbxproj`

Work:

- Delete `WindowThumbnails.swift`, `WindowCaptureEvents.swift`, and `PreviewPanel.swift`.
- Remove `_ = PreviewPanel()`, all `WindowThumbnails.previewSelectedIfNeeded()` calls, all `WindowThumbnails.refreshAsync(...)` calls, and `RefreshCausedBy`.
- Remove `Window.thumbnail`, `Window.refreshThumbnail(_:)`, and preview update hooks.
- Remove `WindowCaptureScreenshots.cachedSCWindows` cleanup from `Windows.removeWindows`.
- Remove `Applications.screenshotThrottler` if nothing else uses it.
- Remove `ActiveWindowCaptures` and `makeSureAllCapturesAreFinished()` once no capture operations remain.
- Remove `ScreenCaptureKit`, `SCScreenshotManager`, `SCStreamConfiguration`, `CGSHWCaptureWindowList`, and `SLSRequestScreenCaptureAccess` declarations if they become unused.
- Keep the app-icon decode queue. If it is named `BackgroundWork.screenshotsQueue` and is still used for icon processing, rename it to `imageProcessingQueue` and update `DebugMenu` and comments.
- Update `ScreenLockEvents` comments after capture guards are gone.
- Remove deleted files from `scry-tab.xcodeproj/project.pbxproj`.

Acceptance:

- `rg -n "WindowThumbnails|PreviewPanel|WindowCapture|ScreenCaptureKit|SCScreenshotManager|CGSHWCaptureWindowList|ActiveWindowCaptures|makeSureAllCapturesAreFinished|screenshotsQueue" src scry-tab.xcodeproj/project.pbxproj` has no live capture references. A renamed image-processing queue is acceptable.
- App termination no longer waits for screenshot work.
- App icon loading still works.

## Task 5 - Strip Thumbnail Rendering, Keep App Icons + Titles Layouts

Objective: remove the window-screenshot rendering path from the tiles while keeping both the App Icons grid layout and the Titles list layout intact.

Files:

- `src/switcher/Appearance.swift`
- `src/switcher/AppearanceTestable.swift`
- `src/switcher/main-window/TilesPanel.swift`
- `src/switcher/main-window/TilesPanelBackgroundView.swift`
- `src/switcher/main-window/TilesView.swift`
- `src/switcher/main-window/TileView.swift`
- `src/switcher/main-window/TileOverView.swift`
- `src/switcher/main-window/TileUnderLayer.swift`
- `src/switcher/main-window/TileFontIconView.swift`
- `src/events/CursorEvents.swift`
- `src/kit/TrafficLightButton.swift`

Work:

- Remove the `thumbnailsSize` layout path. Keep `appIconsSize` and `titlesSize` paths. Wherever code branches on `== .thumbnails` or `!= .thumbnails`, drop the thumbnails branch and keep the App Icons / Titles behavior.
- Keep `AppearanceSizePreference` and the App Icons vs Titles sizing/spacing distinctions (the `.appIcons` center-aligned icon-grid layout and the `.titles` left-aligned row layout both remain).
- Remove `TileView.thumbnail`, thumbnail shadows, thumbnail sizing helpers (`maxThumbnailsWidth`, `maxThumbnailsHeight`, `thumbnailsWidth`, `thumbnailsHeight`, `thumbnailUnderLayer`, `thumbnailOverView`), thumbnail fallback-to-icon logic, and all thumbnail positioning code. Where Titles/App Icons share a constant currently named after thumbnails, rename it to a neutral list/tile name.
- Keep App Icons label-hover behavior and the App Icons grid row-width handling — these are App Icons features, not thumbnail features. Only remove width/positioning special cases that exist solely for the screenshot layout.
- In `TilesPanelBackgroundView`: keep the `.appIcons` Liquid Glass path (macOS 26 private/clear variant for App Icons is an App Icons feature). Only remove any `requiredEffectViewKind()` / `makeEffectView(for:)` branch that exists solely for `.thumbnails`.
- Keep `TileFontIconView` badge logic for App Icons (it is not thumbnail-specific).
- Remove thumbnail traffic-light hover controls (`TileOverView.showWindowControls`). Delete `TrafficLightButton.swift` only if no other usage remains; App Icons/Titles do not use traffic-light hover, so this should be removable.
- Update `CursorEvents`: remove routing that targets the thumbnail overlay / `findButtonUnderPointer()` for traffic-light buttons. Pointer hit-testing should target tile rows and search. Keep mouse-hover tile selection.

Acceptance:

- Switcher renders correctly in both App Icons and Titles styles; thumbnail rendering is gone.
- `rg -n "thumbnail|Thumbnails|maxThumbnails|hideThumbnails|showWindowControls|TrafficLightButton" src/switcher src/kit` returns no live runtime references (deliberate historical comments excepted).
- `rg -n "\.appIcons|\.titles" src/switcher` still returns the retained style branches.
- Both styles still support the title display choices from `ShowTitlesPreference`.

## Task 6 - Clean Up Settings (Remove Thumbnails + Preview Controls Only)

Objective: remove dead preview/capture controls and drop the thumbnails option from the style selector, keeping the App Icons + Titles selector and their controls.

Files:

- `src/preferences/settings-window/tabs/appearance/AppearanceTab.swift`
- `src/preferences/settings-window/tabs/appearance/CustomizeStyleSheet.swift`
- `src/preferences/settings-window/tabs/appearance/AnimationsSheet.swift`
- `src/preferences/settings-window/tabs/GeneralTab.swift`
- `src/preferences/settings-window/tabs/controls/ShortcutEditor.swift`
- `src/preferences/settings-window/tabs/controls/ControlsTab.swift`
- settings search index files, if separate

Work:

- Keep the appearance-style selector but render only two options: App Icons and Titles. Titles keeps its Pro badge; App Icons is the free default. Remove the thumbnails card/radio option.
- Remove the "Preview selected window" global row and per-shortcut override row.
- Remove the "Fade in animation of Preview" row from `AnimationsSheet` and remove `previewFadeInAnimation` from the sheet search index.
- Remove the "Capture windows in the background" row from General.
- Keep "Hide colored circles on mouse hover" (`hideColoredCircles`) — it applies to the App Icons / Titles status dots, not to thumbnails. (If verification shows it only ever affected thumbnail traffic-lights, remove it; otherwise keep.)
- Keep these list/grid controls: `showTitles`, `titleTruncation`, `hideStatusIcons`, `hideSpaceNumberLabels`, `appearanceSize`, `appearanceTheme`, `shortcutStyle`, `showOnScreen`.
- Keep `CustomizeStyleSheet`, but remove any thumbnails-specific illustration/option. Keep the App Icons and Titles illustrations.
- Keep the per-shortcut appearance style override row in `ShortcutEditor.AppearancePane` (now offering App Icons / Titles). Remove the per-shortcut preview override row.
- Update `ControlsTab.removableShortcutPreferences` so deleting shortcuts cleans up the remaining override keys (style, size, theme, shortcut style) and no longer references preview override keys.

Acceptance:

- Settings search does not surface removed Screen Recording, thumbnail, or preview settings.
- Appearance tab shows a two-option style picker (App Icons, Titles).
- `ShortcutEditor.AppearancePane` keeps the style override row and has no preview row.

## Task 7 - Trim Pro / UsageStats Copy Only (Keep The Feature)

Objective: the App Icons & Titles Pro feature stays. Only remove copy/strings that promised thumbnails or window previews.

Files:

- `src/pro/ProFeatureCopy.swift`
- `src/pro/scheduling/Day1WelcomeLetterWindow.swift`
- `src/pro/scheduling/Day15FullUpgradeWindow.swift`
- `src/pro/scheduling/Day15HardGatePopover.swift`
- `src/preferences/settings-window/tabs/UpgradeTab.swift`

Keep (Titles is Pro; App Icons is the free default — see resolved gating model above):

- `ProFeature.appIconsAndTitlesStyle` and its gating
- `ResolvedReason.titlesStyle` and `ProTransitionManager` style mapping (the `.appIconsStyle` path was removed as dead code — App Icons can't be hard-gated when it's free)
- `rememberedAppearanceStyle` / `rememberedAppearanceStyleOverride`
- `ProGatedPreferences.appearanceStyle` / `appearanceStyleOverride0`
- `UsageStats` `triggersTitles` and the "Titles appearance" name (the `triggersAppIcons` key, `usedAppIconsOrTitles()`, and "App Icons appearance" name were removed — App Icons is free, so it isn't a Pro-usage signal)

Work:

- Audit `ProFeatureCopy.appIconsAndTitles` and `ProFeatureCopy.autoSize`. Rewrite any text that references "high-quality thumbnails", "window previews", or "larger previews with few windows" so the copy describes App Icons / Titles styling and sizing without screenshots.
- Update Day 1, Day 15, Upgrade tab, and Day15HardGatePopover copy to drop thumbnail/preview promises while still selling App Icons & Titles.
- Verify `ProTransitionManager` `rememberedAppearanceStyle` index handling still maps correctly after the enum dropped to two cases (the snapshot stores an `Int` index; ensure it reads against the new `allCases`).

Acceptance:

- Pro lock/unlock for App Icons & Titles still works; the style snapshot/ghost-outline still resolves with two cases.
- `rg -n "high-quality thumbnails|window previews|larger previews|Preview selected" src/pro src/preferences resources/l10n` returns no live product copy after l10n cleanup.

## Task 8 - Remove Thumbnail Illustrations And Dead Localization

Objective: delete resources and strings that only supported the removed screenshot/preview surfaces. Keep App Icons and Titles illustrations and strings.

Files:

- `resources/illustrations/*`
- `resources/l10n/**/Localizable.strings`
- `scripts/l10n/extract_l10n_strings.sh`
- `scripts/l10n/apply_translations.ts`
- `docs/contributing.md`
- `PRODUCT_FEATURE_INVENTORY.md`

Work:

- Delete unused illustrations: all `resources/illustrations/thumbnails_*`. Keep `app_icons_*` and `titles_*` (both styles are still selectable and still illustrated in settings).
- Remove stale l10n keys for: Screen Recording prompts, window thumbnails, "Preview selected window", preview fade animation, background capture, "high-quality thumbnails". Keep "App Icons", "Titles", and "Titles appearance".
- Refresh source strings using the repo l10n scripts, then prune translations consistently.
- Update `docs/contributing.md`: delete thumbnail layout / thumbnail drag-drop manual QA sections (or rewrite for App Icons / Titles). Keep App Icons and Titles QA.
- Update `PRODUCT_FEATURE_INVENTORY.md` to remove the screenshot/preview/Screen Recording features and document App Icons + Titles as the two surviving styles.

Acceptance:

- Bundle resources contain no `thumbnails_*` illustrations; `app_icons_*` and `titles_*` remain.
- `rg -n "thumbnail|Screen Recording|Window previews|Capture windows in the background|high-quality thumbnails|Preview selected" resources/l10n docs PRODUCT_FEATURE_INVENTORY.md` returns no live product claims (intentional historical changelog entries excepted).
- App Icons and Titles strings still resolve.

## Task 9 - Update Project Membership And Build Configuration

Objective: make sure deleted files are not still compiled, copied, or indexed.

Files:

- `scry-tab.xcodeproj/project.pbxproj`
- `config/*.xcconfig`
- scripts under `scripts/`

Work:

- Remove deleted Swift files (`WindowThumbnails`, `WindowCaptureEvents`, `PreviewPanel`, `PermissionCalloutResolver` + its tests, and `TrafficLightButton` if removed) from PBX file references and build phases.
- Remove deleted `thumbnails_*` resources from PBX resources. Keep `app_icons_*` and `titles_*` resources.
- Confirm no stale ScreenCaptureKit linker/resource settings remain. Current mapping found no direct ScreenCaptureKit framework entry; expected no-op unless a later search finds one.
- Check scripts for resource lists or l10n assumptions that mention removed keys/illustrations.

Acceptance:

- `xcodebuild` does not reference deleted files.
- `rg -n "WindowCaptureEvents|WindowThumbnails|PreviewPanel|PermissionCalloutResolver|thumbnails_.*heic" scry-tab.xcodeproj scripts config` returns no stale membership.
- `app_icons_*` and `titles_*` references remain present.

## Task 10 - Final Verification

Objective: prove the cleanup is end to end.

Commands:

```bash
./scripts/run_tests.sh
```

Then copy and run the command in `ai/build.sh`:

```bash
xcodebuild \
  -project scry-tab.xcodeproj \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData
```

Run cleanup searches (these strings must be gone; App Icons / Titles strings must remain):

```bash
rg -n "ScreenRecordingPermission|Screen Recording|Privacy_ScreenCapture|screenRecordingPermissionSkipped|PermissionCalloutResolver|WindowThumbnails|PreviewPanel|WindowCapture|ScreenCaptureKit|SCScreenshotManager|CGSHWCaptureWindowList|ActiveWindowCaptures|previewFocusedWindow|previewFadeInAnimation|captureWindowsInBackground|hideThumbnails|usesThumbnails|migrateAppearanceStyleDropThumbnails|thumbnails_.*heic|high-quality thumbnails|larger previews" src scry-tab.xcodeproj resources docs PRODUCT_FEATURE_INVENTORY.md

# Sanity check: these MUST still exist
rg -n "case appIcons|case titles|appIconsAndTitlesStyle|triggersTitles" src
```

Acceptance:

- Tests pass.
- Debug build passes.
- First cleanup search has no live runtime references.
- Second sanity search still returns the retained App Icons + Titles style and its Pro feature.
- The app no longer asks for Screen Recording on fresh launch.
- The switcher offers two appearance styles — App Icons (icon grid) and Titles (list) — selectable from the top of the Appearance tab, with no window-screenshot style and no preview overlay.
