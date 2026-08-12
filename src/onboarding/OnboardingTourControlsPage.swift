import AppKit
import QuartzCore

final class OnboardingTourControlsPage: NSObject, OnboardingTourScene {
    private enum Playback {
        static let initialPause = TimeInterval(0.42)
        static let revealDelay = TimeInterval(0.14)
        static let typingStartDelay = TimeInterval(0.34)
        static let characterDelay = TimeInterval(0.13)
        static let filterDelay = TimeInterval(0.28)
        static let filterDuration = CFTimeInterval(0.46)
        static let timerTolerance = TimeInterval(0.02)
    }

    private enum PlaybackStep {
        case pressSearch, revealSearch, typeQuery, filterResults, finish
    }

    private static let titleText = NSLocalizedString("Switch within one app. Search every window.", comment: "Onboarding Search page heading")
    private static let bodyText = NSLocalizedString("Option–Tab shows this app’s windows. S searches—even with typos. All shortcuts are customizable.", comment: "Onboarding Search page description")
    private static let sequenceText = NSLocalizedString("Same-app windows  •  Typo-tolerant search", comment: "Onboarding Search demonstration features")
    private static let replayTitle = NSLocalizedString("Replay Animation", comment: "Onboarding animation replay button")
    private static let shortcutLabel = NSLocalizedString("Default search shortcut: S", comment: "Onboarding Search shortcut accessibility label")
    private static let initialPreviewSummary = NSLocalizedString("Switcher preview with Cursor, Safari, and VS Code. Safari is selected.", comment: "Onboarding Search initial preview accessibility summary")
    private static let searchEditingPreviewSummary = NSLocalizedString("Search field shown with Cursor, Safari, and VS Code.", comment: "Onboarding Search editing preview accessibility summary")
    private static let searchPreviewSummary = NSLocalizedString("Search preview. The misspelled query “safri” filters the switcher to Safari.", comment: "Onboarding Search result accessibility summary")
    private static let searchQuery = NSLocalizedString("safri", comment: "Onboarding intentionally misspelled Safari search query")

    let view: NSView
    private let preview = OnboardingSwitcherPreviewView()
    private let focusSet = OnboardingTourDemoContent.focusSets[1]
    private let searchKeycap = OnboardingTourKeycapView("S")
    private var playbackTimer: Timer?
    private var typedCharacterCount = 0
    private var hasDemonstrated = false

    override init() {
        let stack = NSStackView()
        view = stack
        super.init()
        setup(stack)
        snapToInitialState()
    }

    deinit {
        playbackTimer?.invalidate()
    }

    func activate(animated: Bool) {
        let shouldDemonstrate = animated && !hasDemonstrated
        hasDemonstrated = true
        guard shouldDemonstrate else {
            snapToFinalState()
            return
        }
        startDemonstration()
    }

    func deactivate() {
        stopPlayback()
        removeAnimations(from: view)
        snapToFinalState()
    }

    @objc private func replay(_ sender: NSButton) {
        guard shouldAnimate() else {
            snapToFinalState()
            return
        }
        startDemonstration()
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
        let row = NSStackView(views: [searchKeycap])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DesignSystem.Metrics.headerFooterGap
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.group)
        row.setAccessibilityLabel(Self.shortcutLabel)
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

    private var searchResultApps: [OnboardingTourDemoApp] {
        guard focusSet.apps.indices.contains(focusSet.selectedIndex) else { return [] }
        return [focusSet.apps[focusSet.selectedIndex]]
    }

    private func snapToInitialState() {
        removeAnimations(from: view)
        preview.apply(apps: focusSet.apps, layout: .iconGrid, selectedIndex: focusSet.selectedIndex, summary: Self.initialPreviewSummary, animated: false)
        resetKeycap()
    }

    private func snapToFinalState() {
        removeAnimations(from: view)
        preview.applySearch(apps: searchResultApps, selectedIndex: 0, query: Self.searchQuery, summary: Self.searchPreviewSummary, animated: false)
        resetKeycap()
    }

    private func resetKeycap() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        searchKeycap.layer?.transform = CATransform3DIdentity
        searchKeycap.layer?.opacity = 1
        CATransaction.commit()
    }

    private func startDemonstration() {
        stopPlayback()
        typedCharacterCount = 0
        snapToInitialState()
        schedule(.pressSearch, after: Playback.initialPause)
    }

    private func perform(_ step: PlaybackStep) {
        playbackTimer = nil
        switch step {
        case .pressSearch:
            animateSearchKeycap()
            schedule(.revealSearch, after: Playback.revealDelay)
        case .revealSearch:
            preview.applySearch(apps: focusSet.apps, selectedIndex: focusSet.selectedIndex, query: "", summary: Self.searchEditingPreviewSummary, animated: true)
            schedule(.typeQuery, after: Playback.typingStartDelay)
        case .typeQuery:
            typeNextCharacter()
        case .filterResults:
            preview.animateSearchFiltering(matchingIndex: focusSet.selectedIndex, duration: Playback.filterDuration)
            schedule(.finish, after: Playback.filterDuration)
        case .finish:
            snapToFinalState()
        }
    }

    private func typeNextCharacter() {
        typedCharacterCount += 1
        preview.updateSearchQuery(String(Self.searchQuery.prefix(typedCharacterCount)))
        guard typedCharacterCount < Self.searchQuery.count else {
            schedule(.filterResults, after: Playback.filterDelay)
            return
        }
        schedule(.typeQuery, after: Playback.characterDelay)
    }

    private func schedule(_ step: PlaybackStep, after delay: TimeInterval) {
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in self?.perform(step) }
        timer.tolerance = Playback.timerTolerance
        RunLoop.main.add(timer, forMode: .common)
        playbackTimer = timer
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func animateSearchKeycap() {
        let keyTimes: [NSNumber] = [0, 0.28, 0.62, 1]
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1, 0.9, 0.82, 1]
        scale.keyTimes = keyTimes
        let travel = CAKeyframeAnimation(keyPath: "transform.translation.y")
        travel.values = [0, -1, -2, 0]
        travel.keyTimes = keyTimes
        let group = CAAnimationGroup()
        group.animations = [scale, travel]
        group.duration = 0.42
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        searchKeycap.layer?.add(group, forKey: "onboarding.search.keycap")
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
