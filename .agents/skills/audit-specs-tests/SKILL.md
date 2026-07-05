---
name: audit-specs-tests
description: Audit the project test suite for spec/test/code consistency. For every co-located triad in `src/` (`Foo.swift` + `FooSpecs.md` + `FooTests.swift`), it cross-checks that each XCTest method has a matching scenario line in the spec and vice-versa, flags drift between a scenario's description and the test's doc-comment, and reports orphan tests, orphan scenarios, and unpaired files. Use after adding or editing any `*Tests.swift` / `*Specs.md`, before committing a test change, or to get an overall health check of the suite.
---

# Audit Specs and Tests

Pair `FooTests.swift` and `FooSpecs.md` in the same folder. Each XCTest method must appear exactly once in the spec's `## Test scenarios` section:

```markdown
### A. <Group name>
- **testAFooDoesBar** — one-line description of what it pins.
```

A spec may cover several implementation types, so a missing same-name production file is a note, not an automatic error.

## Workflow

1. Enumerate:
   ```bash
   rg --files src | rg '(Tests\.swift|Specs\.md)$' | sort
   ```
   Also report test files under `unit-tests/`; the target is zero.
2. Extract test methods, immediately preceding intent comments, and `MARK` groups:
   ```bash
   rg -n '^\s*func test[A-Za-z0-9_]+\(' src/<path>/FooTests.swift
   ```
3. Parse scenario names, descriptions, and groups under each spec's `## Test scenarios`.
4. Report orphan tests, orphan or duplicate scenarios, group mismatches, material description drift, and unpaired files. Judge descriptions semantically.
5. For `*Testable.swift` and `*Resolver.swift`, note public/static entry points or decision cases with no scenario. Skip AppKit-only glue.
6. If asked to repair, regenerate only the scenario index from the tests and their comments. Do not invent behavior or edit tests.

## Reporting

Report a per-triad table with test/scenario counts and status, then findings with file and line, undocumented kernel branches, and the count of tests outside `src/`. If no drift exists, say so.
