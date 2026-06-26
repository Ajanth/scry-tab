# SidebarList — Specs

## Summary

`SidebarListRow` is the recycled row widget for the shortcut sidebar (ControlsTab) — title and
optional summary. Because rows are reused across refreshes rather than rebuilt, content refreshes must
not accumulate stale subviews.

## Behavior & edge cases

- `setContent` updates the visible title/summary without adding replacement view trees.

## Test scenarios

Mirrors `SidebarListTests.swift` 1:1.

- **testRepeatedContentUpdatesDoNotAccumulateViews** — repeated row content updates keep the row's descendant view count stable.
