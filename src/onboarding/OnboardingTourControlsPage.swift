import AppKit
import QuartzCore

final class OnboardingTourControlsPage: NSObject, OnboardingTourScene {
    private enum Motion {
        static let duration = CFTimeInterval(1.8)
        static let keyTimes: [NSNumber] = [0, 0.16, 0.38, 0.54, 0.78, 1]
    }

    private static let titleText = NSLocalizedString("Hold, advance, then release", comment: "Onboarding Controls page heading")
    private static let bodyFormat = NSLocalizedString("Hold %@ to show the switcher, press again to advance, then release to focus the selected window.", comment: "Onboarding Controls page description with primary shortcut")
    private static let sequenceText = NSLocalizedString("Hold to show  •  Press again to advance  •  Release to focus", comment: "Onboarding Controls demonstration sequence")
    private static let replayTitle = NSLocalizedString("Replay Animation", comment: "Onboarding animation replay button")
    private static let shortcutLabelFormat = NSLocalizedString("Primary shortcut: %@", comment: "Onboarding primary shortcut accessibility label")
    private static let previewSummary = NSLocalizedString("Control demonstration preview. Cursor starts selected; pressing the shortcut again advances to Safari, and releasing focuses Safari.", comment: "Onboarding Controls preview accessibility summary")

    let view: NSView
    private let primaryShortcutText: String
    private let preview = OnboardingSwitcherPreviewView()
    private let focusSet = OnboardingTourDemoContent.focusSets[1]
    private var shortcutKeycaps = [OnboardingTourKeycapView]()
    private var hasDemonstrated = false

    init(primaryShortcutText: String) {
        self.primaryShortcutText = primaryShortcutText.trimmingCharacters(in: .whitespacesAndNewlines)
        let stack = NSStackView()
        view = stack
        super.init()
        setup(stack)
        snapToFinalState()
    }

    func activate(animated: Bool) {
        snapToFinalState()
        let shouldDemonstrate = animated && !hasDemonstrated
        hasDemonstrated = true
        guard shouldDemonstrate else { return }
        animateDemonstration()
    }

    func deactivate() {
        removeAnimations(from: view)
        snapToFinalState()
    }

    @objc private func replay(_ sender: NSButton) {
        snapToFinalState()
        guard shouldAnimate() else { return }
        animateDemonstration()
    }

    private func setup(_ stack: NSStackView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = DesignSystem.Metrics.sectionGap
        let heading = makeLabel(Self.titleText, font: NSFont.systemFont(ofSize: 17, weight: .medium), color: .textPrimary)
        let body = makeLabel(String(format: Self.bodyFormat, displayShortcutText), font: NSFont.systemFont(ofSize: 13), color: .textSecondary)
        let header = NSStackView(views: [heading, body])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = DesignSystem.Metrics.headerFooterGap
        let shortcut = makeShortcutRow()
        let sequence = makeLabel(Self.sequenceText, font: NSFont.systemFont(ofSize: 12, weight: .medium), color: .textSecondary)
        let replayButton = DesignSystemControlStyler.makeButton(Self.replayTitle, target: self, action: #selector(replay(_:)))
        let supportRow = makeSupportRow(sequence: sequence, replayButton: replayButton)
        [header, shortcut, preview, supportRow].forEach { stack.addArrangedSubview($0) }
        heading.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true
        body.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true
        supportRow.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true
    }

    private func makeLabel(_ text: String, font: NSFont, color: DesignSystem.ColorRole) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.textColor = DesignSystem.color(color)
        label.alignment = .center
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeShortcutRow() -> NSStackView {
        shortcutKeycaps = shortcutParts.map { OnboardingTourKeycapView($0) }
        let row = NSStackView(views: shortcutKeycaps)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DesignSystem.Metrics.headerFooterGap
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.group)
        row.setAccessibilityLabel(String(format: Self.shortcutLabelFormat, displayShortcutText))
        return row
    }

