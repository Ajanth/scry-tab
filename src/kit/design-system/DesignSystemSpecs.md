# DesignSystem — Specs

## Summary

Defines the AppKit design-system primitives used by the Luminare migration.

- Tokens centralize Settings geometry, typography, motion, color roles, and accessibility variants.
- `DesignComponentState` resolves component state with a single precedence order.
- `DesignSurfaceStyle` maps semantic roles and component states to fill, border, radius, and shadow roles.
- `MaterialSurfaceView` owns one retained `NSVisualEffectView`, one retained tint layer, and only the optional retained gradient/border layers required by its role.

## Behavior & edge cases

- Component state precedence is disabled, pressed, selected, hovered, then normal.
- Reduce Motion removes spatial overlay offset and shortens standard animation durations.
- Increase Contrast strengthens semantic surface borders.
- Reduce Transparency removes ambiguous translucent fills and hides material/gradient treatment.
- Window tint uses multiply compositing.
- Focus adds an independent accessibility-visible outline without changing component-state precedence.
- Sidebar group spacing and icon radius tokens expose the shell geometry from the spec.
- A material surface role that does not use optional layers must not allocate them; the window role uses a restrained gradient but no border layer.
- Updating a material surface for appearance or accessibility changes must preserve retained effect and layer identities.
- Explicit appearance refreshes must mutate retained layers in place.
- Changing a material surface role adds or removes only the optional layers required by the new role.

## Test scenarios

Mirrors `DesignSystemTests.swift` 1:1.

- **testComponentStatePrecedence** — disabled wins over every other state, followed by pressed, selected, hovered, and normal.
- **testReduceMotionRemovesSpatialOffsetAndShortensDurations** — Reduce Motion keeps a short crossfade duration and removes overlay offset.
- **testIncreaseContrastStrengthensNormalBorder** — Increase Contrast raises normal semantic border width.
- **testWindowTintUsesMultiplyBlendMode** — the retained tint layer uses multiply compositing.
- **testFocusedStateAddsIndependentOutline** — focus adds an outline while leaving the resolved component state unchanged.
- **testSidebarShellMetricsMatchSpecification** — sidebar group spacing, label gap, and icon radius match the shell specification.
- **testWindowRoleHasGradientButNoBorderLayer** — the window material role retains the required effect view, tint layer, and restrained gradient but no border layer.
- **testIconRoleHasGradientAndBorderLayers** — icon surfaces retain both optional layers.
- **testAccessibilityUpdateRetainsLayerIdentities** — accessibility updates mutate retained layers in place.
- **testDirectAppearanceRefreshRetainsLayerIdentities** — direct appearance refreshes keep retained effect and layer identities.
- **testRoleChangeUpdatesOptionalLayerPresence** — changing roles adds/removes optional layers according to role requirements.
