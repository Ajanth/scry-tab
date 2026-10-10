# Release blockers

Tracks what still stands between `develop` and the first public download from
<https://scrytab.pages.dev>. Distribution is direct-download only; the Mac App Store is
**permanently foreclosed** by the GPL-3.0 licensing (see [B4](#b4-mac-app-store-is-closed)).

**Update this file when a blocker is cleared.** It is the single source of truth for release
readiness; do not track release state in commit messages or issues alone.

Legend: 🔴 blocks launch · 🟡 should fix before launch · ✅ done

---

## ✅ B1 — Developer ID signing is configured

`config/release.xcconfig:5` uses ScryTab's Developer ID Application identity:

```
CODE_SIGN_IDENTITY = Developer ID Application: Ajanth Kathirkamu (8M242ZY4BY)
```

The certificate and its private key are installed in the login Keychain, and
`security find-identity -v -p codesigning` reports the identity as valid. The stale Team ID
reference in `docs/luminare-appkit-ui-migration-plan.md` is updated. `APPLE_ID`,
`APPLE_PASSWORD`, `APPLE_TEAM_ID`, and `APPLE_P12_CERTIFICATE` exist in the GitHub `production`
environment (verified by secret name on 2026-08-07; GitHub does not expose their values). A local
Release build completed with the Developer ID identity, and `codesign --verify --deep --strict`
accepted the resulting app with bundle ID `com.perpro.scry-tab` and Team ID `8M242ZY4BY`.

> **This choice is permanent.** Per `AGENTS.md`, Developer ID, Team ID, and bundle ID must stay
> stable forever: Keychain items are bound to the code signature, so rotating any of them
> orphans every user's stored licence key and forces mass re-activation. Decide once, now,
> while there are zero users.

---

## ✅ B2 — Self-hosted release runner is operational

The repository-scoped `scrytab-local` runner is registered and online with the labels
`self-hosted`, `macOS`, `ARM64`, and `scry-tab-release`. It runs headlessly as its own per-user
launchd service with a dedicated installation and work directory, separate from the Convobee
runners. Self-hosted jobs do not consume GitHub-hosted runner minutes.

The release workflow is manual-only, restricted to `main`, and targets the dedicated runner label.
It uses `DEVELOPER_DIR` instead of changing the Mac's global Xcode selection, exposes secrets only
to the steps that need them, imports the Developer ID into a per-run keychain, and deletes both the
temporary keychain and generated secret-bearing files in an `always()` cleanup step.

An annotated `v0.0.1` baseline tag points to pre-signing commit `b3454de`, so semantic-release can
produce the intended `0.0.2` patch release. The no-secret runner smoke workflow completed on
`scrytab-local` in 11 seconds on 2026-08-07
([run 31217226134](https://github.com/Ajanth/scry-tab/actions/runs/31217226134)), including checkout,
toolchain reporting, and the ARM64 assertion. The runner returned to online and idle afterwards.

Alternatives remain available if release frequency grows:

| Option | Notes |
| --- | --- |
| [Tart](https://tart.run) macOS VM + ephemeral runner | Stronger host isolation, but the Mac currently has only about 20 GB free; reserve roughly 100–150 GB before adding macOS, Xcode, a VM clone, and build output. |
| Make the development repo public | GitHub-hosted macOS runners become free. Source is published per release anyway under GPL — this is a policy decision, not a technical one. |

OrbStack runs Convobee's Linux service containers, while its GitHub runner listeners are native
macOS processes. A Linux runner container cannot execute Xcode, codesign, or Apple's notarization
tools, so ScryTab's release job must run on macOS.

---

## ✅ B3 — Public download URLs follow the release manifest

The public `v0.0.2` release and its public-repository tag were deliberately deleted on 2026-08-08;
website commit `0cd8db3` then removed every direct `v0.0.2` reference and introduced
`/release.json` as the single website release manifest:

- the manifest used null `version`, `downloadUrl`, and `sourceUrl` values while no release existed;
- landing-page download controls read the manifest and render disabled instead of linking to 404s;
- `/source` exposes a direct Corresponding Source link only when the manifest names one; and
- `/appcast.xml` was a valid empty Sparkle feed with no withdrawn enclosure.

The release workflow now publishes the signed appcast and the DMG/source manifest after the public
GitHub assets exist. Deleting a GitHub release does not mutate a static Cloudflare Pages deployment,
so a future withdrawal must still clear both files; normal publication no longer requires editing
version strings in three separate website files.

Release `v0.4.0` is now current with its DMG, Sparkle ZIP, and Corresponding Source; `v0.3.0`
remains available as the previous public release. The live manifest names the `v0.4.0` DMG and
source archive, the single-item appcast encloses the matching ZIP, all three direct asset URLs
return 200, and the landing page enables its download controls. Public releases and tags `v0.0.3`
through `v0.1.2` were deleted on 2026-08-13; their former asset URLs return 404.

---

## ✅ B4 — Direct-download distribution is confirmed

GPL-3.0 is incompatible with the App Store's DRM and device limits (the VLC precedent). There
is no workaround short of relicensing, which needs consent from every AltTab contributor whose
code survives. ScryTab therefore ships exclusively as a notarized direct download.

`mac-app-store-publishing.md` in the repo root describes a path that is no longer available.
Treat it as historical.

---

## 🟡 B5 — First-run has never been tested on a clean machine

The notarized `v0.4.0` DMG is public and its downloaded bytes match GitHub's SHA-256 digest. The
release workflow passed staple validation, Gatekeeper, Developer ID, Team ID, and bundle-ID checks.
It still needs a first-run test on a Mac that has never run ScryTab:

- Gatekeeper accepts the DMG without a right-click → Open workaround
- `MoveToApplicationsFolder.promptIfNeeded()` (`src/App.swift:603`) handles translocation when
  the app is launched from `~/Downloads`
- The accessibility permission flow completes, including the guide window
- The first-run crash-report consent prompt appears exactly once and defaults to off
- No scheduled update request occurs before consent; Sparkle asks once on its second updater
  launch, declining leaves periodic checks off, accepting is reflected in Settings, and automatic
  installation defaults to off
- Uninstall (Settings → General) removes the LaunchAgent and both preference suites

---

## 🟡 B6 — Sparkle runtime update remains unproven

The live single-item appcast now advertises `v0.4.0`; its enclosure length matches the public ZIP,
and the release job generated its EdDSA signature through the verified keypair and signing path
(see [D5](#done)). Future release jobs replace the website feed only after the matching public ZIP
exists. `v0.4.0` is available to already-installed older copies, so the runtime path — an installed
app fetching, validating, downloading, and installing the update — can now be exercised on an
existing Mac. Fresh installations now use Sparkle's built-in permission request instead of enabling
periodic checks by default; existing persisted update choices remain intact. The clean-install
consent path is tracked under B5, while this blocker still covers a complete signed runtime update.

---

## 🟡 B7 — Privacy contact is a GitHub issue

`/privacy` routes privacy and erasure requests to the public issue tracker. GDPR expects a
contact route; a public tracker is a poor one for personal-data requests. Add a real address
once a domain is decided, and update `public/privacy/index.html` in `scrytab-cms`.

---

## ✅ B8 — Website work is committed and deployed

The landing-page copy/layout refresh, corrected legal ownership notices, and update-check privacy
disclosure are committed and deployed by Cloudflare Pages. Automated commits `c9c1f8b` and
`83541c7` publish the single-item `v0.4.0` appcast and release manifest. The `scry-tab`
`AXCallScheduler` lock fix is also committed (see [D9](#done)).

---

## ✅ B9 — Release pipeline is operational

[Release run 31218768138](https://github.com/Ajanth/scry-tab/actions/runs/31218768138) passed tests
and the signed Release build, then uploaded `ScryTab-0.0.2.zip` to Apple as submission
`903a9301-1388-45cf-889b-8bca310693d5`. Apple kept the submission `In Progress` for the full
15-minute wait, so `notarytool` exited 124 before any source archive, tag, public release, or
appcast was published. The `always()` cleanup succeeded and no CI keychain, temporary `.p12`, or
generated signing config remained on the host.

The per-artifact wait is now 45 minutes and the release job ceiling is 120 minutes. A manual,
read-only notarization-status workflow can query a submission without rebuilding or publishing.

[Release run 31241479026](https://github.com/Ajanth/scry-tab/actions/runs/31241479026) then completed
on the dedicated `scrytab-local` runner on 2026-08-08. Apple accepted both the ZIP submission
`cf06298f-bcb2-41b1-8188-be1dbe8d5cb8` and DMG submission
`4960e871-523c-4170-9976-2d2b1911f06d`. The workflow stapled and validated the app and DMG, and
Gatekeeper reported `source=Notarized Developer ID` for `Developer ID Application: Ajanth
Kathirkamu (8M242ZY4BY)`.

Independent checks downloaded the public artifacts and confirmed their GitHub SHA-256 digests,
strict nested code signatures, staple tickets, Gatekeeper acceptance, bundle ID
`com.perpro.scry-tab`, Team ID `8M242ZY4BY`, GPL source archive, and Sparkle signature. The public
release contained exactly the DMG, ZIP, and source tarball; the live Cloudflare appcast pointed to
the matching ZIP. The temporary CI keychain, `.p12`, and generated `local.xcconfig` were absent
after cleanup, and the runner returned online and idle.

[Release run 31350812858](https://github.com/Ajanth/scry-tab/actions/runs/31350812858)
published `v0.0.4` from commit `2c1e1df` in 5 minutes 9 seconds on 2026-08-10. Apple accepted the
ZIP submission `8fc70170-f85a-44de-8dbd-a19912bc3b3e` and DMG submission
`b000c0cb-f94d-48c3-afb4-93117c44ec12`; the workflow stapled both artifacts and Gatekeeper
reported `source=Notarized Developer ID`. Independent public downloads matched GitHub's SHA-256
digests, strict nested signatures, Team ID `8M242ZY4BY`, bundle ID `com.perpro.scry-tab`, Sparkle
signature and enclosure length, full GPL and dependency notices in both install formats, and the
tagged Corresponding Source with no private or release-only paths. The live Cloudflare manifest,
appcast, source page, privacy page, and landing bundle all matched `v0.0.4` and the corrected legal
copy; all three public asset URLs returned 200.

[Release run 31460527914](https://github.com/Ajanth/scry-tab/actions/runs/31460527914)
published `v0.0.5` from commit `1bb8e9f` in 4 minutes 32 seconds on 2026-08-11. Apple accepted the
ZIP submission `9a8670ec-f215-448b-969d-549cca77a670` and DMG submission
`af7ae813-012c-43de-840b-8914f0f3a19a`; every workflow step, including signing-material cleanup,
passed. Independent public downloads matched GitHub's SHA-256 digests, strict nested Developer ID
signatures, Team ID `8M242ZY4BY`, bundle ID `com.perpro.scry-tab`, Gatekeeper acceptance, staple
tickets, and the Sparkle signature and enclosure length. Both install formats contain the updated
acknowledgments and visible Contributors source document, and the source archive matches the
`v0.0.5` tag while satisfying the repository's required-input and private-path checks. The live
manifest, appcast, landing page, source page, and privacy page all return 200 and publish `v0.0.5`.

[Release run 31469414396](https://github.com/Ajanth/scry-tab/actions/runs/31469414396)
published `v0.1.0` from commit `dc3ae7d` in 4 minutes 50 seconds on 2026-08-11. Apple accepted the
ZIP submission `b9432933-4e33-48f5-afd8-a225ecfb8392` and DMG submission
`32b66aff-cdee-46e4-8456-ea95197079e6`; stapling, validation, Gatekeeper assessment, public asset
upload, website publication, and signing-material cleanup all passed. Fresh public downloads of
the DMG, Sparkle ZIP, and Corresponding Source matched GitHub's SHA-256 digests, while the live
appcast enclosure length matched the ZIP. Cloudflare deployed website commit `cb1ad64`; the
production manifest and appcast now publish `v0.1.0`, and the privacy page documents opt-in
periodic checks and the update endpoint's IP processing.

[Release run 31478815578](https://github.com/Ajanth/scry-tab/actions/runs/31478815578)
published `v0.1.1` from commit `08823c7` in 4 minutes 8 seconds on 2026-08-11. Apple accepted the
ZIP submission `2ced92f8-d9b6-4181-b32e-ceb828dda5ae` and DMG submission
`66092d81-9d63-446c-9eca-f2c596617f18`; stapling, validation, Gatekeeper assessment, public asset
upload, website publication, and signing-material cleanup all passed. Fresh public downloads of
the DMG, Sparkle ZIP, and Corresponding Source matched GitHub's SHA-256 digests. Format-aware ZIP
extraction independently passed strict nested signatures, stable Team and bundle identifiers,
Gatekeeper, and staple validation; both the binary and tagged source contain the approved About
attribution and GPL notice. Cloudflare deployed website commit `b7bf4da`, and the production
manifest and appcast publish `v0.1.1` with the public ZIP's matching enclosure length.

[Release run 31483073923](https://github.com/Ajanth/scry-tab/actions/runs/31483073923)
published `v0.1.2` from commit `896e0d6` in 4 minutes 3 seconds on 2026-08-11. Apple accepted the
ZIP submission `625cf77e-ae69-48c9-92b8-bdd4493c6aba` and DMG submission
`17bd5488-ea27-4de0-9500-dc647c68eca7`; tests, Developer ID build, stapling, Gatekeeper,
Sparkle signing, source packaging, Sentry upload, public asset upload, website publication, and
signing-material cleanup all passed. Independent downloads matched GitHub's SHA-256 digests;
format-aware extraction passed strict nested signatures, stable Team and bundle identifiers,
Gatekeeper, and staple validation for both install formats. Cloudflare deployed website commit
`187c365`, and the live manifest/appcast publish `v0.1.2` with the public ZIP's matching enclosure
length and EdDSA signature. B5 and B6 remain open because this does not replace their manual
clean-machine and installed-updater checks.

[Release run 31663851941](https://github.com/Ajanth/scry-tab/actions/runs/31663851941)
created the private `v0.2.0` tag and semantic-release commit after tests, Developer ID build,
notarization, stapling, Gatekeeper, Sentry upload, and single-item appcast generation all passed.
Corresponding Source packaging then stopped before public asset upload or website publication
because its README guard still required two retired attribution sentences. The live website and
public repository remained on `v0.1.2`, signing-material cleanup passed, and the runner returned
online and idle. The guard now validates the canonical AltTab-derived-portions wording and ScryTab
development date, with explicit diagnostics if either notice is lost. Local reproduction then
reached the archive privacy check and found a personal absolute path in the committed onboarding
plan; the plan now uses the repository-relative build-script path.

[Release run 31664248302](https://github.com/Ajanth/scry-tab/actions/runs/31664248302)
published `v0.2.1` from commit `585905d` in 3 minutes 51 seconds on 2026-08-13. Apple accepted the
ZIP submission `a54c3e14-c09a-4d95-8cb3-9f89ba9c20e4` and DMG submission
`2871b5e0-0892-4cd0-9cbd-c1ae338fbdeb`; tests, Developer ID build, notarization, stapling,
Gatekeeper, Sentry upload, single-item appcast generation, tagged source packaging, public asset
upload, website publication, and cleanup all passed. Independent downloads matched GitHub's
SHA-256 digests and passed strict nested-signature, Team ID, bundle ID, Gatekeeper, staple,
Corresponding Source, enclosure-length, and EdDSA checks. Cloudflare deployed appcast commit
`da9c86a` and manifest commit `7d64c71`. Public releases and tags `v0.0.3` through `v0.1.2` were
then deleted; all former asset URLs return 404. At that time, `v0.2.1` was the only public release
and tag, and its three asset URLs returned 200. The temporary keychain, `.p12`, and generated
`local.xcconfig` are absent, and the runner is online and idle. B5 and B6 remain open because this
does not replace their manual clean-machine and installed-updater checks.

[Release run 31931735592](https://github.com/Ajanth/scry-tab/actions/runs/31931735592) published
`v0.3.0` from semantic-release commit `4e4c84e` in 4 minutes 13 seconds on 2026-08-16. Tests,
the universal Release build, Developer ID signing, Apple notarization, stapling, Gatekeeper,
Sentry symbols, single-item appcast generation, tagged source packaging, public asset upload,
website publication, and signing-material cleanup all passed. The generated release notes and
appcast describe the Focus Set application-picker improvements: running and installed apps are
merged, deduplicated, and ordered deterministically. Independent verification downloaded all
three public assets, matched GitHub's SHA-256 digests, passed strict nested-signature, Team ID,
bundle ID, Gatekeeper, staple, Corresponding Source, enclosure-length, and EdDSA checks, and
confirmed the live manifest and appcast. Cloudflare deployed appcast commit `206f993` and
manifest commit `0fe818c`; the public `v0.3.0` release is non-draft with exactly the DMG, ZIP,
and source tarball. B5 and B6 remain open because this does not replace their manual clean-machine
and installed-updater checks.

[Release run 35513516751](https://github.com/Ajanth/scry-tab/actions/runs/35513516751) published
`v0.4.0` from semantic-release commit `6c0363d` in 8 minutes 55 seconds on 2026-09-20. All 623
tests passed, the universal Release build and Developer ID signing completed, Apple accepted both
notarization submissions, and stapling, Gatekeeper, Sentry symbols, single-item appcast
generation, tagged source packaging, public asset upload, website publication, and signing-material
cleanup all passed. Independent verification downloaded the public DMG, Sparkle ZIP, and
Corresponding Source, matched GitHub's SHA-256 digests, and passed strict nested-signature,
Team ID, bundle ID, Gatekeeper, staple, source, manifest, enclosure-length, and EdDSA checks.
Cloudflare deployed appcast commit `c9c1f8b` and manifest commit `83541c7`; the public `v0.4.0`
release is non-draft with exactly the DMG, ZIP, and source tarball. B5 and B6 remain open because
this does not replace their manual clean-machine and installed-updater checks.

The public release and its `scrytab-public` tag were later withdrawn on 2026-08-08 because the
source archive bundled Apple `notarytool`, stale proprietary wording, an incomplete xcbeautify
notice, and private operational files. That run remains useful historical pipeline evidence.

[Release run 31261703775](https://github.com/Ajanth/scry-tab/actions/runs/31261703775) then published
corrected `v0.0.3` from commit `0f3d7a2` in 4 minutes 27 seconds. Tests, Developer ID build, Apple
notarization and stapling, source packaging, Sentry upload, appcast signing, semantic-release,
public asset upload, website manifest publication, and signing-material cleanup all passed. The
public DMG and ZIP match their GitHub SHA-256 digests. Independent checks accepted the DMG and app
through Gatekeeper, verified strict nested signatures, Team ID `8M242ZY4BY`, bundle ID
`com.perpro.scry-tab`, the Sparkle signature and length, source exclusions, GPL wording,
xcbeautify notice, and local `xcrun notarytool` use. The source archive from that run was later
replaced under [D10](#done) because it archived pre-release `HEAD` instead of the tagged release
tree.

---

## ✅ B10 — Problematic v0.0.2 release is withdrawn

`gh release delete v0.0.2 --repo Ajanth/scrytab-public --cleanup-tag --yes` removed the complete
release and its public-repository tag on 2026-08-08. GitHub reported no releases immediately after
withdrawal; the tag lookup and former DMG, ZIP, and source-archive URLs still return 404. The
private source repository's `v0.0.2` tag remains as historical pipeline state.

The repository-side fixes are prepared: release notarization resolves the installed tool through
`xcrun notarytool`, the Apple binary and Xcode file reference are removed, contribution text now
matches GPL-3.0, the xcbeautify MIT notice is included, and `.gitattributes` excludes non-source
operational files. `package_source_tarball.sh` rejects those paths and personal absolute paths as a
regression guard.

Do not restore the old assets. Corrected `v0.0.3` came from a commit containing these fixes and was
downloaded independently to verify its digest, required build inputs, exclusions, GPL text, and
xcbeautify notice.

---

## 🟡 B10 — Canonical public repository cutover is prepared

`Ajanth/scry-tab` is the intended canonical public source, release, and issue repository.
The website stays in the separate `Ajanth/scrytab-cms` repository at
<https://scrytab.pages.dev/>. Its Cloudflare deployment and cross-repository publication
remain in place.

Preparation on 2026-10-10:

- Audited all remote branches, tags, and 34 pull-request heads: 267 reachable commits,
  4,943 objects, and 2,902 blobs. Gitleaks 8.30.1 reported no credential leaks; a separate
  full-blob pass found no private-key headers. History retains maintainer email metadata,
  personal development paths, release operations notes, and retired fixed local-signing
  passwords (rotation evidence remains in D11). Review this exposure before visibility changes.
- Set the repository description and homepage. Restricted the `production` environment to
  the `main` branch using a custom deployment branch policy. Release dispatch remains
  manual-only on `main`; the prepared workflow also refuses to release while the repo is private.
- Recreated only `v0.3.0` and `v0.4.0` in `scry-tab`, with identical notes and all six asset
  SHA-256 digests; `v0.4.0` is latest. Both source archives exactly match the existing
  canonical tags. The legacy repo's tags point to its placeholder commit instead of source;
  no existing tag was moved. Withdrawn releases were not recreated.
- Prepared app automation, feedback forms, documentation, and the separate website's
  manifest, appcast, source, and issue links for coordinated PRs. New releases use the local
  `GITHUB_TOKEN`; `WEBSITE_DISPATCH_TOKEN` retains write access to `scrytab-cms`.

The repository remains private during PR review; the live website continues to use the
working legacy assets. Merge the app PR, make the audited repository public, verify anonymous
asset access, and then merge the site PR so its deployment cannot advertise private downloads.
Keep the old assets available throughout; archive `scrytab-public` and retire
`PUBLIC_REPO_TOKEN` only after the live cutover checks pass. The rollout has a one-hour maximum
for any download outage and should require none. See
[the migration record](PUBLIC_REPOSITORY_MIGRATION.md) for evidence, commands, and rollback.
B5 and B6 remain open until their manual runtime checks are completed.

---

## First release: dry run

The `v0.0.2` dry run exercised the pipeline with no announcement and no users, then was withdrawn.
Repeat the publication, clean-install, and update steps with corrected future releases.

1. ✅ Push both repos; verify the live release state described in
   [B3](#b3--public-download-urls-follow-the-release-manifest).
2. ✅ Run the pipeline on `scrytab-local`. It produced, in `DerivedData/Build/Products/Release`:
   - `ScryTab-<version>.dmg` — signed, notarized, stapled
   - `ScryTab-<version>.zip` — what Sparkle downloads
   - `ScryTab-<version>-source.tar.gz` — GPL Corresponding Source
3. ✅ Current `v0.4.0` and previous `v0.3.0` have all three assets copied into `Ajanth/scry-tab`
   with verified digests (B10). Legacy public URLs stay available pending cutover; withdrawn
   releases remain withdrawn.
4. ✅ `scrytab-cms` serves the `v0.4.0` release manifest and matching single-item Sparkle feed;
   landing and source-page links resolve to public assets.
5. ⬜ Install the corrected DMG on a clean Mac and work through
   [B5](#-b5--first-run-has-never-been-tested-on-a-clean-machine).
6. ⬜ With `v0.3.0` installed, confirm the in-app updater finds, verifies, downloads, and installs
   its now-published `v0.4.0` successor. This is the real runtime test of
   [B6](#b6--sparkle-runtime-update-remains-unproven).

`package_and_notarize_release.sh` self-checks with `spctl --assess` and `stapler validate`, and
`package_source_tarball.sh` fails if the archive is missing build inputs or contains
`codesign.p12`, `codesign.key`, `codesign.crt`, or `config/local.xcconfig`. Do not bypass either.

---

## Done

Recorded so it is not re-litigated or accidentally reverted.

- **D1 — GPL-3.0 compliance** (`e03a55c`). ScryTab is an AltTab fork that had been relicensed
  proprietary, which was not permissible. `LICENCE.md` is verbatim GPL-3.0 again; attribution
  restored across README, acknowledgments, and contributors; and `NSHumanReadableCopyright`
  localized in 7 languages. The later binary-bundling and legal-owner audit is recorded under
  D12 below.
  `docs/contributors.md` has a frozen `## Built AltTab` section that
  `scripts/update_readme_and_website.sh` must never overwrite.
- **D2 — Releases moved to public URLs** (`659f5c7`). Everything pointed at the private repo and
  would have 404'd. Releases originally published to `Ajanth/scrytab-public`; B10 moves
  publication to the canonical `Ajanth/scry-tab` repository. The appcast enclosure and release
  notes follow; `update_website.sh` pushes the signed feed and manifest into `scrytab-cms`.
- **D3 — Uninstall** (`98526a3`). Deleting the app orphaned
  `~/Library/LaunchAgents/com.perpro.scry-tab.plist`. `UninstallPlan` resolves the removal set;
  `Uninstaller` clears both defaults suites before trashing their files.
- **D4 — Notarized DMG** (`98526a3`). The zip stays for Sparkle; the DMG is what the website links.
- **D5 — Sparkle signing key** (`3fa450b`). `SUPublicEDKey` was byte-identical to AltTab's — we
  never held the private key, so every update would have failed verification. Regenerated with
  Sparkle 2.9.1's `generate_keys`; new public key `WVns7P3X+/bnZRQrE26fiVAMay0mie418X+hHVKlX6w=`.
  Separately, `update_appcast.sh` used `sign_update -s`, removed in Sparkle 2.9, so appcast
  signing was broken regardless of key. Verified by round-trip signing plus negative controls
  (tampered payload and foreign key both rejected).
- **D6 — Website** (`d94c85e`, `2bc094d`, `0cd8db3`). `/source` GPL offer, `/privacy`,
  `appcast.xml` as a real static asset, release-manifest-driven download controls, and source as a
  peer download button.
- **D7 — `scrytab-public` metadata.** Description, homepage, README rewritten; GPL-3.0 added and
  detected by GitHub.
- **D8 — CI secrets.** `SPARKLE_ED_PRIVATE_KEY` and `WEBSITE_DISPATCH_TOKEN` are set.
  Canonical publication uses `GITHUB_TOKEN` with `contents: write`; the legacy
  `PUBLIC_REPO_TOKEN` can be retired after B10 cutover. `WEBSITE_DISPATCH_TOKEN` still needs
  `contents: write` on `scrytab-cms`.
- **D9 — `AXCallScheduler` data race.** `queueForPid` read `unresponsivePids` without holding
  `lock`, while `attemptBlock` inserts/removes it from the AX worker queues and
  `Applications.removeUnresponsivePid` removes it on app teardown. An unsynchronized `Set` read
  racing a resize is undefined behavior, not just stale routing. The read is now taken under the
  lock; no caller holds it, so the non-recursive `NSLock` cannot deadlock.
- **D10 — Corresponding Source uses tagged release state.** The original public
  `ScryTab-0.0.3-source.tar.gz` read the working-tree `0.0.3` for its filename while
  `git archive HEAD` exported `VERSION.txt` as `0.0.1` and a changelog ending at `0.0.2`. The asset
  was replaced in place on 2026-08-09 with SHA-256
  `42c6de76f131866668043c82f8cac187f168f57222c20eb68255fecb731031da`; its version, changelog,
  appcast, application-source blob, GPL text, build inputs, and exclusions were reverified after a
  fresh public download. Future releases commit `VERSION.txt`, package only after semantic-release
  creates `v<version>`, and fail if the tag or archived version differs from the requested version.
- **D11 — Published local-signing passwords are retired.** The corrected `v0.0.3` archive omits
  the three scripts that contained the old credentials. Current scripts stopped embedding
  `password` and `local-dev-password`; local setup creates a random per-user password at
  `~/Library/Application Support/ScryTab/local-signing-password` with mode `0600`, and credential
  handling no longer uses shell tracing. Source packaging rejects either fixed-password literal
  if it is reintroduced. The existing self-signed Debug certificate and `scry-tab.keychain` were
  regenerated on 2026-08-09. The old password was rejected after locking the new keychain, while
  the login-Keychain Developer ID identity remained unchanged.
- **D12 — Licence ownership and shipped notices are corrected.** A follow-up audit found that
  `Rogue Works` was neither ScryTab's legal rights holder nor an available Australian business
  name, the standalone About window omitted parts of GPL-3.0 §0's Appropriate Legal Notices, and
  the app bundle omitted the GPL text and full Sparkle/Sentry binary notices. The human-readable
  notice in the app bundle distinguishes ScryTab's copyright from the copyright in retained
  AltTab-derived portions without promotional lineage wording or singling out one contributor;
  the About surface displays the no-warranty and redistribution notice in every entry point;
  AltTab-derived copyright attribution and the full contributor record remain in the bundled
  acknowledgments and Contributors documents without rendering the developer and translator rolls
  in About;
  `LICENCE.md` and `third-party-notices.md` are app resources included in both the Sparkle ZIP and
  DMG; packaging fails if those resources or their required notices are absent; and the source
  archive records ScryTab's modifications and relevant 2026 date. The website separates its own
  copyright from the GPL-covered software and no longer claims rights for `Rogue Works`.
> **Back up the Sparkle private key.** It lives in the login Keychain and in the
> `SPARKLE_ED_PRIVATE_KEY` secret. Lose both and you cannot ship updates to anyone who already
> installed ScryTab — they would each need a manual reinstall. It is the one secret with no
> recovery path.