    private func makeSupportRow(sequence: NSTextField, replayButton: NSButton) -> NSStackView {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.addView(sequence, in: .leading)
        row.addView(replayButton, in: .trailing)
        return row
    }

    private var displayShortcutText: String {
        primaryShortcutText.isEmpty ? NSLocalizedString("Primary shortcut", comment: "Onboarding empty primary shortcut fallback") : primaryShortcutText
    }

    private var shortcutParts: [String] {
        guard !primaryShortcutText.isEmpty else { return [displayShortcutText] }
        let modifiers = Set(["⌃", "⌥", "⇧", "⌘"])
        var parts = [String]()
        var remainder = primaryShortcutText[...]
        while let modifier = remainder.first, modifiers.contains(String(modifier)) {
            parts.append(String(modifier))
            remainder.removeFirst()
        }
        let key = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { parts.append(key) }
        return parts.isEmpty ? [displayShortcutText] : parts
    }

    private func snapToFinalState() {
        removeAnimations(from: view)
        preview.apply(apps: focusSet.apps, layout: .iconGrid, selectedIndex: focusSet.selectedIndex, summary: Self.previewSummary, animated: false)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shortcutKeycaps.forEach {
            $0.layer?.transform = CATransform3DIdentity
            $0.layer?.opacity = 1
        }
        preview.layer?.transform = CATransform3DIdentity
        preview.layer?.opacity = 1
        CATransaction.commit()
    }

    private func animateDemonstration() {
        if shortcutKeycaps.count == 1 {
            shortcutKeycaps.forEach { addKeycapAnimation(to: $0, values: [1, 0.9, 0.9, 0.82, 0.9, 1]) }
        } else {
            shortcutKeycaps.dropLast().forEach { addKeycapAnimation(to: $0, values: [1, 0.9, 0.9, 0.82, 0.9, 1]) }
            if let advancingKey = shortcutKeycaps.last { addKeycapAnimation(to: advancingKey, values: [1, 0.88, 1, 0.82, 1, 1]) }
        }
        preview.animateSelectionTransition(from: 0, duration: Motion.duration, changeKeyTime: 0.54)
        let advance = CAKeyframeAnimation(keyPath: "transform.translation.x")
        advance.values = [0, 0, 0, 8, 0, 0]
        advance.keyTimes = Motion.keyTimes
        let focus = CAKeyframeAnimation(keyPath: "opacity")
        focus.values = [1, 1, 1, 1, 0.82, 1]
        focus.keyTimes = Motion.keyTimes
        advance.duration = Motion.duration
        focus.duration = Motion.duration
        let group = CAAnimationGroup()
        group.animations = [advance, focus]
        group.duration = Motion.duration
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        preview.layer?.add(group, forKey: "onboarding.controls.preview")
    }

    private func addKeycapAnimation(to keycap: OnboardingTourKeycapView, values: [CGFloat]) {
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = values
        scale.keyTimes = Motion.keyTimes
        let travel = CAKeyframeAnimation(keyPath: "transform.translation.y")
        travel.values = [0, -1, 0, -2, 0, 0]
        travel.keyTimes = Motion.keyTimes
        scale.duration = Motion.duration
        travel.duration = Motion.duration
        let group = CAAnimationGroup()
        group.animations = [scale, travel]
        group.duration = Motion.duration
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        keycap.layer?.add(group, forKey: "onboarding.controls.keycap")
    }

    private func removeAnimations(from view: NSView) {
        removeAnimations(from: view.layer)
        view.subviews.forEach { removeAnimations(from: $0) }
    }

    private func removeAnimations(from layer: CALayer?) {
        layer?.removeAllAnimations()
        layer?.sublayers?.forEach { removeAnimations(from: $0) }
    }

    private func shouldAnimate() -> Bool {
        OnboardingTourResolver.shouldAnimate(windowVisible: view.window?.isVisible ?? false, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}
