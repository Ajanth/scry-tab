import Cocoa

final class AppearancePreviewSwitcherView: NSView {
    private let panelView = AppearancePreviewPanelView()
    private let highlightView = AppearancePreviewHighlightView()
    private let playbackController: AnimatedSelectionPlaybackController
    private var model: AppearancePreviewModel
    private var tileViews = [AppearancePreviewTileView]()

    var onPauseStateChange: (() -> Void)?
    var isManuallyPaused: Bool { playbackController.isManuallyPaused }

    init(appearance: AppearancePreviewAppearanceSnapshot,
         items: [AppearancePreviewItem],
         advanceInterval: TimeInterval,
         startsPaused: Bool) {
        self.model = AppearancePreviewModel(
            appearance: appearance,
            items: items)
        self.playbackController = AnimatedSelectionPlaybackController(
            advanceInterval: advanceInterval,
            startsPaused: startsPaused)
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        playbackController.start()
        applyCurrentScene()
    }

    override func layout() {
        super.layout()
        applyCurrentScene()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyCurrentScene()
    }

    func update(appearance: AppearancePreviewAppearanceSnapshot,
                items: [AppearancePreviewItem]) {
        model = AppearancePreviewModel(
            appearance: appearance,
            items: items)
        synchronizeTiles()
        applyCurrentScene()
    }

    func togglePause() {
        playbackController.toggleManualPause()
    }

    func setPlaybackPaused(_ paused: Bool) {
        playbackController.setManuallyPaused(paused)
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(highlightView)
        addSubview(panelView)
        synchronizeTiles()
        configurePlayback()
    }

    private func synchronizeTiles() {
        guard tileViews.count != model.items.count else {
            zip(tileViews, model.items).forEach { $0.configure(item: $1) }
            return
        }
        tileViews.forEach { $0.removeFromSuperview() }
        tileViews = model.items.map { item in
            let view = AppearancePreviewTileView(item: item)
            panelView.addSubview(view)
            return view
        }
    }

    private func configurePlayback() {
        playbackController.isWindowVisible = { [weak self] in self?.isVisibleInHierarchy ?? false }
        playbackController.onAdvance = { [weak self] in self?.advanceSelection() }
        playbackController.onPauseStateRefresh = { [weak self] in self?.onPauseStateChange?() }
        playbackController.onAccessibilityDisplayOptionsChanged = { [weak self] in self?.applyCurrentScene() }
    }

    private func advanceSelection() {
        model = model.advancingFocus()
        applyCurrentScene()
    }

    private func applyCurrentScene() {
        let layoutDirection: AppearancePreviewLayoutDirection =
            userInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        let backingScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let layout = AppearancePreviewLayoutResolver.resolve(
            style: model.appearance.style,
            size: model.appearance.size,
            itemStatusCounts: model.items.map { $0.statusSymbols.count },
            focusedIndex: model.focusedIndex,
            hostSize: bounds.size,
            backingScale: backingScale,
            platform: currentPlatform(),
            layoutDirection: layoutDirection)
        guard layout != .empty else {
            highlightView.isHidden = true
            panelView.isHidden = true
            return
        }
        let isDark = model.appearance.isDark
        withoutLayerAnimations {
            panelView.isHidden = false
            panelView.frame = layout.panelFrame
            panelView.apply(
                visualStyle: layout.visualStyle,
                cornerRadius: layout.panelCornerRadius,
                contentScale: layout.contentScale,
                isDark: isDark)
            highlightView.frame = layout.selectionFrame
            highlightView.apply(
                cornerRadius: layout.selectionCornerRadius,
                borderWidth: layout.selectionBorderWidth)
            highlightView.isHidden = false
            zip(tileViews, layout.tileLayouts).forEach { tile, tileLayout in
                tile.apply(
                    layout: tileLayout,
                    style: model.appearance.style,
                    contentScale: layout.contentScale,
                    backingScale: backingScale,
                    fontWeight: layout.visualStyle.fontWeight,
                    fontPointSize: layout.visualStyle.fontPointSize,
                    statusFontPointSize: layout.visualStyle.statusFontPointSize,
                    statusIconCellWidth: layout.visualStyle.statusIconCellWidth,
                    isDark: isDark,
                    layoutDirection: layoutDirection)
            }
        }
    }

