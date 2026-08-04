# Release readiness
- `docs/RELEASE_BLOCKERS.md` is the single source of truth for what stands between `develop` and
  the first public download. Read it before touching signing, notarization, Sparkle, the appcast,
  release packaging, licensing, or the website, and update it in the same commit that clears or
  adds a blocker.
- ScryTab is a GPL-3.0 derivative of AltTab. Attribution, the `LICENCE.md` text, the About pane's
  legal notices, and the source-code offer are licence obligations, not decoration — do not
  remove or weaken them. The Mac App Store is permanently unavailable as a consequence.

# macOS development
- Don't use xcode directly to develop
- Use pure swift 5.8 code to make the app. No interface builder. No SwiftUI.
- Aim for compact code. Within methods, don't have groups of statements separated with newlines. No inline comments for simple code. Instead, split statements into sub-methods.
- Use guard closes as much as possible to separate the happy-path under them
- Organize source files into folders. Folders should group files that change together, at the same pace (e.g. one feature)
- When possible, follow the triad pattern: specs in *Specs.md, unit-tests in *Tests.swift, and *swift for the implementation. Document features and their edge-cases this way
- Favor low latency and responsiveness. Reuse objects, avoid wasting memory or I/O. Use observer APIs; don't poll.
- Treat the checked-in System Settings-style design system as mandatory for app chrome. Reuse its material views, grouped panels, controls, metrics, and `DesignSystem.ColorRole` surface palette; extend the shared design system before adding a new visual behavior. Do not create feature-local replacements for panel, surface, material, tint, shared geometry, or control chrome.
- Model Add/Edit flows as one transactional sheet with dependent choices inline; do not cascade or nest sheets. Keep a draft until the default action commits it, and let Cancel leave persisted state unchanged.
- Use native sheet actions: a trailing cluster with the default commit action rightmost and Cancel immediately to its left; Return triggers the default action and Escape cancels. Use intrinsic or minimum label widths, never fixed widths that can clip localized text.
- For incremental `NSSearchField` filtering, reuse a context-appropriate shared primitive and observe `NSControl.textDidChangeNotification`; preserve search-specific behavior when replacing its cell and preserve keyboard/VoiceOver focus through filtered-list rebuilds.

# Required skills
- Before implementing, modifying, refactoring, or debugging Swift/AppKit code, load and follow the `swift-appkit-development` skill in `.agents/skills/swift-appkit-development/SKILL.md`.
- Before reviewing Swift/AppKit code, macOS UI changes, or changes that affect app behavior, load and follow the `swift-appkit-code-review` skill in `.agents/skills/swift-appkit-code-review/SKILL.md`.
- These skills are mandatory project standards. Their `.agents/skills` location is the canonical shared source for Codex, OpenCode, and Cursor; do not maintain divergent vendor-specific copies.

# Workflow
- Copy the command sequence from `ai/build.sh` and run it to confirm compilation after implementing a code change. Resolve `$0` and other script-relative paths against `ai/build.sh` so copied commands preserve the script's behavior.
- Never start, stop, restart, or manage servers, and never open or control browsers unless the user explicitly asks. Non-server tests, type checks, linting, and builds are allowed.

# License / Keychain invariant
- The app's Developer ID, TeamID, and bundle ID must remain stable across builds. Keychain items are tied to the code signature; changing any of these orphans every user's stored license key and forces mass re-activation. If a rotation is unavoidable, plan a migration first (e.g., a backup-restore handler, or `kSecAttrAccessGroup` with a stable group identifier).
- Do not introduce legacy `SecKeychain*` API or `kSecAccessControl` (biometric/PIN gating) into license code — both can trigger Keychain password prompts, which is bad UX for license activation.
