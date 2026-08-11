# Update policy consent state

## Purpose

`UpdatePolicyConsentState` distinguishes registered defaults from choices persisted in the app's
`UserDefaults` domain. Fresh installations must leave Sparkle's automatic-check permission
unanswered, while existing ScryTab and Sparkle choices remain authoritative.

## Behavior

- An empty persistent domain has neither a stored ScryTab policy nor a Sparkle permission response.
- A persisted `updatePolicy` value is an explicit app-setting choice that may be applied to Sparkle.
- Presence of `SUEnableAutomaticChecks` is a Sparkle response whether its value is `true` or `false`.
- Registered defaults are excluded because callers read the persistent domain rather than
  `object(forKey:)`.

## Test scenarios

- **testFreshDomainHasNoStoredChoices** — an empty domain leaves both choices unanswered.
- **testRegisteredDefaultsDoNotCountAsStoredChoices** — registered values remain absent from the persistent domain and cannot grant consent.
- **testStoredAppPreferenceCanBeApplied** — persisted `updatePolicy` is recognized without inventing a Sparkle response.
- **testAcceptedSparkleResponseCanBeSynchronized** — persisted `SUEnableAutomaticChecks = true` is recognized.
- **testDeclinedSparkleResponseCanBeSynchronized** — persisted `SUEnableAutomaticChecks = false` is recognized by presence, not truthiness.
