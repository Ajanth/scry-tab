import Cocoa

private typealias PreviewArtwork = AppearanceLivePreviewArtwork

final class AppearanceLivePreviewView: NSView {
    static let pauseAccessibilityLabel = NSLocalizedString("Pause preview animation", comment: "")
    static let resumeAccessibilityLabel = NSLocalizedString("Resume preview animation", comment: "")
    static let previewAccessibilityLabel = NSLocalizedString("Preview of the selected appearance style", comment: "")

    private let wallpaperView = PreviewArtwork.WallpaperView()
    private var switcherView: AnimatedSwitcherPresentationView?
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
        switcherView?.update(style: currentStyle, items: PreviewArtwork.demoPresentationItems())
        refreshColors()
    }

    override func accessibilityChildren() -> [Any]? {
        [pauseButton]
    }

    override func isAccessibilityElement() -> Bool { true }

    func updateStyle(_ style: AppearanceStylePreference) {
        currentStyle = style
        switcherView?.update(style: style, items: PreviewArtwork.demoPresentationItems())
        refreshColors()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel(Self.previewAccessibilityLabel)
        configureWallpaper()
        configureContainer(for: currentStyle)
        configurePauseButton()
        activateConstraints()
        switcherView?.onPauseStateChange = { [weak self] in self?.refreshPauseButtonState() }
        refreshColors()
    }

    private func configureWallpaper() {
        addSubview(wallpaperView)
        wallpaperView.addSubview(pauseButton)
    }

    private func configureContainer(for style: AppearanceStylePreference) {
        let view = AnimatedSwitcherPresentationView(
            style: style,
            items: PreviewArtwork.demoPresentationItems(),
            advanceInterval: AppearanceLivePreviewResolver.advanceInterval,
            maximumWidthRatio: 0.9,
            maximumHeightRatio: 0.9,
            shouldAdvance: { !SwitcherSession.isActive })
        wallpaperView.addSubview(view, positioned: .below, relativeTo: pauseButton)
        switcherView = view
    }

    private func configurePauseButton() {
        pauseButton.wantsLayer = true
        pauseButton.layer?.cornerRadius = PreviewArtwork.Metrics.pauseButtonDiameter / 2
        pauseButton.layer?.borderWidth = 1
        pauseButton.setAccessibilityRole(.button)
        pauseButton.onClick = { [weak self] _, _ in self?.switcherView?.togglePause() }
        pauseButton.onAccessibilityPress = { [weak self] in
            guard let self else { return false }
            self.switcherView?.togglePause()
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
        guard let switcherView else { return }
        NSLayoutConstraint.activate([
            wallpaperView.leadingAnchor.constraint(equalTo: leadingAnchor),
            wallpaperView.trailingAnchor.constraint(equalTo: trailingAnchor),
            wallpaperView.topAnchor.constraint(equalTo: topAnchor),
            wallpaperView.heightAnchor.constraint(equalTo: wallpaperView.widthAnchor,
                                                  multiplier: 1 / PreviewArtwork.Metrics.wallpaperAspectRatio),
            wallpaperView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            switcherView.leadingAnchor.constraint(equalTo: wallpaperView.leadingAnchor),
            switcherView.trailingAnchor.constraint(equalTo: wallpaperView.trailingAnchor),
            switcherView.topAnchor.constraint(equalTo: wallpaperView.topAnchor),
            switcherView.bottomAnchor.constraint(equalTo: wallpaperView.bottomAnchor),
            pauseButton.topAnchor.constraint(equalTo: wallpaperView.topAnchor,
                                             constant: PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.trailingAnchor.constraint(equalTo: wallpaperView.trailingAnchor,
                                                  constant: -PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.widthAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
            pauseButton.heightAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
        ])
    }

    private func setPauseButtonHovered(_ hovered: Bool) {
        isPauseButtonHovered = hovered
        refreshColors()
    }

    private func refreshPauseButtonState() {
        let isPaused = switcherView?.isManuallyPaused ?? false
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
