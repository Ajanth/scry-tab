# Canonical public repository migration

Status on 2026-10-10: cutover complete. `scry-tab` is public, both PRs are merged,
the existing Cloudflare site uses canonical release/source/issue links, and the legacy
release mirror is archived with its assets preserved. No downtime was observed.
Release readiness is tracked in [RELEASE_BLOCKERS.md](RELEASE_BLOCKERS.md), B10.

`Ajanth/scry-tab` is the public source, release, and issue repository.
`Ajanth/scrytab-cms` continues deploying to <https://scrytab.pages.dev/>. Keep its
Cloudflare project, domain, analytics, and cross-repository publication token.

## Phase 1: history and workflow audit

Fetched every remote branch and tag plus all 34 `refs/pull/*/head` refs into local
`refs/audit/pull/*`. The union with existing local refs contains 267 commits,
4,943 objects, and 2,902 blobs. Gitleaks 8.30.1, downloaded from its official release
and verified against its published checksum, scanned `--all --full-history` with
fully redacted output and reported no leaks. A second pass inspected all reachable
blob contents for private-key headers and reviewed non-vendored text for personal
paths, email addresses, fixed passwords, and unrelated operations.

Exposure that remains in history:

- The maintainer's commit email is personal; the other commit identity is the
  semantic-release bot. Copyright identities remain required attribution.
- Planning documents include personal development paths. Release readiness notes
  describe the release runner and mention another project's runner setup.
- Historical local signing scripts used fixed passwords. D11 records their retirement
  and local keychain regeneration on 2026-08-09; current scripts read a random per-user
  password or explicit arguments. These historical literals are not current secrets.
- Internal planning and release operations excluded by `.gitattributes` will be visible
  in repository history. Export exclusions do not conceal Git history.

This audit does not establish that every unrecognized credential format is absent.
The maintainer explicitly accepted the listed history exposure before cutover on
2026-10-10. Removing a file in a PR would leave historical copies reachable; no history
or release tags were rewritten.

The current Release and Notarization status workflows use `workflow_dispatch`, a
`refs/heads/main` job condition, and `environment: production`. Release has
`contents: write`, a dedicated macOS runner, serialized runs, and unconditional
signing-material cleanup. On 2026-10-10 the production environment was changed from
unrestricted to a custom branch policy containing only branch `main`. The prepared
Release workflow checks repository visibility before checkout, signing, or publication.
There were no active release runs during preparation.

## Phase 2: canonical repository and automation

The repository description and homepage now identify ScryTab and its existing website.
The app PR updates README/contributing links, app source/feedback URLs, matching issue
forms, the release workflow, appcast generation, website publication, statistics, and
the release verification helper. GPL notices and the maintainer-led contribution policy
remain in place. Releases use `GITHUB_TOKEN`; the separate site's contents API still uses
`WEBSITE_DISPATCH_TOKEN`. No site workflow or hosting was replaced.

## Phase 3: release replication evidence

Only the two currently published releases were copied. Their titles and bodies match
exactly, and the uploaded asset names, byte lengths, and GitHub SHA-256 digests match.
`v0.4.0` is latest; neither release is a draft or prerelease. No withdrawn release entry
was recreated, and no existing tag was changed.

The legacy repo's `v0.3.0` and `v0.4.0` tags both identify placeholder commit
`27483595228c9ff49fa00d1dbce4d1ddd0c500f4`; they do not identify application source.
Every archived source entry, file byte, mode, and symlink target was compared against
`git archive` of the canonical tag and matched:

| Version | Canonical source commit |
| --- | --- |
| `v0.3.0` | `4e4c84e2e60f7143e5f830390d557b3f260a9f39` |
| `v0.4.0` | `6c0363d106376bbcf0faec30e8d04363b0fc3495` |

| Asset | SHA-256 |
| --- | --- |
| ScryTab-0.3.0.dmg | `83afbf23dd6919c3f77e7b316c02936261fafcfc37a2a2e88dc31f5865d5fa75` |
| ScryTab-0.3.0.zip | `19caaa0c95597e17f577b7b9f690e67b82ea960e1a8fb68d11f0549b97d2fd7e` |
| ScryTab-0.3.0-source.tar.gz | `4015f3ec994c2c229a8b87e00456de1f359684b6474ed97aa84e0f6732b3abd0` |
| ScryTab-0.4.0.dmg | `43fce81ce52bc7feaa4a87793fd859033c7b547971daaeba127a3c2d3b37c53b` |
| ScryTab-0.4.0.zip | `714f043b46f3a6775350fb5a8b80459b257e7ede66b4c72bf9ab5131c7eb2a4c` |
| ScryTab-0.4.0-source.tar.gz | `7c2de7a06ab016f8111af106652b923814ef6953b9cbc79c34541ed535b84bdf` |

