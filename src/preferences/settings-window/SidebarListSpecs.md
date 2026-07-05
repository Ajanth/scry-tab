# SidebarList — Specs

## Summary

`SidebarListRow` is the recycled row widget for the shortcut sidebar (ControlsTab) — title and
optional summary. Because rows are reused across refreshes rather than rebuilt, content refreshes must
not accumulate stale subviews.

## Behavior & edge cases

- `setContent` updates the visible title/summary without adding replacement view trees.
- Selection and hover backgrounds stay vertically inset from the row bounds.
- A fixed-height sidebar remains independent from dynamic editor height.

## Test scenarios

Mirrors `SidebarListTests.swift` 1:1.

- **testRepeatedContentUpdatesDoNotAccumulateViews** — repeated row content updates keep the row's descendant view count stable.
- **testHighlightBackgroundUsesVerticalInset** — the row background uses the shared vertical inset on both edges.
- **testFixedSidebarHeightDoesNotFollowEditorHeight** — a fixed-height sidebar receives a constant height constraint instead of following the editor.
