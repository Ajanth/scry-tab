# Animated Onboarding Tour Implementation Plan

### User Story: Learn ScryTab Through a Self-Contained Tour

**Goal:** After Accessibility permission is granted on a new installation, show a polished native tour that explains ScryTab's core value without navigating through or highlighting the real application UI. Focus Sets leads the story through three familiar contexts, followed by concise Appearance and Controls demonstrations.

**Scope:**
- Covers: A three-page AppKit tour; demo-only Entertainment, Work, and Side Projects Focus Sets; finite animated illustrations; local Appearance and Controls demonstrations; skip/back/next/replay behavior; keyboard and VoiceOver support; Reduce Motion/Transparency and appearance changes; first-install presentation; status-menu replay; handoff to the existing Focus Sets page.
- Does not cover: Persisting sample Focus Sets; invoking the production switcher; changing real preferences during demonstrations; reordering Settings; automatically showing the tour to existing installations; opening the Add Focus Set sheet directly; analytics; or new animation frameworks.

**Primary User Flow:** A new user grants Accessibility, sees the Focus Sets tour page, explores three demo contexts, advances to Appearance, advances to Controls, and chooses Explore Focus Sets. The tour closes, its completion marker is recorded, the existing Focus Sets Settings page opens, and deferred crash-report consent is then presented. Skip or closing the window records the tour as seen and continues launch without reopening it on later launches.

**UI Structure:** One centered native window contains a generously inset page host, three-step progress label, and native footer actions. Focus Sets uses one localization-safe category story rail aligned over a single centered switcher surface whose app icons match the landing-page demonstration. Appearance uses the shared chip treatment for App Icons/Titles and Controls retains the miniature switcher and keycaps. Only one page hierarchy is resident at a time.

**User Interactions:** Focus Sets autoplays one finite Entertainment → Work → Side Projects pass, with a blue progress band filling each tab before the next staggered app reveal. A manual tab choice cancels the pass and preserves the user's selection; Replay restarts the complete pass. Appearance chips trigger a finite layout transition; Controls Replay restarts its demonstration; Back and Next navigate with a short directional entrance; Explore Focus Sets completes the tour; Skip Tour, Escape, or the close button dismisses it; Return activates Next or Explore Focus Sets.

**Constraints & Limits:** Swift 5.8 and macOS 10.13; programmatic AppKit only; shared design-system chrome; no polling, repeating timer, display link, global event monitor, AX/CG query, production switcher view, Focus Sets persistence, or live application enumeration; all animation stops on page replacement, close, resign-key, or Reduce Motion change; tour objects release after dismissal.

**Visual & Behavioral Fidelity:** The miniature switcher uses optimized app-icon artwork shared with the landing-page examples and accurately communicates named app membership, direct shortcut invocation, repeat-to-cycle, App Icons/Titles presentation, and hold/tap/release control behavior. Motion is never the sole carrier of meaning.

**Persistence & Actions:** The existing `settingsWindowShownOnFirstLaunch` raw preference remains the compatibility marker but is exposed through initial-experience naming. Demo choices never persist. Completion and Skip set the marker. Manual replay never changes it. The final action opens `.focusSets` through existing Settings routing.

**Explicit Non-Goals:** Real-UI coach marks, Settings-page walkthroughs, workspace creation, importing templates, changing shortcuts, collecting telemetry, feature-tour versioning, and performance work outside the onboarding boundary.

## Architecture

**Smallest shared-boundary change:** Add a lazily created `OnboardingTourWindow` behind the existing first-launch gate and reuse the existing Settings route for the final handoff. The tour owns presentation DTOs and finite layer animations; production switcher, Focus Sets, and event code remain unaware of it.

**Shared structures:**

```swift
enum OnboardingTourPage: Int, CaseIterable {
    case focusSets
    case appearance
    case controls
}

enum OnboardingTourNavigationAction: Equatable {
    case show(OnboardingTourPage)
    case finish
}

enum OnboardingTourResolver {
    static func back(from page: OnboardingTourPage) -> OnboardingTourPage
    static func next(from page: OnboardingTourPage) -> OnboardingTourNavigationAction
    static func shouldPresentAutomatically(initialExperienceShown: Bool) -> Bool
    static func shouldAnimate(windowVisible: Bool, reduceMotion: Bool) -> Bool
    static func nextAutoplayIndex(after currentIndex: Int, count: Int) -> Int?
}

protocol OnboardingTourScene: AnyObject {
    var view: NSView { get }
    func activate(animated: Bool)
    func deactivate()
}

enum OnboardingTourCompletion {
    case skip
    case exploreFocusSets
}
```

