# MenubarStatusIcon — Specs

## Summary

`MenubarStatusIcon` builds a menu-bar status item image at the standard 18×18 point size from a
`CGImage`, as a fresh `NSImage` that does not mutate the shared application-icon cache. The result
is a branded color icon (`isTemplate == false`).

## Test scenarios

Mirrors `MenubarStatusIconTests.swift` 1:1.

- **testMakeImageSetsPointSizeAndIsNotTemplate** — `makeImage(from:)` returns an `NSImage` with
  `size == 18×18` and `isTemplate == false`.
