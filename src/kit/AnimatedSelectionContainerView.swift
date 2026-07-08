import Cocoa

protocol AnimatedSelectionItemView where Self: NSView {
    var selectionTarget: NSView { get }
    var selectionPadding: CGFloat { get }
    func setFocused(_ focused: Bool)
}

extension AnimatedSelectionItemView {
    var selectionTarget: NSView { self }
    var selectionPadding: CGFloat { 0 }
    func setFocused(_ focused: Bool) {}
}

struct AnimatedSelectionChrome {
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let fillColor: NSColor
    let borderColor: NSColor
    var borderAlpha: CGFloat
    var increasedContrastBorderAlpha: CGFloat

    init(cornerRadius: CGFloat,
         borderWidth: CGFloat,
         fillColor: NSColor,
         borderColor: NSColor,
         borderAlpha: CGFloat = 1,
         increasedContrastBorderAlpha: CGFloat = 1) {
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.fillColor = fillColor
        self.borderColor = borderColor
        self.borderAlpha = borderAlpha
        self.increasedContrastBorderAlpha = increasedContrastBorderAlpha
    }
}

struct AnimatedSelectionContainerConfiguration {
    let items: [AnimatedSelectionItemView]
    let orientation: NSUserInterfaceLayoutOrientation
    let alignment: NSLayoutConstraint.Attribute
    let spacing: CGFloat
    let contentVerticalOffset: CGFloat
    let containerSize: NSSize
    let containerChrome: AnimatedSelectionChrome
    let selectionChrome: AnimatedSelectionChrome
    let advanceInterval: TimeInterval
    let initialFocusedIndex: Int
    var selectionAnimationDuration: TimeInterval? = nil
    var shouldAdvance: (() -> Bool)? = nil
    var isWindowVisible: (() -> Bool)? = nil
    var accessibilityLabel: String? = nil
    var isAccessibilityElement: Bool = false
}

final class AnimatedSelectionPlaybackController {
    private(set) var isManuallyPaused = false
    var advanceInterval: TimeInterval
    var isWindowVisible: (() -> Bool)?
    var shouldAdvance: (() -> Bool)?
    var onAdvance: (() -> Void)?
    var onPauseStateRefresh: (() -> Void)?
    var onAccessibilityDisplayOptionsChanged: (() -> Void)?

    private var timer: Timer?
    private var accessibilityDisplayObserver: NSObjectProtocol?

    init(advanceInterval: TimeInterval) {
        self.advanceInterval = advanceInterval
    }

    deinit {
        timer?.invalidate()
        if let accessibilityDisplayObserver {
            NotificationCenter.default.removeObserver(accessibilityDisplayObserver)
        }
    }

    func start() {
        guard timer == nil, accessibilityDisplayObserver == nil else { return }
        scheduleTimer()
        observeAccessibilityDisplayOptions()
    }

    func toggleManualPause() {
        isManuallyPaused.toggle()
        onPauseStateRefresh?()
    }

    func updateAdvanceInterval(_ interval: TimeInterval) {
        guard interval != advanceInterval else { return }
        advanceInterval = interval
        guard timer != nil else { return }
        timer?.invalidate()
        scheduleTimer()
    }

    func updateShouldAdvance(_ closure: (() -> Bool)?) {
        shouldAdvance = closure
    }

    private func scheduleTimer() {
        let newTimer = Timer(timeInterval: advanceInterval, repeats: true) { [weak self] _ in
            self?.handleTimerTick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func observeAccessibilityDisplayOptions() {
        accessibilityDisplayObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.onPauseStateRefresh?()
            self?.onAccessibilityDisplayOptionsChanged?()
        }
    }

    private func handleTimerTick() {
        onPauseStateRefresh?()
        guard shouldRun() else { return }
        onAdvance?()
    }

    private func shouldRun() -> Bool {
        AnimatedSelectionResolver.shouldRun(
            isManuallyPaused: isManuallyPaused,
            isWindowVisible: isWindowVisible?() ?? false,
            prefersReducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            shouldAdvance: shouldAdvance?() ?? true)
    }
}

final class AnimatedSelectionContainerView: NSView {
    private let switcherView = NSView()
    private let stack = NSStackView()
    private let selectionView = NSView()
    private let playbackController: AnimatedSelectionPlaybackController

    private var configuration: AnimatedSelectionContainerConfiguration
    private var items = [AnimatedSelectionItemView]()
    private var selectionConstraints = [NSLayoutConstraint]()
    private var switcherSizeConstraints = [NSLayoutConstraint]()
    private var stackCenterYConstraint: NSLayoutConstraint?
    private var focusedIndex = 0

    var onPauseStateChange: (() -> Void)?

