import Cocoa

/// Sizing for the decorative demo tiles. Always renders at this single compact scale — it
/// ignores the user's Size preference on purpose, since it depicts a handful of fixed demo apps
/// rather than the user's actual windows.
private enum PreviewMetrics {
    static let appIconsTileWidth = CGFloat(44)
    static let appIconsIconSize = CGFloat(36)
    static let appIconsLabelGap = CGFloat(4)
    static let appIconsLabelFontSize = CGFloat(9)
    static let appIconsStackSpacing = CGFloat(3)

    static let titlesRowWidth = CGFloat(236)
    static let titlesRowHeight = CGFloat(26)
    static let titlesIconSize = CGFloat(18)
    static let titlesLabelGap = CGFloat(8)
    static let titlesRowInset = CGFloat(6)
    static let titlesStackSpacing = CGFloat(2)

    static let pauseButtonDiameter = CGFloat(22)
    static let pauseButtonInset = CGFloat(8)
    static let pauseButtonGlyphSize = CGFloat(11)

    static let advanceInterval = TimeInterval(1.8)
    static let slideAnimationDuration = 0.35
}

private final class AppearanceLivePreviewPlaybackGlyphView: NSView {
    enum Symbol {
        case play
        case pause
    }

    var symbol: Symbol {
        didSet {
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: PreviewMetrics.pauseButtonGlyphSize, height: PreviewMetrics.pauseButtonGlyphSize)
    }

    init(symbol: Symbol) {
        self.symbol = symbol
        let size = NSSize(width: PreviewMetrics.pauseButtonGlyphSize, height: PreviewMetrics.pauseButtonGlyphSize)
        super.init(frame: NSRect(origin: .zero, size: size))
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.setFill()
        if symbol == .play {
            drawPlay()
        } else {
            drawPause()
        }
    }

    private func drawPlay() {
        let rect = bounds.insetBy(dx: bounds.width * 0.2, dy: bounds.height * 0.12)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.close()
        path.fill()
    }

    private func drawPause() {
        let height = bounds.height * 0.74
        let width = bounds.width * 0.24
        let gap = bounds.width * 0.18
        let y = bounds.midY - height / 2
        let leftX = bounds.midX - gap / 2 - width
        let rightX = bounds.midX + gap / 2
        drawPauseBar(NSRect(x: leftX, y: y, width: width, height: height))
        drawPauseBar(NSRect(x: rightX, y: y, width: width, height: height))
    }

    private func drawPauseBar(_ rect: NSRect) {
        let radius = rect.width / 2
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
}

/// Always-installed Apple apps used as stand-ins for the user's own windows. Resolved through
/// `AppDisplayInfo`, the same bundle-id-to-(name, icon) lookup the Exceptions tab uses, so this
/// never touches live window/Accessibility state.
private let demoAppBundleIds = [
    "com.apple.finder",
    "com.apple.Safari",
    "com.apple.mail",
    "com.apple.iCal",
    "com.apple.Notes",
]

/// A single decorative demo tile: an app icon plus its name, laid out either as a centered
/// App-Icons-style card or a leading-aligned Titles-style row. Purely presentational — it never
/// registers a click handler and isn't part of the key-view loop.
private final class AppearanceLivePreviewTileView: NSView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    init(_ info: AppDisplayInfo, style: AppearanceStylePreference) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configureIconView(info.icon)
        configureNameLabel(info.name)
        if style == .appIcons {
            layoutAsAppIconCard()
        } else {
            layoutAsTitleRow()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func configureIconView(_ icon: NSImage) {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.isEditable = false
        addSubview(iconView)
    }

    private func configureNameLabel(_ name: String) {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.stringValue = name
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.usesSingleLineMode = true
        addSubview(nameLabel)
    }

    private func layoutAsAppIconCard() {
        nameLabel.font = NSFont.systemFont(ofSize: PreviewMetrics.appIconsLabelFontSize)
        nameLabel.alignment = .center
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PreviewMetrics.appIconsTileWidth),
            iconView.widthAnchor.constraint(equalToConstant: PreviewMetrics.appIconsIconSize),
            iconView.heightAnchor.constraint(equalToConstant: PreviewMetrics.appIconsIconSize),
            iconView.topAnchor.constraint(equalTo: topAnchor),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: PreviewMetrics.appIconsLabelGap),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func layoutAsTitleRow() {
        nameLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        nameLabel.alignment = .natural
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PreviewMetrics.titlesRowWidth),
            heightAnchor.constraint(equalToConstant: PreviewMetrics.titlesRowHeight),
            iconView.widthAnchor.constraint(equalToConstant: PreviewMetrics.titlesIconSize),
            iconView.heightAnchor.constraint(equalToConstant: PreviewMetrics.titlesIconSize),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PreviewMetrics.titlesRowInset),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: PreviewMetrics.titlesLabelGap),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -PreviewMetrics.titlesRowInset),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