`OnboardingTourScene` is the only page/window contract. No protocol is introduced for artwork or persistence because each has one implementation.

## File Map

Create:
- `src/onboarding/OnboardingTourResolver.swift` — pure navigation, presentation, and animation decisions.
- `src/onboarding/OnboardingTourResolverSpecs.md` — resolver behavior and scenarios.
- `src/onboarding/OnboardingTourResolverTests.swift` — resolver XCTest coverage.
- `src/onboarding/OnboardingTourArtwork.swift` — demo DTOs, category badges, app-icon views, keycaps, and the miniature switcher with finite keyed animations.
- `src/onboarding/OnboardingTourFocusSetsPage.swift` — Entertainment, Work, and Side Projects scene.
- `src/onboarding/OnboardingTourAppearancePage.swift` — local App Icons/Titles scene.
- `src/onboarding/OnboardingTourControlsPage.swift` — hold/tap/release scene.
- `src/onboarding/OnboardingTourWindow.swift` — page host, navigation, lifecycle, and accessibility-option observation.

Modify:
- `src/App.swift` — first-launch sequencing, replay action, deferred crash consent, and secondary-window key suppression.
- `src/Menubar.swift` — replay menu item.
- `src/preferences/Preferences.swift` — compatibility accessor naming for the existing raw marker.
- `scry-tab.xcodeproj/project.pbxproj` — onboarding group and main/test target membership.
- `resources/l10n/Localizable.strings` and localized variants — extracted source strings and translations.

## Task [1]: Add the Pure Tour Decision Core

**Description:** Add the page, navigation action, completion type, scene contract, and pure resolver with co-located specs/tests. Add only these files to the project and targets. UI construction and launch wiring are out of scope.

**Dependencies:** Blocked by none. Blocks Tasks 2 and 3.

**Files:** Create `src/onboarding/OnboardingTourResolver.swift`, `src/onboarding/OnboardingTourResolverSpecs.md`, `src/onboarding/OnboardingTourResolverTests.swift`; Modify `scry-tab.xcodeproj/project.pbxproj`.

**Interfaces:** Consumes `NSView` for the scene boundary. Produces the exact shared structures declared above.

**Execution Steps:**

- **Step 1:** Implement clamped Back behavior, page-advancing Next behavior, final-page Finish behavior, automatic presentation only when the compatibility marker is false, animation only when the window is visible and Reduce Motion is false, and finite Focus Set autoplay advancement without wrapping.
- **Step 2:** Add one spec scenario and matching XCTest for each boundary: back from first, back from later pages, next from first/middle, next from final, new install, existing install, visible motion, hidden window, Reduce Motion, finite Focus Set advancement, and invalid autoplay indexes.
- **Step 3:** Add the resolver to both application and unit-test Sources phases, and the tests only to unit tests.
- **Step 4:** Run:
  `set -o pipefail && xcodebuild test -project scry-tab.xcodeproj -scheme Test -configuration Debug -only-testing:unit-tests/OnboardingTourResolverTests | scripts/xcbeautify`
  Expected: exit 0 and every `OnboardingTourResolverTests` case passes.

## Task [2]: Build the Isolated Focus Sets Demonstration

**Description:** Build reusable illustration primitives and the flagship Focus Sets page. All state is local presentation data. Appearance, Controls, the window shell, persistence, and launch integration are out of scope.

**Dependencies:** Blocked by Task 1. Blocks Task 3.

**Files:** Create `src/onboarding/OnboardingTourArtwork.swift`, `src/onboarding/OnboardingTourFocusSetsPage.swift`; Modify `scry-tab.xcodeproj/project.pbxproj`.

**Interfaces:** Consumes `OnboardingTourScene`, `DesignSystem`, `DesignSystemControlStyler`, and `DesignSystemSegmentedControl`. Produces `OnboardingTourFocusSetsPage` and internal category-badge/switcher-preview/keycap/app-icon views.

