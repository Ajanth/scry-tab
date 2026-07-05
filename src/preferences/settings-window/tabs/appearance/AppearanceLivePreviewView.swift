import Cocoa

private enum PreviewMetrics {
    static let wallpaperAspectRatio = CGFloat(1.6)
    static let wallpaperCornerRadius = CGFloat(18)
    static let wallpaperBorderWidth = CGFloat(1)

    static let switcherCornerRadius = CGFloat(16)
    static let switcherBorderWidth = CGFloat(1)

    static let appIconsSwitcherWidth = CGFloat(200)
    static let appIconsSwitcherHeight = CGFloat(72)
    static let appIconsTileWidth = CGFloat(57)
    static let appIconsTileHeight = CGFloat(57)
    static let appIconsTileSpacing = CGFloat(8)
    static let appIconsTileCornerRadius = CGFloat(11)
    static let appIconsIconSize = CGFloat(39)
    static let appIconsLabelFontSize = CGFloat(7.5)
    static let appIconsLabelInset = CGFloat(7)

    static let titlesSwitcherWidth = CGFloat(164)
    static let titlesSwitcherHeight = CGFloat(92)
    static let titlesRowWidth = CGFloat(146)
    static let titlesRowHeight = CGFloat(24)
    static let titlesRowSpacing = CGFloat(7)
    static let titlesRowCornerRadius = CGFloat(10)
    static let titlesIconSize = CGFloat(15)
    static let titlesLabelFontSize = CGFloat(8.5)
    static let titlesSideInset = CGFloat(8)
    static let titlesLabelGap = CGFloat(8)
    static let titlesStatusGap = CGFloat(7)
    static let titlesStatusSize = CGFloat(16)

    static let pauseButtonDiameter = CGFloat(22)
    static let pauseButtonInset = CGFloat(10)
    static let pauseButtonGlyphSize = CGFloat(11)

    static let advanceInterval = TimeInterval(1.8)
    static let animationDuration = TimeInterval(0.35)
}

private enum PreviewPalette {
    static let wallpaperTopLeft = NSColor(srgbRed: 0.87, green: 0.40, blue: 0.31, alpha: 1)
    static let wallpaperTopRight = NSColor(srgbRed: 0.36, green: 0.44, blue: 0.95, alpha: 1)
    static let wallpaperBottom = NSColor(srgbRed: 0.33, green: 0.54, blue: 0.16, alpha: 1)
    static let wallpaperOrangeBlob = NSColor(srgbRed: 0.96, green: 0.43, blue: 0.26, alpha: 0.8)
    static let wallpaperBlueBlob = NSColor(srgbRed: 0.45, green: 0.46, blue: 0.97, alpha: 0.72)
    static let wallpaperGreenBlob = NSColor(srgbRed: 0.45, green: 0.64, blue: 0.05, alpha: 0.46)
    static let wallpaperBorder = NSColor.white.withAlphaComponent(0.12)

    static let switcherFill = NSColor.white.withAlphaComponent(0.33)
    static let switcherBorder = NSColor.white.withAlphaComponent(0.2)
    static let tileFill = NSColor(srgbRed: 0.26, green: 0.28, blue: 0.26, alpha: 0.76)
    static let focusedFill = NSColor(srgbRed: 0.33, green: 0.29, blue: 0.30, alpha: 0.82)
    static let titleColor = NSColor.white.withAlphaComponent(0.94)
    static let titleStatusColor = NSColor.white.withAlphaComponent(0.94)
    static let pauseFill = NSColor.black.withAlphaComponent(0.12)
    static let pauseHoverFill = NSColor.black.withAlphaComponent(0.18)
    static let pauseBorder = NSColor.white.withAlphaComponent(0.12)
    static let pauseGlyph = NSColor.white.withAlphaComponent(0.86)
}

private struct PreviewDemoItem {
    let bundleId: String
    let statusSymbols: [String]
}

private let previewDemoItems = [
    PreviewDemoItem(bundleId: "com.apple.Safari",
                    statusSymbols: [Symbols.circledPlusSign.rawValue, StatusIconsView.symbolForSpace(2)]),
    PreviewDemoItem(bundleId: "com.apple.finder",
                    statusSymbols: [Symbols.circledPlusSign.rawValue, StatusIconsView.symbolForSpace(2)]),
    PreviewDemoItem(bundleId: "com.apple.Notes",
                    statusSymbols: [StatusIconsView.symbolForSpace(1)]),
]

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
        PreviewPalette.pauseGlyph.setFill()
        if symbol == .play {
            drawPlay()
            return
        }
        drawPause()
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