    private func currentPlatform() -> AppearancePreviewPlatform {
        if #available(macOS 26.0, *) {
            return .macOS26(
                supportsClearGlass: AppearancePreviewLiquidGlassView.canUsePrivateLiquidGlassLook())
        }
        return .legacy
    }

    private var isVisibleInHierarchy: Bool {
        guard window?.isVisible == true else { return false }
        var candidate: NSView? = self
        while let view = candidate {
            guard !view.isHidden else { return false }
            candidate = view.superview
        }
        return true
    }

    private func withoutLayerAnimations(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}

private enum AppearancePreviewPalette {
    static func fontColor(isDark: Bool) -> NSColor {
        isDark ? NSColor.white.withAlphaComponent(0.85) : NSColor.black.withAlphaComponent(0.8)
    }

    static let imageShadowColor = NSColor.gray.withAlphaComponent(0.4)
    static let focusedBackgroundColor = NSColor.systemAccentColor.withAlphaComponent(0.2)
    static let focusedBorderColor = NSColor.systemAccentColor
}

private class AppearancePreviewFlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class AppearancePreviewPanelView: AppearancePreviewFlippedView {
    private var effectView: NSView?
    private var materialKind: AppearancePreviewMaterialKind?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func layout() {
        super.layout()
        effectView?.frame = bounds
        updateShadowPath()
    }

    func apply(visualStyle: AppearancePreviewVisualStyle,
               cornerRadius: CGFloat,
               contentScale: CGFloat,
               isDark: Bool) {
        replaceEffectViewIfNeeded(visualStyle.materialKind)
        appearance = NSAppearance(named: isDark ? .vibrantDark : .vibrantLight)
        effectView?.frame = bounds
        if let frosted = effectView as? AppearancePreviewFrostedGlassView {
            frosted.apply(
                material: .menu,
                cornerRadius: cornerRadius)
        }
        if #available(macOS 26.0, *),
           let liquidGlass = effectView as? AppearancePreviewLiquidGlassView {
            liquidGlass.apply(cornerRadius: cornerRadius)
        }
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = visualStyle.panelBorderWidth
        layer?.borderColor = NSColor.clear.cgColor
        applyShadow(
            enabled: visualStyle.usesPanelShadow,
            contentScale: contentScale)
    }

    private func replaceEffectViewIfNeeded(_ kind: AppearancePreviewMaterialKind) {
        guard materialKind != kind else { return }
        effectView?.removeFromSuperview()
        let view = makeEffectView(kind)
        if let firstSubview = subviews.first {
            addSubview(view, positioned: .below, relativeTo: firstSubview)
        } else {
            addSubview(view)
        }
        effectView = view
        materialKind = kind
    }

    private func makeEffectView(_ kind: AppearancePreviewMaterialKind) -> NSView {
        if #available(macOS 26.0, *) {
            switch kind {
                case .liquidGlassClear:
                    return AppearancePreviewLiquidGlassView(clear: true)
                case .liquidGlassRegular:
                    return AppearancePreviewLiquidGlassView(clear: false)
                case .frosted:
                    break
            }
        }
        return AppearancePreviewFrostedGlassView()
    }

    private func applyShadow(enabled: Bool, contentScale: CGFloat) {
        guard enabled else {
            layer?.shadowOpacity = 0
            layer?.shadowPath = nil
            return
        }
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = max(4, 12 * contentScale)
        layer?.shadowOffset = CGSize(width: 0, height: -3 * contentScale)
        updateShadowPath()
    }

    private func updateShadowPath() {
        guard layer?.shadowOpacity ?? 0 > 0 else { return }
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: layer?.cornerRadius ?? 0,
            cornerHeight: layer?.cornerRadius ?? 0,
            transform: nil)
    }
}

private final class AppearancePreviewFrostedGlassView: NSVisualEffectView {
    private var appliedCornerRadius = CGFloat(-1)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func apply(material: NSVisualEffectView.Material,
               cornerRadius: CGFloat) {
        self.material = material
        guard appliedCornerRadius != cornerRadius else { return }
        appliedCornerRadius = cornerRadius
        updateRoundedCorners(cornerRadius)
    }

    private func updateRoundedCorners(_ cornerRadius: CGFloat) {
        guard cornerRadius > 0 else {
            maskImage = nil
            return
        }
        let edgeLength = 2 * cornerRadius + 1
        let mask = NSImage(
            size: NSSize(width: edgeLength, height: edgeLength),
            flipped: false) { rect in
                NSColor.black.set()
                NSBezierPath(
                    roundedRect: rect,
                    xRadius: cornerRadius,
                    yRadius: cornerRadius).fill()
                return true
            }
        mask.capInsets = NSEdgeInsets(
            top: cornerRadius,
            left: cornerRadius,
            bottom: cornerRadius,
            right: cornerRadius)
        mask.resizingMode = .stretch
        maskImage = mask
    }
}

