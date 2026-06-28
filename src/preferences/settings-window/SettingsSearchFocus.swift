import Cocoa

extension NSView {
    /// Scroll this view into view inside its enclosing scroll view and apply a short-lived
    /// selection-tinted background pulse. Used by search-result routing to draw the user's eye to
    /// the row that matched their query.
    func performFocusHighlight() {
        scrollToVisibleInEnclosingScrollView()
        pulseSelectionBackground()
    }

    private func scrollToVisibleInEnclosingScrollView() {
        guard let enclosingScrollView else { return }
        let rowRect = convert(bounds, to: enclosingScrollView.contentView)
        enclosingScrollView.contentView.scrollToVisible(rowRect)
    }

    private func pulseSelectionBackground() {
        wantsLayer = true
        guard let layer else { return }
        let pulse = CALayer()
        pulse.frame = bounds
        pulse.backgroundColor = NSColor.systemAccentColor.withAlphaComponent(0.18).cgColor
        pulse.cornerRadius = layer.cornerRadius
        layer.insertSublayer(pulse, at: 0)
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.duration = 0.6
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        animation.delegate = PulseRemover(pulse)
        pulse.add(animation, forKey: "focusPulse")
    }

    private final class PulseRemover: NSObject, CAAnimationDelegate {
        private weak var layer: CALayer?
        init(_ layer: CALayer) { self.layer = layer }
        func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
            layer?.removeFromSuperlayer()
        }
    }
}

extension SettingsWindow {
    /// Navigate to `route` and then resolve `focusID` against `SettingsFocusRegistry`. When the
    /// anchor exists on the destination page, scroll it into view and apply a temporary semantic
    /// highlight. When the row declared a focal control, make it the first responder so keyboard
    /// users land directly on the matching control. `focusID` is a one-shot: a subsequent plain
    /// navigation (no `focusing:`) clears it.
    func navigate(to route: SettingsRoute, focusing focusID: String?) {
        pendingFocusID = focusID
        navigate(to: route)
    }

    func resolvePendingFocusAnchor() {
        guard let id = pendingFocusID else { return }
        pendingFocusID = nil
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            guard let view = SettingsFocusRegistry.shared.view(for: id), view.window != nil else { return }
            view.performFocusHighlight()
            if let row = view as? SettingsRowView, let focal = row.focalControl, focal.window != nil, focal.acceptsFirstResponder {
                view.window?.makeFirstResponder(focal)
            }
        }
    }
}
