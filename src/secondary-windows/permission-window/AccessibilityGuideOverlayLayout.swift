import Foundation

enum AccessibilityGuideOverlayLayout {
    enum DockEdge: Equatable {
        /// Panel sits on the Settings window's leading (left) edge; the arrow points right at the list.
        case leading
        /// Panel sits on the Settings window's trailing (right) edge; the arrow points left at the list.
        case trailing
    }

    struct Placement: Equatable {
        let frame: CGRect
        let edge: DockEdge
    }

    /// Fraction of the Settings window height (from the bottom) for the panel's vertical center.
    /// Above 0.5 biases toward the Accessibility app list in the upper content area.
    private static let verticalCenterFraction: CGFloat = 0.58

    /// Park the guide beside the System Settings window, never on top of it. Prefer the trailing edge
    /// (the Accessibility list and toggles live there); fall back to the leading edge, then to whichever
    /// side has more room when neither fully fits. Vertically bias slightly above the window center and
    /// clamp into the screen's visibleFrame so the panel stays reachable.
    static func placement(
        panelSize: CGSize,
        settingsFrame: CGRect,
        visibleFrame: CGRect,
        gap: CGFloat
    ) -> Placement {
        let leadingX = settingsFrame.minX - gap - panelSize.width
        let trailingX = settingsFrame.maxX + gap
        let fitsLeading = leadingX >= visibleFrame.minX + gap
        let fitsTrailing = trailingX + panelSize.width <= visibleFrame.maxX - gap
        let edge = chooseEdge(
            fitsLeading: fitsLeading,
            fitsTrailing: fitsTrailing,
            leadingRoom: settingsFrame.minX - visibleFrame.minX,
            trailingRoom: visibleFrame.maxX - settingsFrame.maxX)
        let x = edge == .leading ? leadingX : trailingX
        let preferredMidY = settingsFrame.minY + settingsFrame.height * verticalCenterFraction
        var frame = CGRect(
            x: x,
            y: preferredMidY - panelSize.height * 0.5,
            width: panelSize.width,
            height: panelSize.height)
        frame.origin.x = clamp(frame.origin.x, lower: visibleFrame.minX + gap, upper: visibleFrame.maxX - gap - panelSize.width)
        frame.origin.y = clamp(frame.origin.y, lower: visibleFrame.minY + gap, upper: visibleFrame.maxY - gap - panelSize.height)
        return Placement(frame: frame, edge: edge)
    }

    private static func chooseEdge(fitsLeading: Bool, fitsTrailing: Bool, leadingRoom: CGFloat, trailingRoom: CGFloat) -> DockEdge {
        if fitsTrailing { return .trailing }
        if fitsLeading { return .leading }
        return trailingRoom >= leadingRoom ? .trailing : .leading
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard upper >= lower else { return lower }
        return min(max(value, lower), upper)
    }
}
