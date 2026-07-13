# ScryTab Mac App Store publishing guide

**Last verified:** 2026-07-11

## Important project assessment

The current ScryTab build is designed for direct distribution outside the Mac App Store. Publishing it to the Mac App Store will require a separate compatible configuration or target.

Current high-risk incompatibilities:

1. App Sandbox is disabled in [`scry_tab.entitlements`](/Users/ajanth/development/perpro/scry-tab/scry_tab.entitlements:5). App Sandbox is mandatory for Mac App Store distribution.
2. The project links Apple's private `SkyLight.framework` in [`project.pbxproj`](/Users/ajanth/development/perpro/scry-tab/scry-tab.xcodeproj/project.pbxproj:370). Apple requires App Store apps to use public APIs only.
3. The app embeds Sparkle and enables automatic update checks in [`Info.plist`](/Users/ajanth/development/perpro/scry-tab/Info.plist:47). Mac App Store apps must use the Mac App Store for updates.
4. The app contains custom installation and updater behavior that must be removed or disabled for the App Store build.
5. Sentry and other third-party SDKs must be reviewed for sandbox compatibility and accurately included in App Privacy declarations.

Relevant Apple requirements:

- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Current Xcode support and deployment targets](https://developer.apple.com/support/xcode)

The safest architecture is:

| Build | Distribution | Signing | Update mechanism |
| --- | --- | --- | --- |
| Direct build | GitHub Releases | Developer ID Application | Sparkle or manual release process |
| App Store build | Mac App Store | Mac App Distribution | Mac App Store |

Do not try to submit the current direct-distribution build unchanged.

## Cost and account choice

The Apple Developer Program currently costs **$99 USD per year**, charged in local currency where available. The fee applies even if ScryTab is free to users.

Enrollment requires an Apple Account with two-factor authentication:

- [Apple Developer Program enrollment](https://developer.apple.com/help/account/membership/program-enrollment/)

Choose one account type:

### Individual

Your personal legal name appears as the seller on the App Store.

### Organization

The legal company name appears as the seller. Apple requires a legal entity, D-U-N-S number, legal authority to bind the organization, work email, and a publicly available company website associated with the organization.

If ScryTab is currently a personal project, enrolling as an individual is usually the fastest path. If the App Store seller must be a company or brand, establish the legal entity and domain first.

## Step 1: Enroll

1. Go to [developer.apple.com/programs](https://developer.apple.com/programs/).
2. Sign in with the Apple Account that will own the app.
3. Enable two-factor authentication if it is not already enabled.
4. Enroll in the Apple Developer Program.
5. Complete identity verification and pay the annual membership fee.
6. Wait for membership activation.

Once active, the same Apple Account gives access to Certificates, Identifiers & Profiles and App Store Connect.

## Step 2: Create the App ID and App Store Connect record

Use the existing bundle identifier unless there is a strong reason to change it:

```text
com.perpro.scry-tab
```

Register an explicit App ID matching the bundle identifier. Then in App Store Connect:

1. Open **Apps**.
2. Click **+ → New App**.
3. Select **macOS**.
4. Enter `ScryTab` as the app name, if available.
5. Select the matching bundle ID.
6. Enter an internal SKU, for example `scrytab-macos-1`.
7. Create the app record.

Apple requires the app record before the first build is uploaded:

- [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)

## Step 3: Create the App Store build configuration

Create a separate App Store configuration or target so the direct-download build can retain its own behavior.

The App Store configuration should:

- Enable App Sandbox.
- Use only public Apple APIs.
- Remove the private SkyLight and CGS dependencies.
- Remove Sparkle and its updater helpers.
- Remove custom self-installation behavior.
- Ensure all required functionality works while sandboxed.
- Keep login-at-startup behavior explicitly user-controlled.
- Review Sentry and every other third-party SDK for sandbox and privacy compliance.
- Increment both the marketing version and build number for every upload.

For signing, use automatic signing initially, or manually create:

- **Mac App Distribution** certificate.
- **Mac App Store Connect** provisioning profile.

Apple documentation:

- [Certificate types](https://developer.apple.com/help/account/create-certificates/certificates-overview)
- [Create a Mac App Store provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)

## Step 4: Prepare metadata and legal information

Required preparation includes:

- App name
- Subtitle
- Description
- Keywords
- Primary and secondary category
- Support URL
- Marketing URL
- Copyright
- Age rating
- App Review notes
- Export-compliance answers
- Privacy-policy URL
- App Privacy data declarations
- Mac screenshots

### Privacy policy

Apple requires a privacy-policy URL for macOS apps. The policy should explain:

- Whether ScryTab collects crash reports.
- Whether Sentry or other SDKs collect diagnostics.
- Whether window titles, app names, or usage data leave the Mac.
- What data is retained.
- How users can contact you or request deletion where applicable.

The policy should also be accessible from inside the app:

- [App Privacy requirements](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App Privacy reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/)

### Mac screenshots

Upload at least one screenshot. Accepted Mac screenshot sizes include:

```text
1280 × 800
1440 × 900
2560 × 1600
2880 × 1800
```

Screenshots must show the real macOS experience and should not include unrelated website or competing-platform imagery.

- [Mac screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

### App Review notes

Explain exactly how the reviewer can test ScryTab:

1. Launch ScryTab.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Enable ScryTab.
4. Use the default shortcut to open the switcher.
5. Select a window and verify that it receives focus.
6. Test search and window actions.

Mention that Screen Recording is not required, if that remains true in the App Store build.

### EU Digital Services Act

If distributing in the EU, complete Apple's DSA trader-status declaration. Apple may display trader contact information on the App Store product page:

- [EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)

## Step 5: Upload with Xcode

1. Open the App Store-compatible project configuration in Xcode.
2. Confirm the correct Team and bundle identifier.
3. Select the **Release** configuration for the App Store build.
4. Choose **Product → Archive**.
5. Open **Window → Organizer**.
6. Select the archive.
7. Click **Distribute App**.
8. Choose **Mac App Store**.
9. Choose **Upload**.
10. Wait for Apple's processing to finish.

Apple also supports Transporter, Xcode Cloud, and automated App Store Connect uploads:

- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)

## Step 6: Test with TestFlight

After Apple processes the build:

1. Open the build in App Store Connect.
2. Add internal testers first.
3. Create an external testing group if needed.
4. Test a clean install.
5. Test Accessibility permission setup.
6. Test shortcuts, window focus, search, preferences, login behavior, and app removal.
7. Test upgrades from the previous TestFlight build.

Mac TestFlight builds can be tested for up to 90 days. The first external build may require App Review:

- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)

## Step 7: Submit the app

1. Open the macOS version in App Store Connect.
2. Complete every required metadata and compliance field.
3. Select the processed build.
4. Click **Add for Review**.
5. Review the draft submission.
6. Click **Submit for Review**.

- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)

After approval, choose automatic release or manually release the version. Apple hosts the Mac App Store download and updates.

## CI/CD after the first upload

The current app workflow only triggers on `master`:

- [`ci_cd.yml`](/Users/ajanth/development/perpro/scry-tab/.github/workflows/ci_cd.yml:1)

If the app's production branch is `main`, change the workflow trigger accordingly.

For automated App Store uploads, use either:

- Xcode Cloud, or
- GitHub Actions with an App Store Connect API key, signing certificate, provisioning profile, and securely stored secrets.

Keep the direct-download notarization workflow separate from the App Store upload workflow. A Mac App Store build should not be notarized and stapled in the same way as the Developer ID build.

## Recommended execution order

1. Deploy the website through Cloudflare Pages.
2. Keep direct notarized builds on GitHub Releases.
3. Add and publish the privacy-policy page.
4. Enroll in Apple Developer.
5. Create the App Store configuration or target.
6. Remove private APIs and non-App-Store update/install behavior.
7. Upload to TestFlight.
8. Resolve sandbox and review issues.
9. Submit the Mac App Store version.
10. Change the website CTA to the App Store listing after approval.