    init(configuration: AnimatedSelectionContainerConfiguration) {
        self.configuration = configuration
        self.playbackController = AnimatedSelectionPlaybackController(advanceInterval: configuration.advanceInterval)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        playbackController.start()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    override func accessibilityChildren() -> [Any]? { [] }
    override func isAccessibilityElement() -> Bool { configuration.isAccessibilityElement }

    var isManuallyPaused: Bool { playbackController.isManuallyPaused }

    func togglePause() {
        playbackController.toggleManualPause()
    }

    func updateConfiguration(_ configuration: AnimatedSelectionContainerConfiguration) {
        self.configuration = configuration
        playbackController.updateAdvanceInterval(configuration.advanceInterval)
        playbackController.updateShouldAdvance(configuration.shouldAdvance)
        setAccessibilityLabel(configuration.accessibilityLabel ?? "")
        rebuildItems()
        refreshColors()
    }

    private func setupView() {
        configureSwitcher()
        configurePlayback()
        setAccessibilityLabel(configuration.accessibilityLabel ?? "")
        rebuildItems()
        refreshColors()
    }

    private func configureSwitcher() {
        switcherView.translatesAutoresizingMaskIntoConstraints = false
        switcherView.wantsLayer = true
        selectionView.translatesAutoresizingMaskIntoConstraints = false
        selectionView.wantsLayer = true
        selectionView.isHidden = true
        switcherView.addSubview(selectionView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        switcherView.addSubview(stack)
        addSubview(switcherView)
        let centerYConstraint = stack.centerYAnchor.constraint(equalTo: switcherView.centerYAnchor)
        stackCenterYConstraint = centerYConstraint
        NSLayoutConstraint.activate([
            switcherView.centerXAnchor.constraint(equalTo: centerXAnchor),
            switcherView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: switcherView.centerXAnchor),
            centerYConstraint,
        ])
    }

    private func configurePlayback() {
        playbackController.isWindowVisible = { [weak self] in self?.window?.isVisible ?? false }
        playbackController.updateShouldAdvance(configuration.shouldAdvance)
        playbackController.onAdvance = { [weak self] in self?.advanceSelection() }
        playbackController.onPauseStateRefresh = { [weak self] in self?.onPauseStateChange?() }
        playbackController.onAccessibilityDisplayOptionsChanged = { [weak self] in self?.refreshColors() }
    }

    private func rebuildItems() {
        NSLayoutConstraint.deactivate(selectionConstraints)
        selectionConstraints.removeAll(keepingCapacity: true)
        selectionView.isHidden = true
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        items.removeAll(keepingCapacity: true)
        configureStack()
        configureSwitcherSize()
        configuration.items.forEach { item in
            items.append(item)
            stack.addArrangedSubview(item)
        }
        focusedIndex = configuration.initialFocusedIndex
        updateSelection()
    }

    private func configureStack() {
        stack.orientation = configuration.orientation
        stack.spacing = configuration.spacing
        stack.alignment = configuration.alignment
        stackCenterYConstraint?.constant = configuration.contentVerticalOffset
    }

    private func configureSwitcherSize() {
        NSLayoutConstraint.deactivate(switcherSizeConstraints)
        let size = configuration.containerSize
        switcherSizeConstraints = [
            switcherView.widthAnchor.constraint(equalToConstant: size.width),
            switcherView.heightAnchor.constraint(equalToConstant: size.height),
        ]
        NSLayoutConstraint.activate(switcherSizeConstraints)
    }

    private func advanceSelection() {
        focusedIndex = AnimatedSelectionResolver.nextFocusedIndex(current: focusedIndex, count: items.count)
        updateSelection()
    }

    private func updateSelection() {
        guard items.indices.contains(focusedIndex) else {
            selectionView.isHidden = true
            return
        }
        let focusedItem = items[focusedIndex]
        let target = focusedItem.selectionTarget
        let padding = focusedItem.selectionPadding
        applySelectionAnimation {
            selectionView.isHidden = false
            NSLayoutConstraint.deactivate(selectionConstraints)
            selectionConstraints = [
                selectionView.leadingAnchor.constraint(equalTo: target.leadingAnchor, constant: -padding),
                selectionView.trailingAnchor.constraint(equalTo: target.trailingAnchor, constant: padding),
                selectionView.topAnchor.constraint(equalTo: target.topAnchor, constant: -padding),
                selectionView.bottomAnchor.constraint(equalTo: target.bottomAnchor, constant: padding),
            ]
            NSLayoutConstraint.activate(selectionConstraints)
            items.enumerated().forEach { index, item in
                item.setFocused(index == focusedIndex)
            }
            layoutSubtreeIfNeeded()
        }
    }

    private func applySelectionAnimation(_ body: () -> Void) {
        guard let duration = configuration.selectionAnimationDuration else {
            caTransaction(body)
            return
        }
        CATransaction.begin()
        defer { CATransaction.commit() }
        CATransaction.setAnimationDuration(duration)
        body()
    }

    private func refreshColors() {
        let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        applyChrome(configuration.containerChrome, to: switcherView, increaseContrast: increaseContrast)
        applyChrome(configuration.selectionChrome, to: selectionView, increaseContrast: increaseContrast)
    }

    private func applyChrome(_ chrome: AnimatedSelectionChrome, to view: NSView, increaseContrast: Bool) {
        view.layer?.cornerRadius = chrome.cornerRadius
        view.layer?.backgroundColor = chrome.fillColor.cgColor
        view.layer?.borderColor = chrome.borderColor
            .withAlphaComponent(increaseContrast ? chrome.increasedContrastBorderAlpha : chrome.borderAlpha)
            .cgColor
        view.layer?.borderWidth = chrome.borderWidth
    }
}
