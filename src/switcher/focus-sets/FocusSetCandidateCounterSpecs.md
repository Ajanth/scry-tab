# FocusSetCandidateCounter — Specs

## Summary

`FocusSetCandidateCounter` is a Foundation-only preview kernel for Focus Sets profile-scoped
candidate counts. It accepts immutable `WindowState` / `ApplicationState` facts, a precomputed
preferred-screen fact, a compiled `FocusSetResolver`, and a snapshot of every
`WindowFilterResolver` input. It never reads or mutates live window, preference, session, or
AppKit state.

## Behavior & edge cases

- Membership is resolved by `FocusSetResolver` before each candidate enters the normal
  `WindowFilterResolver` predicate.
- `.none` and `.allWindows` apply only the normal profile filters. `.set(id:)` includes exact
  saved app membership, and `.unassigned` includes apps absent from every saved set.
- All normal app, exception, windowless, fullscreen, minimized, Space, screen, and tab filters
  retain `WindowFilterResolver` semantics.
- The preferred-screen Boolean is already materialized on each candidate; the kernel never asks
  `Window` or screen APIs for it.
- Main-window profile grouping counts at most one visible candidate for each application PID.
  All-windows grouping counts every visible candidate.
- Empty and stale selected sets produce zero candidates. An empty set does not assign any app.
- Overlapping sets intentionally count their shared applications in either selected scope.

---

## Test scenarios

### A. Scope membership
- **testAllWindowsScopeAppliesProfileFiltersWithoutMembershipRestriction** — all-windows retains normal filters while admitting assigned and unassigned apps.
- **testCountsResolveMultipleScopesFromOneProfileSnapshot** — multiple scopes reuse one normal-profile snapshot while applying membership independently.
- **testNoScopeAppliesProfileFiltersWithoutMembershipRestriction** — ordinary no-scope counting ignores saved membership.
- **testSetScopeCountsOnlyIncludedApplications** — a selected set excludes an otherwise visible non-member.
- **testUnassignedScopeExcludesMembershipInEverySet** — unassigned keeps only apps outside the union of saved sets.

### B. Profile filters
- **testNormalFilterFactsAreAppliedBeforeCounting** — phantom, exception, app, window, Space, screen, and tab filters all compose before a count.
- **testExcludeFrontmostAndNonVisibleSpaceFiltersAreApplied** — non-active and non-visible-space profile filters use their supplied runtime facts.
- **testPreferredScreenFactFiltersCandidates** — a precomputed off-preferred-screen candidate is excluded when requested.
- **testWindowlessCandidatesObeyProfileFilter** — windowless candidates show by default and disappear when the profile hides them.

### C. Grouping
- **testMainWindowGroupingCountsOneVisibleCandidatePerApplication** — main-window grouping counts one visible child candidate per application.
- **testAllWindowsGroupingCountsEachVisibleCandidate** — all-windows grouping preserves every visible child candidate.

### D. Membership edge cases
- **testOverlappingSetsCountSharedApplicationInEachScope** — a shared app counts in either selected overlapping set and never as unassigned.
- **testEmptySetHasNoSelectedCandidates** — an empty set has no selected candidates while its apps remain unassigned.