private final class AppearanceLivePreviewWallpaperView: NSView {
    override var isOpaque: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func draw(_ dirtyRect: NSRect) {
        let clipPath = NSBezierPath(roundedRect: bounds,
                                    xRadius: PreviewMetrics.wallpaperCornerRadius,
                                    yRadius: PreviewMetrics.wallpaperCornerRadius)
        clipPath.addClip()
        drawBaseGradient()
        drawBlob(NSRect(x: bounds.minX - bounds.width * 0.34,
                        y: bounds.midY - bounds.height * 0.16,
                        width: bounds.width * 1.18,
                        height: bounds.height * 0.84),
                 color: PreviewPalette.wallpaperOrangeBlob)
        drawBlob(NSRect(x: bounds.midX - bounds.width * 0.05,
                        y: bounds.minY - bounds.height * 0.08,
                        width: bounds.width * 0.88,
                        height: bounds.height * 0.9),
                 color: PreviewPalette.wallpaperBlueBlob)
        drawBlob(NSRect(x: bounds.minX - bounds.width * 0.1,
                        y: bounds.minY - bounds.height * 0.4,
                        width: bounds.width * 1.2,
                        height: bounds.height * 0.9),
                 color: PreviewPalette.wallpaperGreenBlob)
        PreviewPalette.wallpaperBorder.setStroke()
        clipPath.lineWidth = PreviewMetrics.wallpaperBorderWidth
        clipPath.stroke()
    }

    private func drawBaseGradient() {
        let gradient = NSGradient(colors: [
            PreviewPalette.wallpaperTopLeft,
            PreviewPalette.wallpaperTopRight,
            PreviewPalette.wallpaperBottom,
        ])!
        gradient.draw(in: bounds, angle: -38)
    }

    private func drawBlob(_ rect: NSRect, color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }
}

private class AppearanceLivePreviewItemView: NSView {
    private let backgroundView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        backgroundView.layer?.backgroundColor = PreviewPalette.tileFill.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func setCornerRadius(_ radius: CGFloat) {
        backgroundView.layer?.cornerRadius = radius
    }

    func setFocused(_ focused: Bool, animated: Bool) {}

    func finishFocusAnimation(_ focused: Bool) {}
}

private final class AppearanceLivePreviewAppIconTileView: AppearanceLivePreviewItemView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var isFocusedState = false

    init(_ info: AppDisplayInfo) {
        super.init(frame: .zero)
        setCornerRadius(PreviewMetrics.appIconsTileCornerRadius)
        configureIcon(info.icon)
        configureTitle(info.name)
        activateConstraints()
        setFocused(false, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func setFocused(_ focused: Bool, animated: Bool) {
        isFocusedState = focused
        guard animated else {
            titleLabel.isHidden = !focused
            titleLabel.alphaValue = focused ? 1 : 0
            return
        }
        if focused {
            titleLabel.isHidden = false
        }
        titleLabel.animator().alphaValue = focused ? 1 : 0
    }

    override func finishFocusAnimation(_ focused: Bool) {
        guard !focused, !isFocusedState else { return }
        titleLabel.isHidden = true
    }

    private func configureIcon(_ icon: NSImage) {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.isEditable = false
        iconView.shadow = TileView.makeAppIconShadow(NSColor.black.withAlphaComponent(0.45))
        addSubview(iconView)
    }

    private func configureTitle(_ title: String) {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: PreviewMetrics.appIconsLabelFontSize)
        titleLabel.textColor = PreviewPalette.titleColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true
        addSubview(titleLabel)
    }

    private func activateConstraints() {
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PreviewMetrics.appIconsTileWidth),
            heightAnchor.constraint(equalToConstant: PreviewMetrics.appIconsTileHeight),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: PreviewMetrics.appIconsIconSize),
            iconView.heightAnchor.constraint(equalToConstant: PreviewMetrics.appIconsIconSize),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -PreviewMetrics.appIconsLabelInset),
        ])
    }
}

