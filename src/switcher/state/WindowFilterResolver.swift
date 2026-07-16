import Foundation

/// Decides whether a single window is shown to the user in the switcher, given the per-shortcut
/// filter preferences and the surrounding context. Pure kernel: takes the window's `WindowState`,
/// the app's `ApplicationState`, the dropdown booleans (defaulted to `false` so tests only spell out
/// what they exercise), the runtime context (frontmost pid, visible spaces, exceptions), the
/// default-true Focus Set membership fact, and a **lazy** `isOnPreferredScreen` — the one fact
/// that's irreducibly OS-coupled (`Window.isOnScreen`
/// touches `Spaces.screenSpacesMap` + multi-screen quartz math). Everything else is a pure
/// expression over the inputs, evaluated inline so `&&` short-circuits exactly like the original.
enum WindowFilterResolver {
    /// True iff the window passes every active filter. Mirrors the original predicate term-for-term;
    /// `isOnPreferredScreen` is an `@autoclosure` so the (relatively expensive) OS call only fires
    /// when the short-circuit reaches it — phantom, exception-hidden, Focus Set-excluded, app-filtered,
    /// and windowless windows never trigger it.
    static func shouldShow(_ s: WindowState, _ app: ApplicationState,
                           onlyFrontmostApp: Bool = false,       // appsToShow == .active
                           excludeFrontmostApp: Bool = false,    // appsToShow == .nonActive
                           hideHidden: Bool = false,             // showHiddenWindows == .hide
                           hideWindowless: Bool = false,         // showWindowlessApps == .hide
                           hideFullscreen: Bool = false,         // showFullscreenWindows == .hide
                           hideMinimized: Bool = false,          // showMinimizedWindows == .hide
                           onlyVisibleSpaces: Bool = false,      // spacesToShow == .visible
                           onlyNonVisibleSpaces: Bool = false,   // spacesToShow == .nonVisible
                           onlyPreferredScreen: Bool = false,    // screensToShow == .showingScryTab
                           frontmostPid: pid_t? = nil,
                           visibleSpaceIds: [UInt64] = [],       // CGSSpaceID === UInt64
                           exceptions: [ExceptionEntry] = [],
                           matchesFocusSet: @autoclosure () -> Bool = true,
                           isOnPreferredScreen: @autoclosure () -> Bool) -> Bool {
        !s.isPhantom &&
            !ExceptionMatcher.hidesWindow(s, app, exceptions: exceptions) &&
            matchesFocusSet() &&
            !(onlyFrontmostApp && !(frontmostPid == app.pid)) &&
            !(excludeFrontmostApp && frontmostPid == app.pid) &&
            !(hideHidden && app.isHidden) &&
            ((!hideWindowless && s.isWindowlessApp) ||
                !s.isWindowlessApp &&
                !(hideFullscreen && s.isFullscreen) &&
                !(hideMinimized && s.isMinimized) &&
                !(onlyVisibleSpaces && !inAnyVisibleSpace(s, visibleSpaceIds)) &&
                !(onlyNonVisibleSpaces && inAnyVisibleSpace(s, visibleSpaceIds)) &&
                !(onlyPreferredScreen && !isOnPreferredScreen()) &&
                !s.isTabbed)
    }

    private static func inAnyVisibleSpace(_ s: WindowState, _ visibleSpaceIds: [UInt64]) -> Bool {
        visibleSpaceIds.contains { visibleSpace in s.spaceIds.contains { $0 == visibleSpace } }
    }
}