@available(macOS 26.0, *)
private final class AppearancePreviewLiquidGlassView: NSGlassEffectView {
    private typealias SetVariantType = @convention(c) (AnyObject, Selector, Int) -> Void
    private static let setVariantSelector = NSSelectorFromString("set_variant:")
    private static let canUsePrivateLiquidGlassLookCached: Bool = {
        class_getInstanceMethod(
            object_getClass(NSGlassEffectView()),
            setVariantSelector) != nil
    }()

    static func canUsePrivateLiquidGlassLook() -> Bool {
        canUsePrivateLiquidGlassLookCached
    }

    init(clear: Bool) {
        super.init(frame: .zero)
        if clear {
            style = .clear
            safeSetVariant(3)
        } else {
            style = .regular
        }
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func apply(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    private func safeSetVariant(_ value: Int) {
        guard let method = class_getInstanceMethod(
            object_getClass(self),
            Self.setVariantSelector) else { return }
        let implementation = method_getImplementation(method)
        let call = unsafeBitCast(implementation, to: SetVariantType.self)
        call(self, Self.setVariantSelector, value)
    }
}

private final class AppearancePreviewHighlightView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func apply(cornerRadius: CGFloat,
               borderWidth: CGFloat) {
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = borderWidth
        layer?.backgroundColor = DesignSystem.resolvedCGColor(
            AppearancePreviewPalette.focusedBackgroundColor,
            in: self)
        layer?.borderColor = DesignSystem.resolvedCGColor(
            AppearancePreviewPalette.focusedBorderColor,
            in: self)
    }
}

private final class AppearancePreviewTileView: AppearancePreviewFlippedView {
    private static let nullActions: [String: any CAAction] = [
        "position": NSNull(),
        "bounds": NSNull(),
        "contents": NSNull(),
        "hidden": NSNull(),
        "opacity": NSNull(),
        "transform": NSNull(),
    ]

    private let iconLayer = CALayer()
    private let titleLabel = NSTextField(labelWithString: "")
    private let statusView = AppearancePreviewStatusView()
    private var icon: NSImage
    private var renderedPixelWidth = 0