private final class AppearanceLivePreviewTitlesRowView: AppearanceLivePreviewItemView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let statusStack = NSStackView()

    init(_ info: AppDisplayInfo, statusSymbols: [String]) {
        super.init(frame: .zero)
        setCornerRadius(PreviewMetrics.titlesRowCornerRadius)
        configureIcon(info.icon)
        configureTitle(info.name)
        configureStatusStack(statusSymbols)
        activateConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func configureIcon(_ icon: NSImage) {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.isEditable = false
        addSubview(iconView)
    }

    private func configureTitle(_ title: String) {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: PreviewMetrics.titlesLabelFontSize)
        titleLabel.textColor = PreviewPalette.titleColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true
        addSubview(titleLabel)
    }

    private func configureStatusStack(_ statusSymbols: [String]) {
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = PreviewMetrics.titlesStatusGap
        addSubview(statusStack)
        statusSymbols.forEach { symbol in
            let view = TileFontIconView(rendering: .symbol,
                                        initialText: symbol,
                                        size: PreviewMetrics.titlesStatusSize,
                                        symbolColor: PreviewPalette.titleStatusColor,
                                        badgeFillColor: .clear,
                                        badgeTextColor: .clear)
            view.translatesAutoresizingMaskIntoConstraints = false
            statusStack.addArrangedSubview(view)
        }
    }

    private func activateConstraints() {
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PreviewMetrics.titlesRowWidth),
            heightAnchor.constraint(equalToConstant: PreviewMetrics.titlesRowHeight),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PreviewMetrics.titlesSideInset),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: PreviewMetrics.titlesIconSize),
            iconView.heightAnchor.constraint(equalToConstant: PreviewMetrics.titlesIconSize),
            statusStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PreviewMetrics.titlesSideInset),
            statusStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: PreviewMetrics.titlesLabelGap),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusStack.leadingAnchor, constant: -PreviewMetrics.titlesLabelGap),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

final class AppearanceLivePreviewView: NSView {
    static let pauseAccessibilityLabel = NSLocalizedString("Pause preview animation", comment: "")
    static let resumeAccessibilityLabel = NSLocalizedString("Resume preview animation", comment: "")
    static let previewAccessibilityLabel = NSLocalizedString("Preview of the selected appearance style", comment: "")

