import AppKit

final class OnboardingTourFocusSetsPage: NSObject, OnboardingTourScene {
    private enum Playback {
        static let stepDuration = TimeInterval(2.8)
        static let timerTolerance = TimeInterval(0.08)
    }

    private static let titleText = NSLocalizedString("Switch contexts with Focus Sets", comment: "Onboarding Focus Sets page heading")
    private static let bodyText = NSLocalizedString("Group apps. Pick any shortcut.", comment: "Onboarding Focus Sets page description")
    private static let exampleText = NSLocalizedString("Choose any shortcut", comment: "Onboarding Focus Set shortcut configurability hint")
    private static let shortcutExampleAccessibilityLabel = NSLocalizedString("Example shortcut: Option–1. Choose any shortcut.", comment: "Onboarding Focus Set shortcut example accessibility label")
    private static let selectorAccessibilityLabel = NSLocalizedString("Focus Set", comment: "Onboarding Focus Set selector accessibility label")
    private static let replayTitle = NSLocalizedString("Replay Animation", comment: "Onboarding animation replay button")
    private static let summaryFormat = NSLocalizedString("%@: %@. Selected: %@", comment: "Onboarding preview summary: Focus Set name, app names, then selected app")

    let view: NSView
    private let focusSets: [OnboardingTourDemoFocusSet]
    private let selector: DesignSystemSegmentedControl
    private let preview = OnboardingSwitcherPreviewView()
    private var selectedIndex = 0
    private var hasActivated = false
    private var autoplayTimer: Timer?

    override init() {
        let focusSets = OnboardingTourDemoContent.focusSets
        self.focusSets = focusSets
        selector = DesignSystemSegmentedControl(labels: focusSets.map { $0.name }, trackingMode: .selectOne, target: nil, action: nil)
        let stack = NSStackView()
        view = stack
        super.init()
        setup(stack)
        applySelection(animated: false)
    }

    deinit {
        autoplayTimer?.invalidate()
    }

    func activate(animated: Bool) {
        guard !hasActivated else {
            applySelection(animated: false)
            return
        }
        hasActivated = true
        startAutoplay(animated: animated)
    }

    func deactivate() {
        stopAutoplay()
        removeAnimations(from: view)
        applySelection(animated: false)
    }

    @objc private func selectFocusSet(_ sender: NSSegmentedControl) {
        let nextIndex = sender.selectedSegment
        guard focusSets.indices.contains(nextIndex) else { return }
        stopAutoplay()
        guard selectedIndex != nextIndex else { return }
        selectedIndex = nextIndex
        applySelection(animated: shouldAnimate())
    }

    @objc private func replay(_ sender: NSButton) {
        startAutoplay(animated: shouldAnimate())
    }

