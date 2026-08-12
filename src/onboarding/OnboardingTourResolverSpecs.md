# OnboardingTourResolver - Specs

## Summary

`OnboardingTourResolver` owns the pure decisions for tour navigation, automatic presentation,
and animation eligibility. Back clamps at the first page, Next advances until the final page,
and only the final page resolves to Finish. Automatic presentation is limited to installations
whose initial experience has not been shown. Animation requires a visible window and Reduce
Motion to be off. Focus Set autoplay advances through its finite tab sequence and stops on the
last tab without wrapping.

The resolver does not construct UI, persist completion, or schedule animations. The
`OnboardingTourScene` protocol is the page/window boundary, while `OnboardingTourCompletion`
identifies the two dismissal outcomes handled by later integration work.

## Test scenarios

### Back navigation
- **testBackFromFirstPageStaysOnFirstPage** - Back from Focus Sets remains on Focus Sets.
- **testBackFromLaterPagesMovesToPreviousPage** - Back from Appearance and Controls moves to each previous page.

### Next navigation
- **testNextFromFirstAndMiddlePagesAdvances** - Next from Focus Sets and Appearance shows each following page.
- **testNextFromFinalPageFinishes** - Next from Controls finishes the tour.

### Automatic presentation
- **testNewInstallPresentsAutomatically** - An installation without a shown initial experience presents the tour.
- **testExistingInstallDoesNotPresentAutomatically** - An installation with a shown initial experience does not present the tour.

### Animation eligibility
- **testVisibleWindowAnimates** - A visible window with Reduce Motion off allows animation.
- **testHiddenWindowDoesNotAnimate** - A hidden window does not animate.
- **testReduceMotionDoesNotAnimate** - Reduce Motion prevents animation for a visible window.

### Focus Set autoplay
- **testFocusSetAutoplayAdvancesWithoutWrapping** - Focus Set autoplay advances to each remaining tab, then stops on the last one.
- **testFocusSetAutoplayRejectsInvalidIndexes** - Empty and invalid sequences stop without selecting an out-of-range tab.
