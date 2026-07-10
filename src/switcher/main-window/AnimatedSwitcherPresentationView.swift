import Cocoa

struct SwitcherPresentationItem {
    let title: String
    let icon: NSImage
    let isFullscreen: Bool
    let spaceNumber: Int
}

final class AnimatedSwitcherPresentationView: NSView {
    private let contentView = FlippedView()
    private let highlightView = FlippedView()
    private let highlightLayer = TileUnderLayer()
    private let playbackController: AnimatedSelectionPlaybackController
    private let maximumWidthRatio: CGFloat
    private let maximumHeightRatio: CGFloat
    private let shouldAdvance: () -> Bool
    private var backgroundView: NSView?
    private var tiles = [TileView]()
    private var items: [SwitcherPresentationItem]
    private var style: AppearanceStylePreference
    private var focusedIndex = 0
    private var lastLayoutSize = NSSize.zero

    var onPauseStateChange: (() -> Void)?
    var isManuallyPaused: Bool { playbackController.isManuallyPaused }

    init(style: AppearanceStylePreference,
         items: [SwitcherPresentationItem],
         advanceInterval: TimeInterval,
         maximumWidthRatio: CGFloat,
         maximumHeightRatio: CGFloat,
         shouldAdvance: @escaping () -> Bool) {
        self.style = style
        self.items = items
        self.maximumWidthRatio = maximumWidthRatio
        self.maximumHeightRatio = maximumHeightRatio
        self.shouldAdvance = shouldAdvance
        self.playbackController = AnimatedSelectionPlaybackController(advanceInterval: advanceInterval)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configureContentView()
        configurePlayback()
        rebuild()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        playbackController.start()
    }

    override func layout() {
        super.layout()
        guard bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size
        layoutSwitcher()
    }

    func update(style: AppearanceStylePreference, items: [SwitcherPresentationItem]) {
        self.style = style
        self.items = items
        rebuild()
    }

    func togglePause() {
        playbackController.toggleManualPause()
    }

    private func configureContentView() {
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = true
        highlightView.wantsLayer = true
        highlightView.layer?.addSublayer(highlightLayer)
        addSubview(contentView)
        contentView.addSubview(highlightView)
    }

    private func configurePlayback() {
        playbackController.isWindowVisible = { [weak self] in self?.window?.isVisible ?? false }
        playbackController.shouldAdvance = shouldAdvance
        playbackController.onAdvance = { [weak self] in self?.advanceSelection() }
        playbackController.onPauseStateRefresh = { [weak self] in self?.onPauseStateChange?() }
    }

    private func rebuild() {
        contentView.appearance = NSAppearance(named: Appearance.currentTheme == .dark ? .vibrantDark : .vibrantLight)
        tiles.forEach { $0.removeFromSuperview() }
        tiles = items.map { _ in TileView() }
        tiles.forEach { contentView.addSubview($0) }
        replaceBackgroundView()
        focusedIndex = style == .appIcons ? min(1, max(0, tiles.count - 1)) : 0
        lastLayoutSize = .zero
        needsLayout = true
    }

    private func replaceBackgroundView() {
        backgroundView?.removeFromSuperview()
        let view = makeAppropriateEffectView()
        if let frostedView = view as? FrostedGlassEffectView {
            frostedView.blendingMode = .withinWindow
        }
        contentView.addSubview(view, positioned: .below, relativeTo: highlightView)
        backgroundView = view
    }

    private func layoutSwitcher() {
        guard bounds.width > 0, bounds.height > 0, !tiles.isEmpty else { return }
        let availableSize = NSSize(width: bounds.width * maximumWidthRatio,
                                   height: bounds.height * maximumHeightRatio)
        let layout = style == .appIcons
            ? makeAppIconsLayout(availableSize)
            : makeTitlesLayout(availableSize)
        apply(layout)
    }

    private func makeAppIconsLayout(_ availableSize: NSSize) -> SwitcherPresentationLayout {
        let labelHeight = tiles[0].label.cell?.cellSize.height ?? Appearance.fontHeight
        let tileSize = NSSize(width: TileView.iconSize().width + Appearance.edgeInsetsSize * 2,
                              height: TileView.height(labelHeight))
        let rowWidth = Appearance.interCellPadding + CGFloat(tiles.count) * (tileSize.width + Appearance.interCellPadding)
        let rowHeight = tileSize.height + Appearance.interCellPadding * 2
        let panelSize = NSSize(width: rowWidth + Appearance.windowPadding * 2,
                               height: rowHeight + Appearance.windowPadding * 2 - Appearance.intraCellPadding - labelHeight)
        let bottomOrigin = Appearance.windowPadding - Appearance.intraCellPadding - labelHeight + Appearance.interCellPadding
        let tileY = panelSize.height - bottomOrigin - tileSize.height
        let origins = tiles.indices.map {
            NSPoint(x: Appearance.windowPadding + Appearance.interCellPadding + CGFloat($0) * (tileSize.width + Appearance.interCellPadding),
                    y: tileY)
        }
        return SwitcherPresentationLayout(panelSize: panelSize, tileSize: tileSize, rowWidth: rowWidth,
                                          origins: origins, availableSize: availableSize)
    }