    private func setup(_ stack: NSStackView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = DesignSystem.Metrics.sectionGap
        let heading = makeLabel(Self.titleText, font: NSFont.systemFont(ofSize: 17, weight: .medium), color: .textPrimary)
        let body = makeLabel(Self.bodyText, font: NSFont.systemFont(ofSize: 13), color: .textSecondary)
        let header = NSStackView(views: [heading, body])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = DesignSystem.Metrics.headerFooterGap
        configureSelector()
        let replayButton = DesignSystemControlStyler.makeButton(Self.replayTitle, target: self, action: #selector(replay(_:)))
        let supportRow = makeSupportRow(replayButton: replayButton)
        [header, selector, preview, supportRow].forEach { stack.addArrangedSubview($0) }
        heading.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true
        body.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true
        supportRow.widthAnchor.constraint(equalTo: selector.widthAnchor).isActive = true
    }

    private func configureSelector() {
        selector.target = self
        selector.action = #selector(selectFocusSet(_:))
        selector.setAccessibilityLabel(Self.selectorAccessibilityLabel)
        for (index, focusSet) in focusSets.enumerated() {
            selector.setImage(OnboardingTourCategoryBadgeImage.make(for: focusSet), forSegment: index)
            selector.setToolTip(focusSet.name, forSegment: index)
        }
        DesignSystemControlStyler.styleSegmentedControl(selector)
        selector.segmentImageDimension = 20
        selector.segmentImageTitleSpacing = DesignSystem.Metrics.rowHorizontalPadding
        selector.segmentHorizontalContentInset = DesignSystem.Metrics.controlTextInset
        let width = selector.equalizeSegmentWidths(minimumTotalWidth: DesignSystem.Metrics.centeredSettingsContentMaxWidth,
                                                   maximumTotalWidth: preview.intrinsicContentSize.width)
        selector.widthAnchor.constraint(equalToConstant: width).isActive = true
        selector.heightAnchor.constraint(equalToConstant: DesignSystem.Metrics.standardControlMinHeight + 2 * DesignSystem.Metrics.headerFooterGap).isActive = true
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

    private func makeSupportRow(replayButton: NSButton) -> NSStackView {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.addView(makeShortcutRow(), in: .leading)
        row.addView(replayButton, in: .trailing)
        return row
    }

    private func makeShortcutRow() -> NSStackView {
        let hint = NSTextField(labelWithString: Self.exampleText)
        hint.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        hint.textColor = DesignSystem.color(.textSecondary)
        hint.setAccessibilityElement(false)
        let row = NSStackView(views: [hint, makeExampleShortcut()])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DesignSystem.Metrics.rowHorizontalPadding
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.group)
        row.setAccessibilityLabel(Self.shortcutExampleAccessibilityLabel)
        return row
    }

    private func makeExampleShortcut() -> NSStackView {
        let plus = NSTextField(labelWithString: "+")
        plus.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        plus.textColor = DesignSystem.color(.textSecondary)
        plus.setAccessibilityElement(false)
        let row = NSStackView(views: [OnboardingTourKeycapView("⌥"), plus, OnboardingTourKeycapView("1")])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DesignSystem.Metrics.headerFooterGap
        row.setAccessibilityElement(false)
        return row
    }

    private func applySelection(animated: Bool) {
        guard focusSets.indices.contains(selectedIndex) else { return }
        let focusSet = focusSets[selectedIndex]
        selector.selectedSegment = selectedIndex
        preview.apply(apps: focusSet.apps, layout: .iconGrid, selectedIndex: focusSet.selectedIndex, summary: summary(for: focusSet), animated: animated)
    }

    private func startAutoplay(animated: Bool) {
        stopAutoplay()
        selectedIndex = 0
        applySelection(animated: animated)
        guard animated, focusSets.indices.contains(selectedIndex) else { return }
        scheduleAutoplayStep()
    }

    private func scheduleAutoplayStep() {
        selector.setProgress(1, forSegment: selectedIndex, animationDuration: Playback.stepDuration)
        let timer = Timer(timeInterval: Playback.stepDuration, repeats: false) { [weak self] _ in self?.advanceAutoplay() }
        timer.tolerance = Playback.timerTolerance
        RunLoop.main.add(timer, forMode: .common)
        autoplayTimer = timer
    }

    private func advanceAutoplay() {
        autoplayTimer = nil
        guard shouldAnimate() else {
            selector.clearProgress()
            return
        }
        selector.setProgress(1, forSegment: selectedIndex)
        guard let nextIndex = OnboardingTourResolver.nextAutoplayIndex(after: selectedIndex, count: focusSets.count) else { return }
        selectedIndex = nextIndex
        applySelection(animated: true)
        scheduleAutoplayStep()
    }

    private func stopAutoplay() {
        autoplayTimer?.invalidate()
        autoplayTimer = nil
        selector.clearProgress()
    }

    private func summary(for focusSet: OnboardingTourDemoFocusSet) -> String {
        let selectedApp = focusSet.apps.indices.contains(focusSet.selectedIndex) ? focusSet.apps[focusSet.selectedIndex].name : ""
        return String(format: Self.summaryFormat, focusSet.name, focusSet.apps.map { $0.name }.joined(separator: ", "), selectedApp)
    }

    private func removeAnimations(from view: NSView) {
        view.layer?.removeAllAnimations()
        view.layer?.sublayers?.forEach { $0.removeAllAnimations() }
        view.subviews.forEach { removeAnimations(from: $0) }
    }

    private func shouldAnimate() -> Bool {
        OnboardingTourResolver.shouldAnimate(windowVisible: view.window?.isVisible ?? false, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}
