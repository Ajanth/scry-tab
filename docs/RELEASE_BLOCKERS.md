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

## ✅ B3 — Release repositories and public URLs are ready

The app repo's signing, release workflow, runner, and baseline-tag changes are pushed to `main`.
The website's release-link, source-offer, appcast, and privacy commits are also pushed. The local
rotating-hero work remains uncommitted and was not included in the deployment.

```
scry-tab      main   synchronized with origin/main
scrytab-cms   main   synchronized with origin/main; unrelated hero changes remain local
```

The Cloudflare Pages deployment was verified on 2026-08-07:

```bash
/appcast.xml   200 application/xml; first line starts with <?xml
/source        200; first line starts with <!doctype html>
/privacy       200; first line starts with <!doctype html>
```

`/appcast.xml` previously returned `index.html` with a 200 status, which silently breaks every
Sparkle update check. A 200 alone is not proof; check the body.

---

## ✅ B4 — Direct-download distribution is confirmed

GPL-3.0 is incompatible with the App Store's DRM and device limits (the VLC precedent). There
is no workaround short of relicensing, which needs consent from every AltTab contributor whose
code survives. ScryTab therefore ships exclusively as a notarized direct download.

`mac-app-store-publishing.md` in the repo root describes a path that is no longer available.
Treat it as historical.

---

## 🟡 B5 — First-run has never been tested on a clean machine

Depends on B1 and a real notarized DMG. Test on a Mac that has never run ScryTab:

- Gatekeeper accepts the DMG without a right-click → Open workaround
- `MoveToApplicationsFolder.promptIfNeeded()` (`src/App.swift:603`) handles translocation when
  the app is launched from `~/Downloads`
- The accessibility permission flow completes, including the guide window
- The first-run crash-report consent prompt appears exactly once and defaults to off
- Uninstall (Settings → General) removes the LaunchAgent and both preference suites

---

## 🟡 B6 — Sparkle runtime verification is unproven

The keypair and signing path are verified (see [D5](#done)), but the runtime path — the app
fetching a real appcast and validating it against `SUPublicEDKey` — cannot be exercised until a
release exists. Covered by the dry run below.

---

## 🟡 B7 — Privacy contact is a GitHub issue

`/privacy` routes privacy and erasure requests to the public issue tracker. GDPR expects a
contact route; a public tracker is a poor one for personal-data requests. Add a real address
once a domain is decided, and update `public/privacy/index.html` in `scrytab-cms`.

---

## 🟡 B8 — Uncommitted work in `scrytab-cms`

Not a blocker by itself, but it will be swept into someone's commit if ignored.

- `scrytab-cms`: `src/components/sections/hero.tsx` and the `heroVariants` block in
  `src/content/landing.ts` — an in-progress rotating-hero feature.

The `scry-tab` half is cleared: the `AXCallScheduler` lock fix is committed (see [D9](#done)).

---

## 🔴 B9 — First notarization exceeded the original CI wait limit

[Release run 31218768138](https://github.com/Ajanth/scry-tab/actions/runs/31218768138) passed tests
and the signed Release build, then uploaded `ScryTab-0.0.2.zip` to Apple as submission
`903a9301-1388-45cf-889b-8bca310693d5`. Apple kept the submission `In Progress` for the full
15-minute wait, so `notarytool` exited 124 before any source archive, tag, public release, or
appcast was published. The `always()` cleanup succeeded and no CI keychain, temporary `.p12`, or
generated signing config remained on the host.

The per-artifact wait is now 45 minutes and the release job ceiling is 120 minutes. A manual,
read-only notarization-status workflow can query the original submission without rebuilding or
publishing. B9 clears after Apple accepts a complete rerun and both the app and DMG pass stapling
and Gatekeeper validation.

---

## First release: dry run

Cut `v0.0.2` with no announcement. It exercises every unproven path at once, while there are no
users to break.

1. Push both repos; verify the URLs in [B3](#b3--release-repositories-and-public-urls-are-ready).
2. Run the pipeline (locally or on a runner). It must produce, in `DerivedData/Build/Products/Release`:
   - `ScryTab-<version>.dmg` — signed, notarized, stapled
   - `ScryTab-<version>.zip` — what Sparkle downloads
   - `ScryTab-<version>-source.tar.gz` — GPL Corresponding Source
3. Confirm all three attach to a release on **`Ajanth/scrytab-public`**, not the private repo.
4. Confirm `scrytab-cms` received the updated `public/appcast.xml` and redeployed.
5. Install the DMG on a clean Mac and work through [B5](#-b5--first-run-has-never-been-tested-on-a-clean-machine).
6. With v0.0.2 installed, cut v0.0.3 and confirm the in-app updater finds, verifies, downloads,
   and installs it. This is the only real test of [B6](#-b6--sparkle-runtime-verification-is-unproven).

`package_and_notarize_release.sh` self-checks with `spctl --assess` and `stapler validate`, and
`package_source_tarball.sh` fails if the archive is missing build inputs or contains
`codesign.p12`, `codesign.key`, `codesign.crt`, or `config/local.xcconfig`. Do not bypass either.

---

## Done

Recorded so it is not re-litigated or accidentally reverted.

- **D1 — GPL-3.0 compliance** (`e03a55c`). ScryTab is an AltTab fork that had been relicensed
  proprietary, which was not permissible. `LICENCE.md` is verbatim GPL-3.0 again; attribution
  restored across README, acknowledgments, and contributors; `NSHumanReadableCopyright`
  localized in 7 languages; the About pane satisfies GPL-3.0 §0 Appropriate Legal Notices.
  `docs/contributors.md` has a frozen `## Built AltTab` section that
  `scripts/update_readme_and_website.sh` must never overwrite.
- **D2 — Releases moved to public URLs** (`659f5c7`). Everything pointed at the private repo and
  would have 404'd. Releases now publish to `Ajanth/scrytab-public`; the appcast enclosure and
  release notes follow; `update_website.sh` pushes the signed appcast into `scrytab-cms`.
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
- **D6 — Website** (`d94c85e`, `2bc094d`). `/source` GPL offer, `/privacy`, `appcast.xml` as a
  real static asset, download CTA repointed, source as a peer download button.
- **D7 — `scrytab-public` metadata.** Description, homepage, README rewritten; GPL-3.0 added and
  detected by GitHub.
- **D8 — CI secrets.** `SPARKLE_ED_PRIVATE_KEY`, `PUBLIC_REPO_TOKEN`, `WEBSITE_DISPATCH_TOKEN`
  are set. `PUBLIC_REPO_TOKEN` needs `contents: write` on `scrytab-public`;
  `WEBSITE_DISPATCH_TOKEN` needs `contents: write` on `scrytab-cms`.
- **D9 — `AXCallScheduler` data race.** `queueForPid` read `unresponsivePids` without holding
  `lock`, while `attemptBlock` inserts/removes it from the AX worker queues and
  `Applications.removeUnresponsivePid` removes it on app teardown. An unsynchronized `Set` read
  racing a resize is undefined behavior, not just stale routing. The read is now taken under the
  lock; no caller holds it, so the non-recursive `NSLock` cannot deadlock.

> **Back up the Sparkle private key.** It lives in the login Keychain and in the
> `SPARKLE_ED_PRIVATE_KEY` secret. Lose both and you cannot ship updates to anyone who already
> installed ScryTab — they would each need a manual reinstall. It is the one secret with no
> recovery path.
