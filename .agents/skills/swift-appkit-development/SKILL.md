---
name: swift-appkit-development
description: Implement, modify, refactor, or debug Swift and AppKit code in this repository. Use whenever changing `.swift` files, macOS UI, the design system, preferences, events, tests, or Xcode project metadata. Enforce Swift 5.8, macOS 10.13, AppKit lifecycle safety, and strict reuse of the checked-in System Settings-style material, panel, surface, and control system.
---

# Swift and AppKit Development

Make the smallest coherent change that preserves the repository's behavior and visual language.

## Before Editing

1. Read `AGENTS.md`.
2. Read the changed implementation, its callers, and its co-located specs and tests.
3. For any window, view, control, settings, or design-system change, read [references/ui-design-standard.md](references/ui-design-standard.md) and inspect the exact shared primitives being reused.
4. Preserve unrelated worktree changes.

## Implementation Rules

- Use Swift 5.8, programmatic AppKit, and the macOS 10.13 deployment target.
- Do not add SwiftUI, Interface Builder, storyboards, or nibs.
- Guard newer APIs and provide a behaviorally valid macOS 10.13 fallback.
- Keep AppKit work on the main thread. Move blocking I/O and expensive pure work off it.
- Use Auto Layout and intrinsic sizing. Configure stable hierarchy and constraints once.
- Keep one source of truth for mutable state. Route preferences through existing typed APIs and migrate changed keys or meanings.
- Store and tear down observers, timers, monitors, delegates, and escaping callbacks symmetrically. Prevent duplicate registration and retain cycles.
- Prefer `guard`, immutable values, explicit ownership, narrow access, and `final` classes. Keep each method at one abstraction level; extract distinct phases instead of separating them with blank lines.
- Do not force unwrap or cast external state, resources, preferences, indexes, events, or framework objects. Do not swallow failures.
- Keep event and drawing paths bounded. Reuse stable expensive objects, bound caches, coalesce bursty work, and use observers instead of polling.
- Keep system, Accessibility, Carbon, and private APIs behind the existing `src/macos` boundary.
- Add new source, test, and resource files to the correct Xcode targets.
- Do not change the Developer ID, Team ID, release bundle ID, entitlements, or Keychain access behavior without an explicit migration plan.
- Do not introduce `SecKeychain*` or `kSecAccessControl` into license code.

## Visual Contract

- Treat the existing liquid-glass-like material and `surface*` roles as a fixed app-wide contract, not inspiration.
- Build settings from `TableGroupSetView`, `TableGroupView`, `LabelAndControl`, and existing design-system controls.
- Use `DesignSystemWindowContentView` or `DesignSystemMaterialView` for window material, `surfacePlateau` for grouped panels, `surfaceFlat` for controls, and the existing hover, pressed, selected, border, and focus roles for state.
- Do not add feature-local app-chrome colors, alpha values, materials, gradients, panel backgrounds, borders, radii, spacing scales, duplicated shared metrics, or custom control treatments. If a required behavior is missing, extend and test the shared primitive first.
- Preserve native target/action, menus, editing, responder, keyboard, focus, enabled, and accessibility semantics.
- Handle light, dark, key-window, disabled, hover, pressed, selected, focus, Reduce Transparency, and Increase Contrast states as applicable.
- Resolve layer colors through `DesignSystem` in the view's effective appearance and refresh cached colors when appearance changes.
- Keep the compact System Settings hierarchy: quiet material background, grouped plateau sections, flat controls, short labels, secondary explanations, and no decorative or nested cards.
- Localize user-facing text and register settings content with the existing search infrastructure.

## Sheets, Search, and Dynamic Lists

- Put Add/Edit flows in one transactional sheet: keep all dependent selection controls inline, retain a draft locally, commit it only from the default action, and discard it on Cancel. Never stack or cascade sheets.
- Put the default commit action at the bottom trailing edge, with Cancel immediately to its left; map Return to the default action and Escape to Cancel. Preserve AppKit’s intrinsic button widths or use localization-safe minimums—never force a fixed label width.
- Reuse a named, context-appropriate search primitive instead of reproducing its visual or behavioral setup. If styling replaces an `NSSearchFieldCell`, preserve its search-specific state; for live filtering, observe `NSControl.textDidChangeNotification` in addition to any target/action configuration.
- Filter from one query source of truth and extract matching logic into a deterministic resolver when practical. Test blank, case-insensitive, diacritic-insensitive, and unavailable-item behavior.
- A list reload triggered by search or selection must preserve a valid keyboard/VoiceOver focus target and selection where possible; do not leave the first responder pointing at a removed view.

## Specs and Verification

- For changed decision logic, create or update the co-located `Foo.swift`, `FooSpecs.md`, and `FooTests.swift` triad. AppKit-only glue may omit a test only when no deterministic decision can be extracted.
- Test changed decisions, state transitions, lifecycle behavior, migrations, availability fallbacks, and design-system contracts.
- Test observable behavior rather than private implementation structure.
- Keep every XCTest method represented exactly once in the matching spec and keep descriptions aligned.
- Use the `audit-specs-tests` skill after changing `*Tests.swift` or `*Specs.md`.
- Use `assets-optimization` when adding or replacing shipped images.

## Verify

1. Run focused non-server tests.
2. For code changes, inspect `ai/build.sh`, copy its complete non-comment command sequence, resolve script-relative paths against `ai/build.sh`, and run the commands directly in order.
3. Run required audits, then inspect `git diff --check`, the final diff, and `git status --short`.
4. Report exact checks and visual-verification gaps. Do not launch the app, manage servers, or open/control browsers unless explicitly requested.