**Execution Steps:**

- **Step 1:** Define nine immutable demo apps grouped as Entertainment (`Netflix`, `Plex`, `Chrome`), Work (`Cursor`, `Safari`, `VS Code`), and Side Projects (`Finder`, `Notes`, `Settings`). Render optimized HEIC app artwork from the landing-page examples, with a guarded SF Symbol and text fallback if a resource cannot load.
- **Step 2:** Build `OnboardingSwitcherPreviewView` with one stable set of reusable tile views inside one 536-point centered plateau surface over the window material. Support icon-grid and title-list layouts, a product-like selected tile, immediate application, finite staggered opacity/position/scale transitions, and recursive animation teardown.
- **Step 3:** Compose the Focus Sets page with localized heading/body, one accessible 536-point segmented story rail using shared control styling, 20-point colored badges, shared blue per-segment progress bands, the centered app-icon switcher, an illustrative `⌥` plus `1`/`2`/`3` keycap row, and Replay Animation. Selection updates the visible membership and accessible summary without persistence.
- **Step 4:** On first activation, schedule one-shot 2.8-second transitions through all three Focus Set tabs, keeping past progress full and stopping on Side Projects. Manual selection cancels playback; Replay resets to Entertainment. On deactivation, invalidate the one-shot timer, remove animations, and snap to the selected final state. Exclude decorative icons from VoiceOver; expose selector names and one stable scene summary.
- **Step 5:** Run the copied build sequence from `ai/build.sh`:
  `/Users/ajanth/development/perpro/scry-tab/scripts/codesign/unlock_local_keychain.sh`
  `xcodebuild -project scry-tab.xcodeproj -scheme Debug -configuration Debug -derivedDataPath DerivedData`
  Expected: exit 0 and `** BUILD SUCCEEDED **`.

## Task [3]: Complete the Three-Page Tour Window

**Description:** Add Appearance and Controls scenes and host all three scenes in a native tour window. Launch integration, replay menus, and localization catalog updates are out of scope.

**Dependencies:** Blocked by Tasks 1 and 2. Blocks Task 4.

**Files:** Create `src/onboarding/OnboardingTourAppearancePage.swift`, `src/onboarding/OnboardingTourControlsPage.swift`, `src/onboarding/OnboardingTourWindow.swift`; Modify `scry-tab.xcodeproj/project.pbxproj`.

**Interfaces:** Consumes the scene contract and artwork from Tasks 1–2. Produces `OnboardingTourWindow.present(primaryShortcutText:onCompletion:)`, `OnboardingTourWindow.dismissAnimations()`, and one completion callback carrying `OnboardingTourCompletion`. The caller supplies a one-time display snapshot so the tour never observes preferences or shortcut state.

**Execution Steps:**

- **Step 1:** Build Appearance with local App Icons/Titles choices and the reusable preview. Transitions change only the illustration; size and System/Light/Dark are explained but not configurable in the tour.
- **Step 2:** Build Controls from a one-time display string supplied by the window initializer, keycap views, and the reusable preview. A finite keyframe group demonstrates modifier held, next key pressed, selection advanced, and release-to-focus. Replay is user-triggered; there is no automatic loop.
- **Step 3:** Build a centered, nonresizable `NSWindow` using `DesignSystemWindowContentView`. The stable hierarchy is page host, `Step n of 3`, divider, and trailing native actions: Skip Tour on the leading side; Back then Next/Explore Focus Sets on the trailing side. Preserve intrinsic button widths. Return activates Next/final; Escape and close produce Skip.
- **Step 4:** Keep only the current scene attached. On navigation, deactivate and remove the old scene before attaching the new one. Observe `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`; Reduce Motion removes animations and applies final state immediately. Also stop animations on resign-key and close, remove the observer symmetrically, clear callbacks, and release `shared` after dismissal.
- **Step 5:** Give every interactive control a native accessibility role/label/action, keep decorative artwork hidden from VoiceOver, expose page title/body/progress in reading order, and preserve full keyboard traversal.
- **Step 6:** Run the copied `ai/build.sh` sequence. Expected: exit 0 and `** BUILD SUCCEEDED **`.

## Task [4]: Integrate First Launch, Replay, and Localization

