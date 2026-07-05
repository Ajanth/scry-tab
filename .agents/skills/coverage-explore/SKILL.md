---
name: coverage-explore
description: Measure project test coverage and record it as documentation. Runs the Test scheme with coverage into a throwaway result bundle, parses the per-file/region report, refreshes the per-feature badge atop each `*Specs.md` and the root `src/coverage.md` table, then suggests the highest-value missing tests. These two markdown outputs are the ONLY stored coverage — no lcov/html/xcresult is kept, and routine test runs don't gather coverage. Use to refresh coverage docs, find untested kernel branches, or decide what to test next.
---

# Coverage Exploration

Measure decision kernels, not aggregate AppKit glue. Store only the badges in `*Specs.md` and the table in `src/coverage.md`; keep no result bundle, HTML, or lcov output.

## Workflow

1. Measure into a temporary bundle:
   ```bash
   PROJECT="$(find . -maxdepth 1 -name '*.xcodeproj' -print -quit)"
   test -n "$PROJECT"
   rm -rf /tmp/altcov.xcresult
   set -o pipefail && xcodebuild test \
     -project "$PROJECT" -scheme Test -configuration Release \
     -enableCodeCoverage YES -resultBundlePath /tmp/altcov.xcresult | scripts/xcbeautify
   ```
   If the build is red, stop and report — coverage on a failing suite is meaningless.
2. Parse `xcrun xccov view --report --json /tmp/altcov.xcresult`. Use `xcrun xccov view --file <path>` for line-level gaps.
3. Rewrite `src/coverage.md` with compiled non-test `src/` files sorted worst-first as `| NN% (covered/executable) | path |`; preserve the scope note and update the date.
4. Update accepted per-spec coverage badges with the new percentage and date. Preserve notes for intentionally partial files.
5. For kernels below 100%, map uncovered regions to behavior and suggest a matching spec scenario and focused XCTest. Do not add tests unless asked.
6. Delete `/tmp/altcov.xcresult`.

## Reporting

Report kernel coverage and deltas, ranked behavioral gaps, suggested scenarios/tests, changed documentation, and intentionally partial files.
