---
name: publish-public-release
description: Use when a user asks to publish, ship, tag, notarize, or verify a public ScryTab release from the repository's main branch.
---

# Publish Public Release

Ship through `.github/workflows/ci_cd.yml`; never reproduce signing or publication locally.

REQUIRED: Use `wolf-skills/verification-before-completion`.

## Source of truth

1. Read `AGENTS.md`, `docs/RELEASE_BLOCKERS.md`, `.github/workflows/ci_cd.yml`, and every script called by the workflow.
2. Preserve GPL notices, Corresponding Source, Developer ID, Team ID, bundle ID, Sparkle signing, and website publication.
3. Update `docs/RELEASE_BLOCKERS.md` in the same commit that adds or clears a blocker. Never mark B5 or B6 complete without the manual runtime evidence they require.

## Recipe

1. Inspect `git status --short --branch`, the complete diff, current branch, remotes, and recent tags. Fetch `origin` and require `main` with no upstream divergence or unrelated changes.
2. Confirm GitHub authentication, the `scry-tab-release` runner is online and idle, and no release run is active.
3. Run every repository check required by the changed files. For Swift/AppKit changes, use the mandatory development/review skills, run focused tests, copy and run `ai/build.sh` commands directly, then run the Release test suite. Run formatting checks, `git diff --check`, and review the final diff.
4. Stage only intended files, run `scripts/ensure_generated_files_are_up_to_date.sh` against that staged state, inspect the staged diff, then commit with a release-producing conventional subject (`fix:`, `feat:`, or a breaking change). Keep the commit local.
5. Dry-run semantic-release without writing `VERSION.txt`. Require a non-empty next version, explain the release type from conventional commits, and require that the predicted public tag does not exist.
6. Push `main` and verify local `HEAD` equals `origin/main`.
7. Dispatch `gh workflow run ci_cd.yml --ref main`. Capture the new run ID and watch it to completion with `gh run watch <id> --exit-status`. Report meaningful phase changes during the run.
8. On failure, stop. Inspect the failed step, signing cleanup, tags, private release commit, public release assets, and live website state. Never blindly rerun a partially published workflow.
9. On success, fetch and fast-forward to semantic-release's `chore(release)` commit. Resolve the published version from `VERSION.txt` and run `scripts/verify_public_release.sh <version>` from this skill directory.
10. Record new release evidence in `docs/RELEASE_BLOCKERS.md` when the repository uses that record for current-version/run evidence. Commit and push the documentation separately, then verify the release tag still points to the semantic-release commit.

## Verification gate

Require all of these before claiming publication:

- workflow conclusion `success`, including signing-material cleanup;
- private `v<version>` tag and semantic-release commit;
- public non-draft release with exactly DMG, Sparkle ZIP, and Corresponding Source;
- asset digests, strict signatures, stable Team/bundle identifiers, Gatekeeper, and staple validation;
- live manifest/appcast version, URLs, enclosure length, and EdDSA signature;
- final `main` synchronized with `origin/main`.

The workflow proves packaging integrity. It does not prove the clean-machine flow or an installed app's end-to-end Sparkle update; keep B5/B6 open until those manual checks occur.
