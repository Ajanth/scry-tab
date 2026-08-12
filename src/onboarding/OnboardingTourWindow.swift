import AppKit
import QuartzCore

final class OnboardingTourWindow: NSWindow {
    private enum Metrics {
        static let contentWidth = CGFloat(680)
        static let pageHeight = CGFloat(468)
        static let edgeInset = DesignSystem.Metrics.sectionGap + DesignSystem.Metrics.formOuterPadding
    }

    private enum Motion {
        static let pageDuration = CFTimeInterval(0.3)
        static let pageOffset = CGFloat(24)
    }

    private static let windowTitle = NSLocalizedString("ScryTab Tour", comment: "Onboarding tour window title")
    private static let progressFormat = NSLocalizedString("Step %d of %d", comment: "Onboarding tour progress")
    private static let skipTitle = NSLocalizedString("Skip Tour", comment: "Onboarding tour skip button")
    private static let backTitle = NSLocalizedString("Back", comment: "Onboarding tour back button")
    private static let nextTitle = NSLocalizedString("Next", comment: "Onboarding tour next button")
    private static let doneTitle = NSLocalizedString("Done", comment: "Onboarding tour finish into Appearance button")
    private static let exploreTitle = NSLocalizedString("Explore Focus Sets", comment: "Onboarding tour final button")

    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }
    private(set) static var shared: OnboardingTourWindow?
    private let pageHost = NSView()
    private let progressLabel = NSTextField(labelWithString: "")
    private let skipButton: NSButton
    private let backButton: NSButton
    private let doneButton: NSButton
    private let nextButton: NSButton
    private var currentPage = OnboardingTourPage.focusSets
    private var currentScene: OnboardingTourScene?
    private var accessibilityObserver: NSObjectProtocol?
    private var completion: ((OnboardingTourCompletion) -> Void)?
    private var pendingCompletion = OnboardingTourCompletion.skip

    static func present(onCompletion: @escaping (OnboardingTourCompletion) -> Void) {
        if let existing = shared {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = OnboardingTourWindow(onCompletion: onCompletion)
        shared = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private init(onCompletion: @escaping (OnboardingTourCompletion) -> Void) {
        completion = onCompletion
        skipButton = DesignSystemControlStyler.makeButton(Self.skipTitle)
        backButton = DesignSystemControlStyler.makeButton(Self.backTitle)
        doneButton = DesignSystemControlStyler.makeButton(Self.doneTitle)
        nextButton = DesignSystemControlStyler.makePrimaryButton(Self.nextTitle)
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        setupWindow()
        setupContent()
        observeAccessibilityOptions()
        show(.focusSets, activate: false)
    }

    func dismissAnimations() {
        currentScene?.deactivate()
    }

    override func cancelOperation(_ sender: Any?) {
        complete(.skip)
    }

    private func setupWindow() {
        title = Self.windowTitle
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        delegate = self
    }

    private func setupContent() {
        pageHost.translatesAutoresizingMaskIntoConstraints = false
        pageHost.setAccessibilityElement(false)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        progressLabel.textColor = DesignSystem.color(.textSecondary)
        progressLabel.alignment = .center
        configureButtons()
        let divider = DesignSystemDividerView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        divider.setAccessibilityElement(false)
        let footer = makeFooter()
        let root = NSStackView(views: [pageHost, progressLabel, divider, footer])
        root.translatesAutoresizingMaskIntoConstraints = false
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = DesignSystem.Metrics.sectionGap
        root.edgeInsets = NSEdgeInsets(top: Metrics.edgeInset, left: Metrics.edgeInset, bottom: Metrics.edgeInset, right: Metrics.edgeInset)
        root.setCustomSpacing(DesignSystem.Metrics.headerFooterGap, after: progressLabel)
        root.setCustomSpacing(DesignSystem.Metrics.formOuterPadding, after: divider)
        [pageHost, progressLabel, divider, footer].forEach { $0.widthAnchor.constraint(equalToConstant: Metrics.contentWidth).isActive = true }
        pageHost.heightAnchor.constraint(equalToConstant: Metrics.pageHeight).isActive = true
        let container = DesignSystemWindowContentView(content: root, topPadding: DesignSystem.Metrics.formOuterPadding)
        contentView = container
        setContentSize(container.fittingSize)
    }

    private func configureButtons() {
        skipButton.target = self
        skipButton.action = #selector(skip(_:))
        skipButton.keyEquivalent = "\u{1b}"
        backButton.target = self
        backButton.action = #selector(back(_:))
        doneButton.target = self
        doneButton.action = #selector(done(_:))
        nextButton.target = self
        nextButton.action = #selector(next(_:))
        skipButton.setAccessibilityLabel(Self.skipTitle)
        backButton.setAccessibilityLabel(Self.backTitle)
        doneButton.setAccessibilityLabel(Self.doneTitle)
        nextButton.setAccessibilityLabel(Self.nextTitle)
    }

    private func makeFooter() -> NSView {
        let trailingActions = NSStackView(views: [backButton, doneButton, nextButton])
        trailingActions.translatesAutoresizingMaskIntoConstraints = false
        trailingActions.orientation = .horizontal
        trailingActions.alignment = .centerY
        trailingActions.spacing = TableGroupView.toolRowSpacing
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: TableGroupView.toolRowSpacing).isActive = true
        let footer = NSStackView(views: [skipButton, spacer, trailingActions])
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 0
        return footer
    }

    private func observeAccessibilityOptions() {
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.dismissAnimations()
        }
    }

    @objc private func skip(_ sender: Any?) {
        complete(.skip)
    }

    @objc private func back(_ sender: Any?) {
        show(OnboardingTourResolver.back(from: currentPage), activate: true)
    }

    @objc private func done(_ sender: Any?) {
        complete(.openAppearance)
    }

    @objc private func next(_ sender: Any?) {
        switch OnboardingTourResolver.next(from: currentPage) {
        case let .show(page): show(page, activate: true)
        case .finish: complete(.exploreFocusSets)
        }
    }

    private func show(_ page: OnboardingTourPage, activate: Bool) {
        guard page != currentPage || currentScene == nil else { return }
        let previousPage = currentPage
        currentScene?.deactivate()
        currentScene?.view.removeFromSuperview()
        let scene = makeScene(for: page)
        currentPage = page
        currentScene = scene
        attach(scene.view)
        updateNavigation()
        updateKeyViewLoop()
        guard activate else { return }
        let animated = shouldAnimate
        scene.activate(animated: animated)
        if animated { animateSceneEntry(scene.view, movingForward: page.rawValue > previousPage.rawValue) }
    }

    private func makeScene(for page: OnboardingTourPage) -> OnboardingTourScene {
        switch page {
        case .focusSets: return OnboardingTourFocusSetsPage()
        case .appearance: return OnboardingTourAppearancePage()
        case .controls: return OnboardingTourControlsPage()
        }
    }

    private func attach(_ sceneView: NSView) {
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        pageHost.addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.centerXAnchor.constraint(equalTo: pageHost.centerXAnchor),
            sceneView.centerYAnchor.constraint(equalTo: pageHost.centerYAnchor),
            sceneView.leadingAnchor.constraint(greaterThanOrEqualTo: pageHost.leadingAnchor),
            sceneView.trailingAnchor.constraint(lessThanOrEqualTo: pageHost.trailingAnchor),
            sceneView.topAnchor.constraint(greaterThanOrEqualTo: pageHost.topAnchor),
            sceneView.bottomAnchor.constraint(lessThanOrEqualTo: pageHost.bottomAnchor),
        ])
    }

    private func animateSceneEntry(_ sceneView: NSView, movingForward: Bool) {
        pageHost.layoutSubtreeIfNeeded()
        sceneView.wantsLayer = true
        guard let layer = sceneView.layer else { return }
        let direction = movingForward ? CGFloat(1) : CGFloat(-1)
        let position = CABasicAnimation(keyPath: "position")
        position.fromValue = NSPoint(x: layer.position.x + direction * Motion.pageOffset, y: layer.position.y)
        position.toValue = layer.position
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.42
        opacity.toValue = 1
        position.duration = Motion.pageDuration
        opacity.duration = Motion.pageDuration
        let group = CAAnimationGroup()
        group.animations = [position, opacity]
        group.duration = Motion.pageDuration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(group, forKey: "onboarding.pageEntry")
    }

    private func updateNavigation() {
        progressLabel.stringValue = String(format: Self.progressFormat, currentPage.rawValue + 1, OnboardingTourPage.allCases.count)
        backButton.isEnabled = currentPage != .focusSets
        doneButton.isHidden = currentPage != .controls
        nextButton.title = currentPage == .controls ? Self.exploreTitle : Self.nextTitle
        nextButton.setAccessibilityLabel(nextButton.title)
    }

    private func updateKeyViewLoop() {
        let pageControls = focusableControls(in: currentScene?.view)
        let controls = pageControls + [skipButton, backButton, doneButton, nextButton].filter { $0.isEnabled && !$0.isHidden }
        guard !controls.isEmpty else { return }
        recalculateKeyViewLoop()
        for (index, control) in controls.enumerated() { control.nextKeyView = controls[(index + 1) % controls.count] }
        initialFirstResponder = controls[0]
        if isKeyWindow { makeFirstResponder(controls[0]) }
    }

    private func focusableControls(in view: NSView?) -> [NSView] {
        guard let view else { return [] }
        var result = [NSView]()
        if let control = view as? NSControl,
           !(control is DesignSystemChipSelectControl),
           control.isEnabled,
           !control.isHidden,
           control.acceptsFirstResponder {
            result.append(control)
        }
        view.subviews.forEach { result.append(contentsOf: focusableControls(in: $0)) }
        return result
    }

    private var shouldAnimate: Bool {
        OnboardingTourResolver.shouldAnimate(windowVisible: isVisible, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private func complete(_ result: OnboardingTourCompletion) {
        guard completion != nil else { return }
        pendingCompletion = result
        close()
    }

    private func tearDown() -> ((OnboardingTourCompletion) -> Void)? {
        dismissAnimations()
        currentScene?.view.removeFromSuperview()
        currentScene = nil
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
        accessibilityObserver = nil
        let callback = completion
        completion = nil
        delegate = nil
        return callback
    }
}

extension OnboardingTourWindow: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        currentScene?.activate(animated: shouldAnimate)
    }

    func windowDidResignKey(_ notification: Notification) {
        dismissAnimations()
    }

    func windowWillClose(_ notification: Notification) {
        let result = pendingCompletion
        let callback = tearDown()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if Self.shared === self { Self.shared = nil }
            callback?(result)
        }
    }
}