    private let wallpaperView = AppearanceLivePreviewWallpaperView()
    private let switcherView = NSView()
    private let stack = NSStackView()
    private let selectionView = NSView()
    private let pauseButton: ClickHoverImageView = {
        let glyph = AppearanceLivePreviewPlaybackGlyphView(symbol: .pause)
        glyph.translatesAutoresizingMaskIntoConstraints = false
        let button = ClickHoverImageView(infoCircle: glyph)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var items = [AppearanceLivePreviewItemView]()
    private var selectionConstraints = [NSLayoutConstraint]()
    private var switcherSizeConstraints = [NSLayoutConstraint]()
    private var focusedIndex = 0
    private var currentStyle = AppearanceStylePreference.appIcons
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
        currentStyle = style
        rebuildItems(for: style)
        refreshColors()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel(Self.previewAccessibilityLabel)
        configureWallpaper()
        configureSwitcher()
        configurePauseButton()
        activateConstraints()
        refreshColors()
        scheduleTimer()
        accessibilityDisplayObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshPauseButtonState()
            self?.refreshColors()
        }
    }

    private func configureWallpaper() {
        addSubview(wallpaperView)
        wallpaperView.addSubview(switcherView)
        wallpaperView.addSubview(pauseButton)
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
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: switcherView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: switcherView.centerYAnchor),
        ])
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
        guard let glyph = pauseButton.infoCircle else { return }
        NSLayoutConstraint.activate([
            glyph.centerXAnchor.constraint(equalTo: pauseButton.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: pauseButton.centerYAnchor),
        ])
    }

    private func activateConstraints() {
        NSLayoutConstraint.activate([
            wallpaperView.leadingAnchor.constraint(equalTo: leadingAnchor),
            wallpaperView.trailingAnchor.constraint(equalTo: trailingAnchor),
            wallpaperView.centerYAnchor.constraint(equalTo: centerYAnchor),
            wallpaperView.heightAnchor.constraint(equalTo: wallpaperView.widthAnchor,
                                                  multiplier: 1 / PreviewMetrics.wallpaperAspectRatio),
            wallpaperView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            wallpaperView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            switcherView.centerXAnchor.constraint(equalTo: wallpaperView.centerXAnchor),
            switcherView.centerYAnchor.constraint(equalTo: wallpaperView.centerYAnchor),
            pauseButton.topAnchor.constraint(equalTo: wallpaperView.topAnchor, constant: PreviewMetrics.pauseButtonInset),
            pauseButton.trailingAnchor.constraint(equalTo: wallpaperView.trailingAnchor, constant: -PreviewMetrics.pauseButtonInset),
            pauseButton.widthAnchor.constraint(equalToConstant: PreviewMetrics.pauseButtonDiameter),
            pauseButton.heightAnchor.constraint(equalToConstant: PreviewMetrics.pauseButtonDiameter),
        ])
    }

    private func rebuildItems(for style: AppearanceStylePreference) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        items.removeAll(keepingCapacity: true)
        configureStack(for: style)
        configureSwitcherSize(for: style)
        previewDemoItems.forEach { item in
            let info = AppDisplayInfo.resolve(bundleId: item.bundleId)
            let view: AppearanceLivePreviewItemView
            if style == .appIcons {
                view = AppearanceLivePreviewAppIconTileView(info)
            } else {
                view = AppearanceLivePreviewTitlesRowView(info, statusSymbols: item.statusSymbols)
            }
            items.append(view)
            stack.addArrangedSubview(view)
        }
        focusedIndex = defaultFocusedIndex(for: style, count: items.count)
        updateSelection(animated: false)
    }

    private func configureStack(for style: AppearanceStylePreference) {
        stack.orientation = style == .appIcons ? .horizontal : .vertical
        stack.spacing = style == .appIcons ? PreviewMetrics.appIconsTileSpacing : PreviewMetrics.titlesRowSpacing
        stack.alignment = style == .appIcons ? .centerY : .centerX
    }

    private func configureSwitcherSize(for style: AppearanceStylePreference) {
        NSLayoutConstraint.deactivate(switcherSizeConstraints)
        let width = style == .appIcons ? PreviewMetrics.appIconsSwitcherWidth : PreviewMetrics.titlesSwitcherWidth
        let height = style == .appIcons ? PreviewMetrics.appIconsSwitcherHeight : PreviewMetrics.titlesSwitcherHeight
        switcherSizeConstraints = [
            switcherView.widthAnchor.constraint(equalToConstant: width),
            switcherView.heightAnchor.constraint(equalToConstant: height),
        ]
        NSLayoutConstraint.activate(switcherSizeConstraints)
    }

    private func defaultFocusedIndex(for style: AppearanceStylePreference, count: Int) -> Int {
        guard count > 0 else { return 0 }
        if style == .appIcons {
            return min(1, count - 1)
        }
        return 0
    }

    private func updateSelection(animated: Bool) {
        guard items.indices.contains(focusedIndex) else {
            selectionView.isHidden = true
            return
        }
        selectionView.isHidden = false
        NSLayoutConstraint.deactivate(selectionConstraints)
        let focusedItem = items[focusedIndex]
        selectionConstraints = [
            selectionView.leadingAnchor.constraint(equalTo: focusedItem.leadingAnchor),
            selectionView.trailingAnchor.constraint(equalTo: focusedItem.trailingAnchor),
            selectionView.topAnchor.constraint(equalTo: focusedItem.topAnchor),
            selectionView.bottomAnchor.constraint(equalTo: focusedItem.bottomAnchor),
        ]
        NSLayoutConstraint.activate(selectionConstraints)
        let applyState = {
            self.items.enumerated().forEach { index, item in
                item.setFocused(index == self.focusedIndex, animated: animated)
            }
        }
        guard animated else {
            applyState()
            layoutSubtreeIfNeeded()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = PreviewMetrics.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            applyState()
            self.layoutSubtreeIfNeeded()
        } completionHandler: {
            self.items.enumerated().forEach { index, item in
                item.finishFocusAnimation(index == self.focusedIndex)
            }
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
        focusedIndex = AppearanceLivePreviewResolver.nextFocusedIndex(current: focusedIndex, count: items.count)
        updateSelection(animated: true)
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
        let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        switcherView.layer?.cornerRadius = PreviewMetrics.switcherCornerRadius
        switcherView.layer?.backgroundColor = PreviewPalette.switcherFill.cgColor
        switcherView.layer?.borderColor = PreviewPalette.switcherBorder
            .withAlphaComponent(increaseContrast ? 0.34 : 0.2)
            .cgColor
        switcherView.layer?.borderWidth = PreviewMetrics.switcherBorderWidth
        let selectionRadius = currentStyle == .appIcons
            ? PreviewMetrics.appIconsTileCornerRadius
            : PreviewMetrics.titlesRowCornerRadius
        selectionView.layer?.cornerRadius = selectionRadius
        selectionView.layer?.backgroundColor = PreviewPalette.focusedFill.cgColor
        pauseButton.layer?.backgroundColor = (isPauseButtonHovered
            ? PreviewPalette.pauseHoverFill
            : PreviewPalette.pauseFill).cgColor
        pauseButton.layer?.borderColor = PreviewPalette.pauseBorder
            .withAlphaComponent(increaseContrast ? 0.28 : 0.12)
            .cgColor
    }
}
