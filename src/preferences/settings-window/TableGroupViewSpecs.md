# TableGroupView — Specs

## Summary

`TableGroupView` is the shared joined-section primitive used across Settings pages. It owns the
group label treatment and the split between section-container geometry and individual row geometry.

## Behavior & edge cases

- The outer grouped-section container uses the section radius token, while exposed row corners keep
  the joined-row radius token.
- Group labels use the compact secondary-label styling and inset from the group edge.
- Row content uses distinct horizontal and vertical insets so wider label/control padding does not
  inflate row height.
- Row content keeps a flexible minimum-height constraint instead of freezing the main row to its
  initial fitting size.
- Secondary-only rows do not insert an empty primary-row spacer before their content.

## Test scenarios

Mirrors `TableGroupViewTests.swift` 1:1.

- **testSectionContainerUsesSectionRadiusWhileRowsKeepJoinedRowRadius** — the rounded group surface uses the section token while its row surface keeps the joined-row token.
- **testTitledGroupsUseSecondaryHeaderStyleAndInset** — titled groups pin their header color to the secondary label role and use the compact header inset.
- **testRowsUseSeparateHorizontalAndVerticalInsets** — rows pin their main content with wider horizontal padding while keeping the original vertical inset.
- **testRowsUseFlexibleMainRowHeightInsteadOfFrozenFittingHeight** — the main row keeps a minimum-height guard without locking itself to the first fitting pass.
- **testSecondaryOnlyRowsSkipPlaceholderMainRow** — rows that only render secondary content skip the empty primary-row placeholder.
