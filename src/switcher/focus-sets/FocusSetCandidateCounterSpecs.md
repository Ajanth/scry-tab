# FocusSetCandidateCounter — Specs

## Summary

`FocusSetCandidateCounter` is a Foundation-only preview kernel for Focus Sets candidate counts. It
accepts immutable `WindowState` / `ApplicationState` facts, a compiled `FocusSetResolver`, and the
explicit Focus Sets visibility/shared-grouping snapshot. It never reads or mutates live window,
preference, session, screen, or AppKit state.

## Behavior & edge cases

- Membership is resolved by `FocusSetResolver` before each candidate enters the normal
  `WindowFilterResolver` predicate.
- `.none` and `.allWindows` apply only the Focus Sets visibility policy. `.set(id:)` includes exact
  saved app membership, and `.unassigned` includes apps absent from every saved set.
- The standard policy shows every app across all Spaces and screens, including hidden, windowless,
  fullscreen, and minimized states; windowless apps sort at the end, while phantom windows and
  configured exceptions remain excluded.
- Shared tab grouping retains `WindowFilterResolver` tab semantics without materializing any
  preferred-screen fact.
- Main-window shared grouping counts at most one visible candidate for each application PID.
  All-windows grouping counts every visible candidate.
- Empty and stale selected sets produce zero candidates. An empty set does not assign any app.
- Overlapping sets intentionally count their shared applications in either selected scope.

---

## Test scenarios

### A. Scope membership
- **testAllWindowsScopeAppliesPolicyWithoutMembershipRestriction** — all-windows retains the Focus Sets safety policy while admitting assigned and unassigned apps.
- **testCountsResolveMultipleScopesFromOnePolicySnapshot** — multiple scopes reuse one policy snapshot while applying membership independently.
- **testNoScopeAppliesPolicyWithoutMembershipRestriction** — no-scope counting ignores saved membership while retaining the supplied Focus Sets policy.
- **testSetScopeCountsOnlyIncludedApplications** — a selected set excludes an otherwise visible non-member.
- **testSetScopeConjoinsMembershipWithPolicy** — a selected set keeps only candidates that pass both exact app membership and the Focus Sets policy.
- **testUnassignedScopeExcludesMembershipInEverySet** — unassigned keeps only apps outside the union of saved sets.

### B. Focus Sets visibility policy
- **testStandardPolicyIncludesAllVisibilityStatesWhileKeepingSafetyExclusions** — standard policy includes hidden, windowless, fullscreen, minimized, other-app, and other-Space candidates while excluding phantoms and exceptions.
- **testSharedTabGroupingControlsTabbedCandidates** — the shared tab setting decides whether tab candidates remain separate.

### C. Grouping
- **testMainWindowGroupingCountsOneVisibleCandidatePerApplication** — main-window grouping counts one visible child candidate per application.
- **testAllWindowsGroupingCountsEachVisibleCandidate** — all-windows grouping preserves every visible child candidate.

### D. Membership edge cases
- **testOverlappingSetsCountSharedApplicationInEachScope** — a shared app counts in either selected overlapping set and never as unassigned.
- **testEmptySetHasNoSelectedCandidates** — an empty set has no selected candidates while its apps remain unassigned.
