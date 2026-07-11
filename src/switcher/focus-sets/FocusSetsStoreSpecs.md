# FocusSetsStore — Specs

## Summary

`FocusSetsStore` owns the single `focusSets` JSON value. It parses persisted data independently
from the generic preference cache, so malformed values never cause a preference reset. The store
uses only Foundation and receives its `UserDefaults` instance at construction.

## Behavior & edge cases

- A malformed root JSON value returns an empty current-version configuration without replacing the
  stored value. The returned profile reference can still resolve to the supplied fallback.
- A malformed set is discarded without affecting valid sibling sets. Malformed rules are discarded
  while their otherwise valid set remains, including when that leaves an empty set.
- A rule requires a non-blank stable application bundle identifier. Cached application names are
  presentation-only, so a saved name remains available when its application is not running.
- A missing, empty, or non-string direct shortcut decodes as unassigned without discarding its set.
- Writes preserve unknown root, set, and rule fields from the existing JSON when the stable set
  identifier and rule bundle identifier are each unambiguous, while updating known fields.
- Reading a legacy V1 configuration migrates it to the current version while preserving unknown
  root and nested fields. Higher future versions remain intact.
- The persisted profile reference is matched exactly against supplied stable shortcut identifiers.
  A missing reference deterministically rebinds to the first non-blank supplied identifier and is
  written back. With no supplied identifiers, the existing reference is retained.
- Explicit writes normalize invalid versions and blank rule identifiers, then serialize a
  versioned configuration that can be read back unchanged.

---

## Test scenarios

Mirrors `FocusSetsStoreTests.swift` 1:1.

### A. Tolerant parsing
- **testMalformedRootKeepsStoredStringAndReturnsFallback** — malformed JSON remains untouched while the returned empty configuration uses the first available profile.
- **testMalformedSetAndRulesKeepValidSiblingSets** — invalid set and rule shapes are discarded without losing valid sets or valid rules beside them.
- **testReadDropsDuplicateSetIdentifiers** — duplicate persisted set identifiers retain only the first set, so one scope cannot merge their app membership.
- **testBlankBundleIdentifiersAreRejectedOnReadAndWrite** — blank stable identities are removed from both persisted input and an explicit write.
- **testWriteDropsDuplicateSetIdentifiers** — an explicit configuration with duplicate set identifiers persists only the first set.
- **testReadKeepsCachedNameForUnavailableApplication** — a saved display name remains readable without any live-application dependency.
- **testMalformedShortcutValueIsIgnoredWithoutDroppingSet** — a malformed optional shortcut is ignored while its otherwise valid set remains.

### B. Forward compatibility
- **testReadMigratesV1WhilePreservingUnknownFields** — a V1 configuration migrates to the current version without losing unknown root or set fields.
- **testWritePreservesUnknownFieldsAndOptionalTitle** — unknown root, set, and rule fields survive a read/write cycle while optional `titleContains` remains available.
- **testWritePreservesUnknownRuleFieldsWhenCachedNameChanges** — updating a rule’s presentation-only cached app name retains unrecognized fields on its unambiguous persisted rule.

### C. Profile rebinding and serialization
- **testReadRebindsMissingProfileToFirstAvailableIdentifier** — a deleted profile reference selects and persists the first non-blank supplied identifier.
- **testWriteAndReadPreservesEmptyFocusSet** — an explicitly saved Focus Set with no applications survives a write/read cycle.
- **testWriteAndReadRoundTrip** — a normalized multi-set configuration survives a write/read cycle exactly.
