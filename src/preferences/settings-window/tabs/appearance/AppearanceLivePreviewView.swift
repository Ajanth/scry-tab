import Cocoa

private typealias PreviewArtwork = AppearanceLivePreviewArtwork

final class AppearanceLivePreviewView: NSView {
    static let pauseAccessibilityLabel = NSLocalizedString("Pause preview animation", comment: "")
    static let resumeAccessibilityLabel = NSLocalizedString("Resume preview animation", comment: "")
    static let previewAccessibilityLabel = NSLocalizedString("Preview of the selected appearance style", comment: "")
    private static let previewItems = PreviewArtwork.demoItems.map { item in
        var statusSymbols = [String]()
        if item.isFullscreen { statusSymbols.append(AppearancePreviewStatusSymbols.fullscreen) }
        statusSymbols.append(AppearancePreviewStatusSymbols.space(item.spaceNumber))
        return AppearancePreviewItem(
            title: item.displayName,
            icon: previewIcon(bundleId: item.bundleId),
            statusSymbols: statusSymbols)
    }

    private let wallpaperView = PreviewArtwork.WallpaperView()
    private var switcherView: AppearancePreviewSwitcherView?
    private let startsPaused: Bool
    private let showsPauseButton: Bool
    private let pauseButton: ClickHoverImageView = {
        let glyph = AppearanceLivePreviewPauseGlyphView(symbol: .pause)
        glyph.translatesAutoresizingMaskIntoConstraints = false
        let button = ClickHoverImageView(infoCircle: glyph)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var currentAppearance: AppearancePreviewAppearanceSnapshot
    private var isPauseButtonHovered = false

    init(style: AppearanceStylePreference = .appIcons,
         size: AppearanceSizePreference = .medium,
         theme: AppearanceThemePreference = .system,
         startsPaused: Bool = false,
         showsPauseButton: Bool = true) {
        self.currentAppearance = AppearancePreviewAppearanceSnapshot(
            style: style.previewStyle,
            size: size.previewSize,
            theme: theme.previewTheme,
            systemIsDark: false)
        self.startsPaused = startsPaused
        self.showsPauseButton = showsPauseButton
        super.init(frame: .zero)
        resolveSystemTheme()
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
        resolveSystemTheme()
        refreshSwitcher()
        refreshColors()
    }

    override func accessibilityChildren() -> [Any]? {
        showsPauseButton ? [pauseButton] : []
    }

    override func isAccessibilityElement() -> Bool { true }

    func updateStyle(_ style: AppearanceStylePreference) {
        currentAppearance = currentAppearance.updating(style: style.previewStyle)
        refreshSwitcher()
        refreshColors()
    }

    func updateAppearance(style: AppearanceStylePreference,
                          size: AppearanceSizePreference,
                          theme: AppearanceThemePreference) {
        currentAppearance = currentAppearance.updating(
            style: style.previewStyle,
            size: size.previewSize,
            theme: theme.previewTheme)
        resolveSystemTheme()
        refreshSwitcher()
        refreshColors()
    }

    func updateAppearance(size: AppearanceSizePreference,
                          theme: AppearanceThemePreference) {
        currentAppearance = currentAppearance.updating(
            size: size.previewSize,
            theme: theme.previewTheme)
        resolveSystemTheme()
        refreshSwitcher()
        refreshColors()
    }

    func setAnimationPaused(_ paused: Bool) {
        switcherView?.setPlaybackPaused(paused)
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityLabel(Self.previewAccessibilityLabel)
        configureWallpaper()
        configureContainer()
        configurePauseButton()
        activateConstraints()
        switcherView?.onPauseStateChange = { [weak self] in self?.refreshPauseButtonState() }
        refreshColors()
    }

    private func configureWallpaper() {
        addSubview(wallpaperView)
        if showsPauseButton { wallpaperView.addSubview(pauseButton) }
    }

    private func configureContainer() {
        let view = AppearancePreviewSwitcherView(
            appearance: currentAppearance,
            items: makePreviewItems(),
            advanceInterval: AppearanceLivePreviewResolver.advanceInterval,
            startsPaused: startsPaused)
        if showsPauseButton {
            wallpaperView.addSubview(view, positioned: .below, relativeTo: pauseButton)
        } else {
            wallpaperView.addSubview(view)
        }
        switcherView = view
    }

    private func resolveSystemTheme() {
        currentAppearance = currentAppearance.updating(
            systemIsDark: DesignSystem.isDark(effectiveAppearance))
    }

    private func refreshSwitcher() {
        switcherView?.update(
            appearance: currentAppearance,
            items: makePreviewItems())
    }

    private func makePreviewItems() -> [AppearancePreviewItem] {
        Self.previewItems
    }

    private static func previewIcon(bundleId: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return NSWorkspace.shared.icon(forFileType: "app")
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func configurePauseButton() {
        guard showsPauseButton else { return }
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
        var constraints = [
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
        ]
        if showsPauseButton {
            constraints += [
            pauseButton.topAnchor.constraint(equalTo: wallpaperView.topAnchor,
                                             constant: PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.trailingAnchor.constraint(equalTo: wallpaperView.trailingAnchor,
                                                  constant: -PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.widthAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
            pauseButton.heightAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func setPauseButtonHovered(_ hovered: Bool) {
        isPauseButtonHovered = hovered
        refreshColors()
    }

    private func refreshPauseButtonState() {
        guard showsPauseButton else { return }
        let isPaused = switcherView?.isManuallyPaused ?? false
        (pauseButton.infoCircle as? AppearanceLivePreviewPauseGlyphView)?.symbol = isPaused ? .play : .pause
        let label = isPaused ? Self.resumeAccessibilityLabel : Self.pauseAccessibilityLabel
        pauseButton.setAccessibilityLabel(label)
        pauseButton.toolTip = label
    }

    private func refreshColors() {
        guard showsPauseButton else { return }
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
