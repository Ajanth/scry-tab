---
name: swift-appkit-code-review
description: Review Swift and AppKit diffs, staged changes, pull requests, or source code in this repository. Use for every Swift/AppKit review and after substantial implementations. Find correctness, lifecycle, compatibility, accessibility, performance, persistence, test, and maintainability defects, and strictly reject deviations from the checked-in System Settings-style material, panel, surface, and control system.
---

# Swift and AppKit Code Review

Review for user-visible and engineering risk. Do not edit code unless the user asks for fixes.

## Establish Scope

1. Read `AGENTS.md`.
2. Identify the requested diff or source range.
3. Read every changed file plus enough callers, specs, and tests to establish behavior.
4. For UI changes, read [../swift-appkit-development/references/ui-design-standard.md](../swift-appkit-development/references/ui-design-standard.md), then inspect the reused design-system primitives and the current Appearance and Controls tabs.
5. Report only issues introduced or materially worsened by the reviewed change.

## Review in Risk Order

- Trace success, empty, failure, cancellation, repeated-call, teardown, and re-entry paths.
- Check force operations, indexes, stale references, target/action, responder behavior, callback ordering, preference synchronization, and error handling.
- Check observer, timer, monitor, delegate, and closure ownership for duplicates, leaks, use-after-free, and retain cycles.
- Require main-thread AppKit work and safe return from background work. Reject polling or blocking input/drawing paths.
- Enforce Swift 5.8 and macOS 10.13. Flag unguarded newer APIs or fallbacks that do not preserve behavior.
- Check target membership, localization, settings search, persisted-key migration, and launch integration.
- For Add/Edit sheets, verify one transactional sheet owns the draft, Cancel cannot persist it, and dependent choices are inline rather than nested in a second sheet.
- For incremental `NSSearchField` UI, verify text changes reach the filtering state after styling or cell replacement; target/action alone is insufficient evidence. Check blank, case/diacritic, unavailable-item, and focus-preservation paths.
- For sheet actions, verify the default action is rightmost, Cancel is immediately to its left, Return/Escape work, destructive actions are separate, and localized labels rely on intrinsic or safe minimum widths rather than fixed widths.
- Treat Developer ID, Team ID, release bundle ID, entitlements, and license Keychain changes as release-critical unless an explicit migration proves continuity.
- Reject `SecKeychain*` and `kSecAccessControl` in license code.

## Enforce the Visual Contract

- Compare changed app chrome against the exact shared material, `surface*` roles, metrics, grouped panels, and controls. Visual similarity is insufficient.
- Report every new feature-local panel or control background, material, tint, gradient, border, radius, spacing system, or state color. The correction is to reuse or extend the shared design system.
- Report inconsistent hierarchy, alignment, density, typography, decorative nesting, or non-native interaction that makes the surface diverge from the polished macOS/System Settings baseline.
- Verify normal, hover, pressed, selected, focused, disabled, key-window, light, dark, Reduce Transparency, and Increase Contrast behavior where applicable.
- Verify keyboard access, focus, control semantics, accessibility, localization growth, intrinsic sizing, and complete constraints.
- Treat these as objective contract violations, not stylistic preferences.

## Maintainability and Tests

- Flag duplicated truth, hidden side effects, unclear ownership, broad global mutation, stringly state, speculative abstractions, feature logic trapped in views, and copied UI state machines when they create concrete risk.
- Check recoverable errors, private or Accessibility API isolation, bounded caches, and deterministic teardown.
- Require tests proportional to changed behavior, especially for preferences, migrations, availability branches, control state, and lifecycle.
- Confirm tests would fail without the change and assert behavior rather than source shape.
- For changed testable decisions, require the implementation/spec/test triad. Check both directions and use `audit-specs-tests` when either side changes.

## Apply an Evidence Threshold

Report a finding only when all are true:

- The issue is in the requested scope and introduced or worsened by the change.
- A concrete input, event sequence, configuration, or maintenance failure demonstrates the impact.
- The affected code and a reasonable correction are precise.

For visual-contract findings, the changed surface itself is the concrete trigger and inconsistent app chrome is the impact. Do not dismiss it as style. Do not report unrelated debt, formatting preferences, documented intentional behavior, or issues prevented by the language or framework.

## Assign Severity

- **P0**: Immediate, broadly catastrophic data loss, security compromise, or unusable release.
- **P1**: Likely crash, data or license loss, major workflow failure, or severe security/privacy defect.
- **P2**: Real behavioral regression, compatibility or accessibility failure, lifecycle leak, or maintainability defect likely to cause near-term divergence.
- **P3**: Localized edge case, bounded visual-contract violation, or clear new technical debt.

Use the lowest severity that accurately represents demonstrated impact.

## Verify and Report

- Run focused tests or static checks when they can confirm or reject a suspected finding.
- For code changes, inspect `ai/build.sh`, copy its complete non-comment command sequence, resolve script-relative paths against `ai/build.sh`, and run the commands directly in order when feasible.
- Do not launch the app, manage servers, or open/control browsers unless explicitly requested.
- Do not turn a failed check into a code finding unless the failure is caused by the reviewed change.
- Report findings first, ordered by severity and confidence:

```text
[P2] Imperative, specific title - path/to/File.swift:line
Explain the triggering scenario, resulting impact, and why the changed code permits it.
```

Keep line ranges tight. Then list assumptions and verification gaps. If there are no findings, say so and state residual test or visual-verification risk.