## Phase 4: cutover, availability, and rollback

Completed execution:

- App PR [#35](https://github.com/Ajanth/scry-tab/pull/35) merged at 16:27 CEST as
  `b044a48ee389b117f6c99e9e17500f3861ca10cd`. The repository was then made public;
  all six assets downloaded without authentication and matched the hashes above.
- Site PR [#3](https://github.com/Ajanth/scrytab-cms/pull/3) merged at 16:28 CEST as
  `cd8da1b435052a87ea90c1fac094b281e97b489c`. Its Cloudflare deployment
  `a5482c46-16be-4e91-a7e1-6d3a75b1d698` completed successfully.
- The live landing page, source page, privacy page, manifest, and appcast returned 200
  and contained no legacy release-repository links. The manifest names canonical DMG
  and source assets; the single-item feed names the canonical ZIP and retains its
  original EdDSA signature and `6151166` byte length.
- The full `verify_public_release.sh 0.4.0` passed hashes, source contents, strict nested
  signatures, Gatekeeper, staple tickets, stable Team/bundle identifiers, and live
  manifest/feed checks. The production branch policy still permits only `main`.
- The legacy README and description identify the canonical repository. The mirror
  is archived, its existing tags and assets remain available, and repository-scoped
  `PUBLIC_REPO_TOKEN` was deleted. `WEBSITE_DISPATCH_TOKEN` remains configured.

The sequence below documents the rollout and rollback procedure used for this cutover.

The old site and all existing assets stay available during preparation and review.
Target downtime is zero; any outage must be restored within one hour. Do not dispatch
a new release during cutover. Record the cutover start time and both merge commits.

1. Review the audit exposure above and merge the app PR into `main`. Recheck that
   release jobs remain manual, `main` only, and protected by the production branch policy.
2. Make the repository public:
   `gh repo edit Ajanth/scry-tab --visibility public --accept-visibility-change-consequences`.
   Re-read the production environment policy after the visibility change.
3. Verify all six canonical asset URLs return 200 without authentication before deploying
   the website PR. Use `curl -fL` to download each and compare the table above. This ordering
   ensures Cloudflare never deploys links to private assets.
4. Merge the site PR and wait for its existing Cloudflare Pages deployment. Check the
   live landing page, `/source`, `/privacy`, `/release.json`, and `/appcast.xml`. The manifest
   must name the canonical `v0.4.0` DMG/source and the feed must enclose the canonical ZIP
   with the original length `6151166` and unchanged EdDSA signature. Run
   `.agents/skills/publish-public-release/scripts/verify_public_release.sh 0.4.0`.
5. If deployment or anonymous asset access fails, keep legacy assets online and revert the
   site cutover commit immediately. Do not wait near the one-hour ceiling. Confirm the
   previous manifest/feed and legacy downloads return 200 before retrying. The former
   website baseline is `83541c7`; its release manifest and feed contain the current old URLs.

After live verification, update the legacy README/description to identify the canonical
repository, provide a link to its issue tracker, and archive it with
`gh repo archive Ajanth/scrytab-public --yes`. Do not delete its assets or tags. Existing
binary feedback links continue to name the legacy tracker until users install a future
release; its archived issues are read-only. Retire `PUBLIC_REPO_TOKEN` from its existing
secret scope only after the app workflow is merged and legacy publication is no longer
needed. Keep `WEBSITE_DISPATCH_TOKEN`. Update B10 in the same commit that records completion.

## Verification before PR creation

The copied commands from `ai/build.sh` run the local keychain unlock helper followed by
the Debug build. Verification completed: Debug build and all six focused `FeedbackGitHubComposerTests`
passed. The changed triad has six matching scenarios; the full triad audit found only an
existing missing scenario index in `UninstallPlanSpecs.md`. Shell syntax, workflow/form
parsing, source/tag archive comparison, and a mocked website publication passed.
The checked-in Swift formatter excludes all files, and no formatter binary is installed.
The website production build passed after installing its unchanged lockfile. Full website
lint still fails on the existing `react-hooks/set-state-in-effect` error at
`src/components/switcher-demo.tsx:346`; that file matches the remote main branch. Validate manifest/feed agreement with uploaded
release metadata, and preserve the original Sparkle signature. B5 clean-install and B6
installed-updater runtime checks remain open.