/// A non-interactive, looping animation of demo app tiles for the Appearance tab's style
/// preview. Visually echoes the real switcher's tile layout and selection highlight, but is a
/// fully self-contained clone: its own demo tiles, its own timer, and read-only use of
/// `DesignSystem` tokens. It never touches `TilesView`, `TilesPanel`, `SwitcherSession.current`,
/// or the global `Appearance` singleton, so it can never collide with a live switcher session.
final class AppearanceLivePreviewView: NSView {
    static let pauseAccessibilityLabel = NSLocalizedString("Pause preview animation", comment: "")
    static let resumeAccessibilityLabel = NSLocalizedString("Resume preview animation", comment: "")
    static let previewAccessibilityLabel = NSLocalizedString("Preview of the selected appearance style", comment: "")

    private let stack = NSStackView()
    private let highlightView = NSView()
    private let pauseButton: ClickHoverImageView = {
        let glyph = AppearanceLivePreviewPlaybackGlyphView(symbol: .pause)
        glyph.translatesAutoresizingMaskIntoConstraints = false
        let button = ClickHoverImageView(infoCircle: glyph)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var tiles = [NSView]()
    private var highlightConstraints = [NSLayoutConstraint]()
    private var focusedIndex = 0
    private var isManuallyPaused = false
    private var isPauseButtonHovered = false
    private var timer: Timer?
    private var accessibilityDisplayObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        timer?.invalidate()
        if let accessibilityDisplayObserver {
            NotificationCenter.default.removeObserver(accessibilityDisplayObserver)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshPauseButtonState()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    override func accessibilityChildren() -> [Any]? {
        [pauseButton]
    }

    override func isAccessibilityElement() -> Bool { true }

    func updateStyle(_ style: AppearanceStylePreference) {
        rebuildTiles(for: style)
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel(Self.previewAccessibilityLabel)
        configureHighlightView()
        configureStack()
        configurePauseButton()
        activateChromeConstraints()
        refreshColors()
        scheduleTimer()
        accessibilityDisplayObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshPauseButtonState()
        }
    }

    private func configureHighlightView() {
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = DesignSystem.Metrics.sidebarSelectionRadius
        // Unlike TileView/TileUnderLayer, this decorative preview is meant to visibly slide
        // between tiles, so it deliberately keeps AppKit's default implicit layer animations
        // instead of the NoAnimationDelegate the live switcher uses everywhere else.
        addSubview(highlightView)
    }

    private func configureStack() {
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
    }

    private func configurePauseButton() {
        pauseButton.wantsLayer = true
        pauseButton.layer?.cornerRadius = PreviewMetrics.pauseButtonDiameter / 2
        pauseButton.layer?.borderWidth = 1
        pauseButton.setAccessibilityRole(.button)
        pauseButton.onClick = { [weak self] _, _ in self?.toggleManualPause() }
        pauseButton.onAccessibilityPress = { [weak self] in
            guard let self else { return false }
            self.toggleManualPause()
            return true
        }
        pauseButton.onMouseEntered = { [weak self] _, _ in self?.setPauseButtonHovered(true) }
        pauseButton.onMouseExited = { [weak self] _, _ in self?.setPauseButtonHovered(false) }
        addSubview(pauseButton)
        guard let glyph = pauseButton.infoCircle else { return }
        NSLayoutConstraint.activate([
            glyph.centerXAnchor.constraint(equalTo: pauseButton.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: pauseButton.centerYAnchor),
        ])
    }

    private func activateChromeConstraints() {
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            pauseButton.topAnchor.constraint(equalTo: topAnchor, constant: PreviewMetrics.pauseButtonInset),
            pauseButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PreviewMetrics.pauseButtonInset),
            pauseButton.widthAnchor.constraint(equalToConstant: PreviewMetrics.pauseButtonDiameter),
            pauseButton.heightAnchor.constraint(equalToConstant: PreviewMetrics.pauseButtonDiameter),
        ])
    }

    private func rebuildTiles(for style: AppearanceStylePreference) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        stack.orientation = style == .appIcons ? .horizontal : .vertical
        stack.spacing = style == .appIcons ? PreviewMetrics.appIconsStackSpacing : PreviewMetrics.titlesStackSpacing
        stack.alignment = style == .appIcons ? .top : .leading
        tiles = demoAppBundleIds.map { AppearanceLivePreviewTileView(AppDisplayInfo.resolve(bundleId: $0), style: style) }
        tiles.forEach { stack.addArrangedSubview($0) }
        focusedIndex = tiles.indices.contains(focusedIndex) ? focusedIndex : 0
        updateHighlight(animated: false)
    }

    private func updateHighlight(animated: Bool) {
        guard tiles.indices.contains(focusedIndex) else { return }
        let focusedTile = tiles[focusedIndex]
        NSLayoutConstraint.deactivate(highlightConstraints)
        highlightConstraints = [
            highlightView.leadingAnchor.constraint(equalTo: focusedTile.leadingAnchor),
            highlightView.trailingAnchor.constraint(equalTo: focusedTile.trailingAnchor),
            highlightView.topAnchor.constraint(equalTo: focusedTile.topAnchor),
            highlightView.bottomAnchor.constraint(equalTo: focusedTile.bottomAnchor),
        ]
        NSLayoutConstraint.activate(highlightConstraints)
        guard animated else {
            layoutSubtreeIfNeeded()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = PreviewMetrics.slideAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            self.layoutSubtreeIfNeeded()
        }
    }

    private func scheduleTimer() {
        let newTimer = Timer(timeInterval: PreviewMetrics.advanceInterval, repeats: true) { [weak self] _ in
            self?.handleTimerTick()
        }
        newTimer.tolerance = PreviewMetrics.advanceInterval * 0.2
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func handleTimerTick() {
        refreshPauseButtonState()
        guard isRunning() else { return }
        focusedIndex = AppearanceLivePreviewResolver.nextFocusedIndex(current: focusedIndex, count: tiles.count)
        updateHighlight(animated: true)
    }

    private func toggleManualPause() {
        isManuallyPaused.toggle()
        refreshPauseButtonState()
    }

    private func setPauseButtonHovered(_ hovered: Bool) {
        isPauseButtonHovered = hovered
        refreshColors()
    }

    private func isRunning() -> Bool {
        AppearanceLivePreviewResolver.shouldRun(
            isManuallyPaused: isManuallyPaused,
            isWindowVisible: window?.isVisible ?? false,
            isSwitcherActive: SwitcherSession.isActive,
            prefersReducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private func refreshPauseButtonState() {
        (pauseButton.infoCircle as? AppearanceLivePreviewPlaybackGlyphView)?.symbol = isManuallyPaused ? .play : .pause
        let label = isManuallyPaused ? Self.resumeAccessibilityLabel : Self.pauseAccessibilityLabel
        pauseButton.setAccessibilityLabel(label)
        pauseButton.toolTip = label
    }

    private func refreshColors() {
        highlightView.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfaceSelected, in: self)
        highlightView.layer?.borderColor = DesignSystem.semanticCGColor(.borderSelected, in: self)
        highlightView.layer?.borderWidth = 1
        let backgroundRole: DesignSystem.ColorRole = isPauseButtonHovered ? .surfaceHover : .surfaceFlat
        pauseButton.layer?.backgroundColor = DesignSystem.semanticCGColor(backgroundRole, in: self)
        pauseButton.layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: self)
    }
}