    init(item: AppearancePreviewItem) {
        self.icon = item.icon
        super.init(frame: .zero)
        setupView()
        configure(item: item)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func configure(item: AppearancePreviewItem) {
        if icon !== item.icon {
            icon = item.icon
            renderedPixelWidth = 0
        }
        titleLabel.stringValue = item.title
        statusView.symbols = item.statusSymbols
    }

    func apply(layout: AppearancePreviewTileLayout,
               style: AppearancePreviewStyle,
               contentScale: CGFloat,
               backingScale: CGFloat,
               fontWeight: AppearancePreviewFontWeight,
               fontPointSize: CGFloat,
               statusFontPointSize: CGFloat,
               statusIconCellWidth: CGFloat,
               isDark: Bool,
               layoutDirection: AppearancePreviewLayoutDirection) {
        frame = layout.frame
        iconLayer.frame = layout.iconFrame
        renderIconIfNeeded(
            pointWidth: layout.iconFrame.width,
            backingScale: backingScale)
        applyIconShadow(contentScale: contentScale)
        titleLabel.frame = layout.labelFrame
        titleLabel.isHidden = !layout.showsLabel
        titleLabel.alignment = style == .appIcons ? .center : .natural
        titleLabel.font = NSFont.systemFont(
            ofSize: fontPointSize * contentScale,
            weight: nsFontWeight(fontWeight))
        titleLabel.textColor = AppearancePreviewPalette.fontColor(isDark: isDark)
        statusView.frame = layout.statusFrame
        statusView.isHidden = style == .appIcons || layout.statusFrame.isEmpty
        statusView.apply(
            contentScale: contentScale,
            fontPointSize: statusFontPointSize,
            iconCellWidth: statusIconCellWidth,
            color: AppearancePreviewPalette.fontColor(isDark: isDark),
            layoutDirection: layoutDirection)
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = false
        iconLayer.contentsGravity = .resize
        iconLayer.magnificationFilter = .trilinear
        iconLayer.minificationFilter = .trilinear
        iconLayer.actions = Self.nullActions
        layer?.addSublayer(iconLayer)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true
        titleLabel.allowsDefaultTighteningForTruncation = false
        titleLabel.wantsLayer = true
        titleLabel.layer?.actions = Self.nullActions
        addSubview(titleLabel)
        addSubview(statusView)
    }

    private func renderIconIfNeeded(pointWidth: CGFloat,
                                    backingScale: CGFloat) {
        let pixelWidth = max(1, Int((pointWidth * backingScale).rounded()))
        guard renderedPixelWidth != pixelWidth else { return }
        renderedPixelWidth = pixelWidth
        iconLayer.contentsScale = backingScale
        iconLayer.contents = AppearancePreviewIconRasterizer.rasterize(
            icon,
            pixelWidth: pixelWidth) ?? icon
    }

    private func applyIconShadow(contentScale: CGFloat) {
        iconLayer.shadowColor = DesignSystem.resolvedCGColor(
            AppearancePreviewPalette.imageShadowColor,
            in: self)
        iconLayer.shadowOpacity = 1
        iconLayer.shadowOffset = NSSize(
            width: 0.1 * contentScale,
            height: contentScale)
        iconLayer.shadowRadius = 2 * contentScale
    }

    private func nsFontWeight(_ weight: AppearancePreviewFontWeight) -> NSFont.Weight {
        switch weight {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
        }
    }
}

private enum AppearancePreviewIconRasterizer {
    static func rasterize(_ icon: NSImage,
                          pixelWidth: Int) -> CGImage? {
        let finalWidth = CGFloat(pixelWidth)
        let referencePadding = appIconPadding
        let padding = referencePadding
            * (finalWidth / max(1, 1024 - referencePadding * 2))
        let sourceWidth = finalWidth + padding * 2
        var proposedRect = CGRect(
            origin: .zero,
            size: NSSize(width: sourceWidth, height: sourceWidth))
        let hints: [NSImageRep.HintKey: NSNumber] = [
            .interpolation: NSNumber(value: NSImageInterpolation.high.rawValue),
        ]
        guard let source = icon.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: hints) else { return nil }
        let scaledPadding = padding * (CGFloat(source.width) / sourceWidth)
        let cropRect = CGRect(
            x: scaledPadding,
            y: scaledPadding,
            width: CGFloat(source.width) - scaledPadding * 2,
            height: CGFloat(source.height) - scaledPadding * 2).integral
        guard cropRect.width > 0,
              cropRect.height > 0,
              let cropped = source.cropping(to: cropRect),
              let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelWidth,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                    .union(.byteOrder32Little).rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(
            cropped,
            in: CGRect(
                origin: .zero,
                size: CGSize(width: pixelWidth, height: pixelWidth)))
        return context.makeImage()
    }

    private static var appIconPadding: CGFloat {
        if #available(macOS 26.0, *) { return 84 }
        if #available(macOS 11.0, *) { return 24 }
        return 0
    }
}

private final class AppearancePreviewStatusView: NSView {
    private static let baseSpacing = CGFloat(2)

    var symbols = [String]() {
        didSet { needsDisplay = true }
    }

    private var contentScale = CGFloat(1)
    private var fontPointSize = CGFloat(12)
    private var iconCellWidth = CGFloat(13.201171875)
    private var color = NSColor.white
    private var layoutDirection = AppearancePreviewLayoutDirection.leftToRight

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    func apply(contentScale: CGFloat,
               fontPointSize: CGFloat,
               iconCellWidth: CGFloat,
               color: NSColor,
               layoutDirection: AppearancePreviewLayoutDirection) {
        self.contentScale = contentScale
        self.fontPointSize = fontPointSize
        self.iconCellWidth = iconCellWidth
        self.color = color
        self.layoutDirection = layoutDirection
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !symbols.isEmpty else { return }
        let fontSize = fontPointSize * contentScale
        let font = NSFont(name: "SF Pro Text", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.85
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let displayedSymbols = AppearancePreviewStateResolver.orderedStatusSymbols(
            symbols,
            layoutDirection: layoutDirection)
        displayedSymbols.enumerated().forEach { index, symbol in
            let value = NSAttributedString(
                string: symbol,
                attributes: attributes)
            let size = value.size()
            let slotWidth = iconCellWidth * contentScale
            let slotX = CGFloat(index)
                * (slotWidth + Self.baseSpacing * contentScale)
            value.draw(
                at: pixelAligned(
                    NSPoint(
                        x: slotX + (slotWidth - size.width) / 2,
                        y: (bounds.height - size.height) / 2)))
        }
    }

    private func pixelAligned(_ point: NSPoint) -> NSPoint {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return NSPoint(
            x: (point.x * scale).rounded() / scale,
            y: (point.y * scale).rounded() / scale)
    }
}
