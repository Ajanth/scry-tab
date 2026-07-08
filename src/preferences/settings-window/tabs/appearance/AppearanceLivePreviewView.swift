import Cocoa

private typealias PreviewArtwork = AppearanceLivePreviewArtwork

final class AppearanceLivePreviewView: NSView {
    static let pauseAccessibilityLabel = NSLocalizedString("Pause preview animation", comment: "")
    static let resumeAccessibilityLabel = NSLocalizedString("Resume preview animation", comment: "")
    static let previewAccessibilityLabel = NSLocalizedString("Preview of the selected appearance style", comment: "")

    private let wallpaperView = PreviewArtwork.WallpaperView()
    private var selectionContainer: AnimatedSelectionContainerView?
    private let pauseButton: ClickHoverImageView = {
        let glyph = AppearanceLivePreviewPauseGlyphView(symbol: .pause)
        glyph.translatesAutoresizingMaskIntoConstraints = false
        let button = ClickHoverImageView(infoCircle: glyph)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var currentStyle = AppearanceStylePreference.appIcons
    private var isPauseButtonHovered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
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
        selectionContainer?.updateConfiguration(makeConfiguration(for: style))
        refreshColors()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel(Self.previewAccessibilityLabel)
        configureWallpaper()
        configureContainer(for: currentStyle)
        configurePauseButton()
        activateConstraints()
        selectionContainer?.onPauseStateChange = { [weak self] in self?.refreshPauseButtonState() }
        refreshColors()
    }

    private func configureWallpaper() {
        addSubview(wallpaperView)
        wallpaperView.addSubview(pauseButton)
    }

    private func configureContainer(for style: AppearanceStylePreference) {
        let container = AnimatedSelectionContainerView(configuration: makeConfiguration(for: style))
        container.translatesAutoresizingMaskIntoConstraints = false
        wallpaperView.addSubview(container)
        selectionContainer = container
    }

