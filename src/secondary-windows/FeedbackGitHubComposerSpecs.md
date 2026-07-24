# FeedbackGitHubComposer — Specs

## Summary

`FeedbackGitHubComposer` builds public GitHub issue-composer URLs for ScryTab feedback.
The private app repository stays closed; users continue on `scrytab-public` with YAML issue forms.
Title and details may be prefilled via query parameters. Diagnostic/debug profiles are never placed in the URL.

## Test scenarios

Mirrors `FeedbackGitHubComposerTests.swift` 1:1.

### A. Templates and links
- **testBugUsesBugReportTemplate** — bug kind → `bug-report.yml`.
- **testEnhancementUsesFeatureRequestTemplate** — enhancement kind → `feature-request.yml`.
- **testIssuesURLPointsAtPublicRepo** — issues list URL is the public feedback repository.

### B. Prefill URL
- **testComposerURLPrefillsTitleAndDetails** — non-empty title/details produce `template`, `title`, and `details` query items.
- **testComposerURLRejectsBlankFields** — whitespace-only title or details → `nil`.
- **testComposerURLOmitsDetailsWhenTooLong** — when the full URL exceeds the length cap, keep template+title and omit details.