**Description:** Replace the first-launch Appearance handoff with the tour, defer crash consent until the tour closes, add replay entries, retain existing-install compatibility, and translate new strings. Reordering Settings and opening the Add sheet directly remain out of scope.

**Dependencies:** Blocked by Task 3. Blocks Task 5.

**Files:** Modify `src/App.swift`, `src/Menubar.swift`, `src/preferences/Preferences.swift`, `resources/l10n/Localizable.strings`, localized `.lproj/Localizable.strings`, and any generated localization manifest required by the localization workflow.

**Interfaces:** Consumes `OnboardingTourWindow.present`, `OnboardingTourCompletion`, `SettingsRoute.focusSets`, and the existing raw `settingsWindowShownOnFirstLaunch` preference. Produces `App.showOnboardingTour()` and `Preferences.initialExperienceShown`/`markInitialExperienceShown()` compatibility accessors.

**Execution Steps:**

- **Step 1:** Rename only the Swift accessor/mutator semantics while continuing to read and write raw key `settingsWindowShownOnFirstLaunch`, preserving existing users as already shown. Gate automatic presentation with `OnboardingTourResolver`; manual replay bypasses the gate and never mutates the marker.
- **Step 2:** After permissions and normal runtime initialization, present the tour for a new install instead of Appearance. On Skip/close, mark the initial experience shown and then present crash consent. On Explore Focus Sets, mark shown, close the tour, open `.focusSets`, and then present crash consent. If no tour is needed, keep current crash-consent behavior.
- **Step 3:** Include the tour window in `allSecondaryWindowsCanBecomeKey`. Add one localized `Take ScryTab Tour…` entry near Settings in the status menu targeting `App.showOnboardingTour()`.
- **Step 4:** Follow `translate-missing-l10n`: refresh source strings, translate every new key for German, Spanish, French, Japanese, Simplified Chinese, and Russian, preserve shortcut glyphs and `%@` specifiers, and apply translations with `scripts/l10n/apply_translations.ts`.
- **Step 5:** Run the copied `ai/build.sh` sequence. Expected: exit 0 and `** BUILD SUCCEEDED **`.

## Task [5]: Audit, Review, and Verify the Complete Change

**Description:** Run required spec/test consistency, full tests, build, diff, lifecycle, and performance-boundary audits. Do not launch the app or claim visual fidelity that was not observed.

**Dependencies:** Blocked by Task 4. Blocks completion.

**Files:** Modify only files needed to correct verified defects. Do not broaden scope.

**Interfaces:** Consumes the complete diff. Produces verification evidence and a concise visual-QA gap report.

**Execution Steps:**

- **Step 1:** Run the `audit-specs-tests` skill and resolve every onboarding triad mismatch. Expected: no orphan or drift findings for onboarding.
- **Step 2:** Run `scripts/run_tests.sh`. Expected: exit 0 and the Test scheme succeeds.
- **Step 3:** Run the complete copied `ai/build.sh` command sequence. Expected: exit 0 and `** BUILD SUCCEEDED **`.
- **Step 4:** Inspect the diff for repeating timers, `DispatchSourceTimer`, `CVDisplayLink`, `NSEvent.addGlobalMonitor`, `Applications.list`, `FocusSetsStore`, `TilesView`, `TilesPanel`, AX, or CG references under `src/onboarding`; the only scheduler may be the Focus Sets page's finite, invalidated one-shot `Timer`.
- **Step 5:** Run `git diff --check`, inspect `git diff --stat`, `git diff`, and `git status --short`; expected: no whitespace errors, `.sdd-ledger` absent from status, and only planned files changed.
- **Step 6:** Apply the mandatory `swift-appkit-code-review` skill and the subagent independent review gate. Resolve findings within three cycles. Report that live visual/animation QA and Instruments profiling remain unverified because project rules prohibit launching the app without a separate explicit request.

## Plan Self-Review

- One primary flow: yes; Focus Sets → Appearance → Controls → existing Focus Sets page.
- Requirements covered: yes; self-contained pages, animation, skip/replay, first launch, accessibility, lifecycle, localization, and latency isolation.
- Interfaces consistent: yes; one page enum, one pure resolver, one scene boundary, one completion callback.
- Placeholders: none.
- Smallest shared boundary: one first-launch switch and the existing `.focusSets` route; no production switcher changes.