    private func configurePauseButton() {
        pauseButton.wantsLayer = true
        pauseButton.layer?.cornerRadius = PreviewArtwork.Metrics.pauseButtonDiameter / 2
        pauseButton.layer?.borderWidth = 1
        pauseButton.setAccessibilityRole(.button)
        pauseButton.onClick = { [weak self] _, _ in self?.selectionContainer?.togglePause() }
        pauseButton.onAccessibilityPress = { [weak self] in
            guard let self else { return false }
            self.selectionContainer?.togglePause()
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
        guard let container = selectionContainer else { return }
        NSLayoutConstraint.activate([
            wallpaperView.leadingAnchor.constraint(equalTo: leadingAnchor),
            wallpaperView.trailingAnchor.constraint(equalTo: trailingAnchor),
            wallpaperView.topAnchor.constraint(equalTo: topAnchor),
            wallpaperView.heightAnchor.constraint(equalTo: wallpaperView.widthAnchor,
                                                  multiplier: 1 / PreviewArtwork.Metrics.wallpaperAspectRatio),
            wallpaperView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            container.leadingAnchor.constraint(equalTo: wallpaperView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: wallpaperView.trailingAnchor),
            container.topAnchor.constraint(equalTo: wallpaperView.topAnchor),
            container.bottomAnchor.constraint(equalTo: wallpaperView.bottomAnchor),
            pauseButton.topAnchor.constraint(equalTo: wallpaperView.topAnchor,
                                             constant: PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.trailingAnchor.constraint(equalTo: wallpaperView.trailingAnchor,
                                                  constant: -PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.widthAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
            pauseButton.heightAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
        ])
    }

    private func makeConfiguration(for style: AppearanceStylePreference) -> AnimatedSelectionContainerConfiguration {
        AnimatedSelectionContainerConfiguration(
            items: makeItems(for: style),
            orientation: style == .appIcons ? .horizontal : .vertical,
            alignment: style == .appIcons ? .centerY : .centerX,
            spacing: style == .appIcons
                ? PreviewArtwork.Metrics.appIconsTileSpacing
                : PreviewArtwork.Metrics.titlesRowSpacing,
            contentVerticalOffset: style == .appIcons
                ? PreviewArtwork.Metrics.appIconsContentVerticalOffset
                : 0,
            containerSize: style == .appIcons
                ? NSSize(width: PreviewArtwork.Metrics.appIconsSwitcherWidth,
                         height: PreviewArtwork.Metrics.appIconsSwitcherHeight)
                : NSSize(width: PreviewArtwork.Metrics.titlesSwitcherWidth,
                         height: PreviewArtwork.Metrics.titlesSwitcherHeight),
            containerChrome: makeSwitcherChrome(),
            selectionChrome: makeSelectionChrome(for: style),
            advanceInterval: AppearanceLivePreviewResolver.advanceInterval,
            initialFocusedIndex: defaultFocusedIndex(for: style),
            shouldAdvance: { !SwitcherSession.isActive },
            accessibilityLabel: Self.previewAccessibilityLabel,
            isAccessibilityElement: false)
    }

    private func makeItems(for style: AppearanceStylePreference) -> [AnimatedSelectionItemView] {
        var views = [AnimatedSelectionItemView]()
        PreviewArtwork.demoItems.forEach { item in
            let resolvedInfo = AppDisplayInfo.resolve(bundleId: item.bundleId)
            let info = AppDisplayInfo(name: item.displayName, icon: resolvedInfo.icon)
            let view: PreviewArtwork.ItemView
            if style == .appIcons {
                view = PreviewArtwork.AppIconTileView(info)
            } else {
                view = PreviewArtwork.TitlesRowView(info, statusSymbols: item.statusSymbols)
            }
            views.append(view)
        }
        return views
    }

    private func makeSwitcherChrome() -> AnimatedSelectionChrome {
        AnimatedSelectionChrome(
            cornerRadius: PreviewArtwork.Metrics.switcherCornerRadius,
            borderWidth: PreviewArtwork.Metrics.switcherBorderWidth,
            fillColor: PreviewArtwork.Palette.switcherFill,
            borderColor: PreviewArtwork.Palette.switcherBorder,
            borderAlpha: 0.2,
            increasedContrastBorderAlpha: 0.34)
    }

    private func makeSelectionChrome(for style: AppearanceStylePreference) -> AnimatedSelectionChrome {
        let cornerRadius = style == .appIcons
            ? PreviewArtwork.Metrics.appIconsSelectionCornerRadius
            : PreviewArtwork.Metrics.titlesRowCornerRadius
        let borderWidth = style == .appIcons
            ? PreviewArtwork.Metrics.appIconsSelectionBorderWidth
            : Appearance.highlightBorderWidth
        return AnimatedSelectionChrome(
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            fillColor: Appearance.highlightFocusedBackgroundColor,
            borderColor: Appearance.highlightFocusedBorderColor)
    }

    private func defaultFocusedIndex(for style: AppearanceStylePreference) -> Int {
        let count = PreviewArtwork.demoItems.count
        guard count > 0 else { return 0 }
        guard style == .appIcons else { return 0 }
        return min(1, count - 1)
    }

    private func setPauseButtonHovered(_ hovered: Bool) {
        isPauseButtonHovered = hovered
        refreshColors()
    }

    private func refreshPauseButtonState() {
        let isPaused = selectionContainer?.isManuallyPaused ?? false
        (pauseButton.infoCircle as? AppearanceLivePreviewPauseGlyphView)?.symbol = isPaused ? .play : .pause
        let label = isPaused ? Self.resumeAccessibilityLabel : Self.pauseAccessibilityLabel
        pauseButton.setAccessibilityLabel(label)
        pauseButton.toolTip = label
    }

    private func refreshColors() {
        let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        pauseButton.layer?.backgroundColor = (isPauseButtonHovered
            ? PreviewArtwork.Palette.pauseHoverFill
            : PreviewArtwork.Palette.pauseFill).cgColor
        pauseButton.layer?.borderColor = PreviewArtwork.Palette.pauseBorder
            .withAlphaComponent(increaseContrast ? 0.28 : 0.12)
            .cgColor
    }
}

private final class AppearanceLivePreviewPauseGlyphView: NSView {
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
        let size = AppearanceLivePreviewArtwork.Metrics.pauseButtonGlyphSize
        return NSSize(width: size, height: size)
    }

    init(symbol: Symbol) {
        self.symbol = symbol
        let size = AppearanceLivePreviewArtwork.Metrics.pauseButtonGlyphSize
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: size, height: size)))
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func draw(_ dirtyRect: NSRect) {
        AppearanceLivePreviewArtwork.Palette.pauseGlyph.setFill()
        guard symbol == .pause else {
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
