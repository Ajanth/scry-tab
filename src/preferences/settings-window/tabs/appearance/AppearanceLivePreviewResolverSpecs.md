# AppearanceLivePreviewResolver - Specs

## Summary

The Appearance tab's style preview cycles the focus state across demo app tiles once per second
so the user can see how selection looks in the chosen style.
`AppearanceLivePreviewResolver` owns only that feature-specific timing constant. Generic focus
cycling, visibility, manual pause, and Reduce Motion gating remain in `AnimatedSelectionResolver`,
while style-specific initial focus and Controls playback selection remain in
`AppearancePreviewStateResolver`. The preview does not read live switcher session state.

## Test scenarios

- **testAdvancesOncePerSecond** - The preview holds each focused item for exactly one second.
