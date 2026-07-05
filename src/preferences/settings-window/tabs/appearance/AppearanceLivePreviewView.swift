import Cocoa

private typealias PreviewArtwork = AppearanceLivePreviewArtwork

final class AppearanceLivePreviewView: NSView {
    static let pauseAccessibilityLabel = NSLocalizedString("Pause preview animation", comment: "")
    static let resumeAccessibilityLabel = NSLocalizedString("Resume preview animation", comment: "")
    static let previewAccessibilityLabel = NSLocalizedString("Preview of the selected appearance style", comment: "")

    private let wallpaperView = PreviewArtwork.WallpaperView()
    private let switcherView = NSView()
    private let stack = NSStackView()
    private let selectionView = NSView()
    private let playbackController = AppearanceLivePreviewPlaybackController()
    private let pauseButton: ClickHoverImageView = {
        let glyph = AppearanceLivePreviewPlaybackGlyphView(symbol: .pause)
        glyph.translatesAutoresizingMaskIntoConstraints = false
        let button = ClickHoverImageView(infoCircle: glyph)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var items = [PreviewArtwork.ItemView]()
    private var selectionConstraints = [NSLayoutConstraint]()
    private var switcherSizeConstraints = [NSLayoutConstraint]()
    private var stackCenterYConstraint: NSLayoutConstraint?
    private var focusedIndex = 0
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
        configurePlayback()
        refreshColors()
        playbackController.start()
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
        let centerYConstraint = stack.centerYAnchor.constraint(equalTo: switcherView.centerYAnchor)
        stackCenterYConstraint = centerYConstraint
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: switcherView.centerXAnchor),
            centerYConstraint,
        ])
    }

    private func configurePauseButton() {
        pauseButton.wantsLayer = true
        pauseButton.layer?.cornerRadius = PreviewArtwork.Metrics.pauseButtonDiameter / 2
        pauseButton.layer?.borderWidth = 1
        pauseButton.setAccessibilityRole(.button)
        pauseButton.onClick = { [weak self] _, _ in self?.playbackController.toggleManualPause() }
        pauseButton.onAccessibilityPress = { [weak self] in
            guard let self else { return false }
            self.playbackController.toggleManualPause()
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
            wallpaperView.topAnchor.constraint(equalTo: topAnchor),
            wallpaperView.heightAnchor.constraint(equalTo: wallpaperView.widthAnchor,
                                                  multiplier: 1 / PreviewArtwork.Metrics.wallpaperAspectRatio),
            wallpaperView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            switcherView.centerXAnchor.constraint(equalTo: wallpaperView.centerXAnchor),
            switcherView.centerYAnchor.constraint(equalTo: wallpaperView.centerYAnchor),
            pauseButton.topAnchor.constraint(equalTo: wallpaperView.topAnchor,
                                             constant: PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.trailingAnchor.constraint(equalTo: wallpaperView.trailingAnchor,
                                                  constant: -PreviewArtwork.Metrics.pauseButtonInset),
            pauseButton.widthAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
            pauseButton.heightAnchor.constraint(equalToConstant: PreviewArtwork.Metrics.pauseButtonDiameter),
        ])
    }

    private func configurePlayback() {
        playbackController.isWindowVisible = { [weak self] in self?.window?.isVisible ?? false }
        playbackController.onAdvance = { [weak self] in self?.advanceSelection() }
        playbackController.onPauseStateRefresh = { [weak self] in self?.refreshPauseButtonState() }
        playbackController.onAccessibilityDisplayOptionsChanged = { [weak self] in self?.refreshColors() }
    }

    private func rebuildItems(for style: AppearanceStylePreference) {
        NSLayoutConstraint.deactivate(selectionConstraints)
        selectionConstraints.removeAll(keepingCapacity: true)
        selectionView.isHidden = true
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        items.removeAll(keepingCapacity: true)
        configureStack(for: style)
        configureSwitcherSize(for: style)
        PreviewArtwork.demoItems.forEach { item in
            let resolvedInfo = AppDisplayInfo.resolve(bundleId: item.bundleId)
            let info = AppDisplayInfo(name: item.displayName, icon: resolvedInfo.icon)
            let view: PreviewArtwork.ItemView
            if style == .appIcons {
                view = PreviewArtwork.AppIconTileView(info)
            } else {
                view = PreviewArtwork.TitlesRowView(info, statusSymbols: item.statusSymbols)
            }
            items.append(view)
            stack.addArrangedSubview(view)
        }
        focusedIndex = defaultFocusedIndex(for: style, count: items.count)
        updateSelection()
    }

    private func configureStack(for style: AppearanceStylePreference) {
        stack.orientation = style == .appIcons ? .horizontal : .vertical
        stack.spacing = style == .appIcons
            ? PreviewArtwork.Metrics.appIconsTileSpacing
            : PreviewArtwork.Metrics.titlesRowSpacing
        stack.alignment = style == .appIcons ? .centerY : .centerX
        stackCenterYConstraint?.constant = style == .appIcons
            ? PreviewArtwork.Metrics.appIconsContentVerticalOffset
            : 0
    }

    private func configureSwitcherSize(for style: AppearanceStylePreference) {
        NSLayoutConstraint.deactivate(switcherSizeConstraints)
        let width = style == .appIcons
            ? PreviewArtwork.Metrics.appIconsSwitcherWidth
            : PreviewArtwork.Metrics.titlesSwitcherWidth
        let height = style == .appIcons
            ? PreviewArtwork.Metrics.appIconsSwitcherHeight
            : PreviewArtwork.Metrics.titlesSwitcherHeight
        switcherSizeConstraints = [
            switcherView.widthAnchor.constraint(equalToConstant: width),
            switcherView.heightAnchor.constraint(equalToConstant: height),
        ]
        NSLayoutConstraint.activate(switcherSizeConstraints)
    }

    private func defaultFocusedIndex(for style: AppearanceStylePreference, count: Int) -> Int {
        guard count > 0 else { return 0 }
        guard style == .appIcons else { return 0 }
        return min(1, count - 1)
    }

    private func advanceSelection() {
        focusedIndex = AppearanceLivePreviewResolver.nextFocusedIndex(current: focusedIndex, count: items.count)
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
        caTransaction {
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

    private func setPauseButtonHovered(_ hovered: Bool) {
        isPauseButtonHovered = hovered
        refreshColors()
    }

    private func refreshPauseButtonState() {
        let isPaused = playbackController.isManuallyPaused
        (pauseButton.infoCircle as? AppearanceLivePreviewPlaybackGlyphView)?.symbol = isPaused ? .play : .pause
        let label = isPaused ? Self.resumeAccessibilityLabel : Self.pauseAccessibilityLabel
        pauseButton.setAccessibilityLabel(label)
        pauseButton.toolTip = label
    }

    private func refreshColors() {
        let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        switcherView.layer?.cornerRadius = PreviewArtwork.Metrics.switcherCornerRadius
        switcherView.layer?.backgroundColor = PreviewArtwork.Palette.switcherFill.cgColor
        switcherView.layer?.borderColor = PreviewArtwork.Palette.switcherBorder
            .withAlphaComponent(increaseContrast ? 0.34 : 0.2)
            .cgColor
        switcherView.layer?.borderWidth = PreviewArtwork.Metrics.switcherBorderWidth
        let selectionRadius = currentStyle == .appIcons
            ? PreviewArtwork.Metrics.appIconsSelectionCornerRadius
            : PreviewArtwork.Metrics.titlesRowCornerRadius
        selectionView.layer?.cornerRadius = selectionRadius
        selectionView.layer?.backgroundColor = Appearance.highlightFocusedBackgroundColor.cgColor
        selectionView.layer?.borderColor = Appearance.highlightFocusedBorderColor.cgColor
        selectionView.layer?.borderWidth = currentStyle == .appIcons
            ? PreviewArtwork.Metrics.appIconsSelectionBorderWidth
            : Appearance.highlightBorderWidth
        pauseButton.layer?.backgroundColor = (isPauseButtonHovered
            ? PreviewArtwork.Palette.pauseHoverFill
            : PreviewArtwork.Palette.pauseFill).cgColor
        pauseButton.layer?.borderColor = PreviewArtwork.Palette.pauseBorder
            .withAlphaComponent(increaseContrast ? 0.28 : 0.12)
            .cgColor
    }
}