    private func makeTitlesLayout(_ availableSize: NSSize) -> SwitcherPresentationLayout {
        let labelHeight = tiles[0].label.cell?.cellSize.height ?? Appearance.fontHeight
        let tileHeight = max(TileView.iconSize().height, labelHeight) + Appearance.edgeInsetsSize * 2
        let panelWidth = availableSize.width
        let rowWidth = max(0, panelWidth - Appearance.windowPadding * 2)
        let tileSize = NSSize(width: max(0, rowWidth - Appearance.interCellPadding * 2), height: tileHeight)
        let rowHeight = Appearance.interCellPadding + CGFloat(tiles.count) * (tileHeight + Appearance.interCellPadding)
        let panelSize = NSSize(width: panelWidth, height: rowHeight + Appearance.windowPadding * 2)
        let origins = tiles.indices.map {
            NSPoint(x: Appearance.windowPadding + Appearance.interCellPadding,
                    y: Appearance.windowPadding + Appearance.interCellPadding + CGFloat($0) * (tileHeight + Appearance.interCellPadding))
        }
        return SwitcherPresentationLayout(panelSize: panelSize, tileSize: tileSize, rowWidth: rowWidth,
                                          origins: origins, availableSize: availableSize)
    }

    private func apply(_ layout: SwitcherPresentationLayout) {
        let scale = AnimatedSelectionResolver.scaleToFit(
            contentSize: layout.panelSize,
            availableSize: layout.availableSize,
            maximumWidthRatio: 1,
            maximumHeightRatio: 1)
        if style == .appIcons {
            applyAppIconsLayout(layout, scale: scale)
            return
        }
        let frameSize = NSSize(width: layout.panelSize.width * scale, height: layout.panelSize.height * scale)
        contentView.frame = NSRect(x: bounds.midX - frameSize.width / 2,
                                   y: bounds.midY - frameSize.height / 2,
                                   width: frameSize.width,
                                   height: frameSize.height)
        contentView.bounds = NSRect(origin: .zero, size: layout.panelSize)
        backgroundView?.frame = contentView.bounds
        highlightView.frame = contentView.bounds
        highlightLayer.frame = highlightView.bounds
        tiles.enumerated().forEach { index, tile in
            tile.numberOfViewsInRow = tiles.count
            tile.indexInRow = index
            tile.isFirstInRow = index == 0
            tile.isLastInRow = index == tiles.count - 1
            tile.updatePresentationCell(title: items[index].title,
                                        icon: items[index].icon,
                                        frameSize: layout.tileSize,
                                        rowWidth: layout.rowWidth,
                                        isFullscreen: items[index].isFullscreen,
                                        spaceNumber: items[index].spaceNumber)
            tile.frame.origin = layout.origins[index]
        }
        updateSelection()
    }

    private func applyAppIconsLayout(_ layout: SwitcherPresentationLayout, scale: CGFloat) {
        let panelSize = pixelAligned(layout.panelSize.scaled(by: scale))
        contentView.frame = NSRect(x: pixelAligned(bounds.midX - panelSize.width / 2),
                                   y: pixelAligned(bounds.midY - panelSize.height / 2),
                                   width: pixelAligned(panelSize.width),
                                   height: pixelAligned(panelSize.height))
        contentView.bounds = NSRect(origin: .zero, size: contentView.frame.size)
        backgroundView?.frame = contentView.bounds
        applyBackgroundScale(scale)
        highlightView.frame = contentView.bounds
        highlightLayer.frame = highlightView.bounds
        tiles.enumerated().forEach { index, tile in
            tile.numberOfViewsInRow = tiles.count
            tile.indexInRow = index
            tile.isFirstInRow = index == 0
            tile.isLastInRow = index == tiles.count - 1
            tile.updatePresentationCell(title: items[index].title,
                                        icon: items[index].icon,
                                        frameSize: pixelAligned(layout.tileSize.scaled(by: scale)),
                                        rowWidth: layout.rowWidth * scale,
                                        isFullscreen: items[index].isFullscreen,
                                        spaceNumber: items[index].spaceNumber,
                                        scale: scale)
            tile.frame.origin = pixelAligned(layout.origins[index].scaled(by: scale))
        }
        updateSelection()
    }

    private func applyBackgroundScale(_ scale: CGFloat) {
        if let frostedView = backgroundView as? FrostedGlassEffectView {
            frostedView.updatePresentationScale(scale)
            return
        }
        if #available(macOS 26.0, *), let liquidGlassView = backgroundView as? LiquidGlassEffectView {
            liquidGlassView.updatePresentationScale(scale)
        }
    }

    private func pixelAligned(_ value: CGFloat) -> CGFloat {
        let backingScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return (value * backingScale).rounded() / backingScale
    }

    private func pixelAligned(_ size: NSSize) -> NSSize {
        NSSize(width: pixelAligned(size.width), height: pixelAligned(size.height))
    }

    private func pixelAligned(_ point: NSPoint) -> NSPoint {
        NSPoint(x: pixelAligned(point.x), y: pixelAligned(point.y))
    }

    private func advanceSelection() {
        focusedIndex = AnimatedSelectionResolver.nextFocusedIndex(current: focusedIndex, count: tiles.count)
        updateSelection()
    }

    private func updateSelection() {
        tiles.enumerated().forEach { $0.element.setPresentationFocused($0.offset == focusedIndex) }
        let focused = tiles.indices.contains(focusedIndex) ? tiles[focusedIndex] : nil
        highlightLayer.updateHighlight(focusedView: focused, hoveredView: nil)
    }
}

private struct SwitcherPresentationLayout {
    let panelSize: NSSize
    let tileSize: NSSize
    let rowWidth: CGFloat
    let origins: [NSPoint]
    let availableSize: NSSize
}

private extension NSSize {
    func scaled(by scale: CGFloat) -> NSSize {
        NSSize(width: width * scale, height: height * scale)
    }
}

private extension NSPoint {
    func scaled(by scale: CGFloat) -> NSPoint {
        NSPoint(x: x * scale, y: y * scale)
    }
}
