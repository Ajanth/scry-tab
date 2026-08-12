import AppKit
import QuartzCore

struct OnboardingTourDemoApp {
    let name: String
    let iconResourceName: String
    let symbolName: String
    let fallbackGlyph: String
    let color: NSColor
}

struct OnboardingTourDemoFocusSet {
    let name: String
    let symbolName: String
    let fallbackGlyph: String
    let color: NSColor
    let apps: [OnboardingTourDemoApp]
    let selectedIndex: Int
}

enum OnboardingTourDemoContent {
    static let focusSets = [
        OnboardingTourDemoFocusSet(
            name: NSLocalizedString("Entertainment", comment: "Onboarding demo Focus Set name"),
            symbolName: "play.rectangle.fill",
            fallbackGlyph: "▶",
            color: .systemPurple,
            apps: [
                OnboardingTourDemoApp(name: NSLocalizedString("Netflix", comment: "Onboarding demo app"), iconResourceName: "netflix", symbolName: "play.fill", fallbackGlyph: "N", color: .systemRed),
                OnboardingTourDemoApp(name: NSLocalizedString("Plex", comment: "Onboarding demo app"), iconResourceName: "plex", symbolName: "play.circle.fill", fallbackGlyph: "▶", color: .systemOrange),
                OnboardingTourDemoApp(name: NSLocalizedString("Chrome", comment: "Onboarding demo app"), iconResourceName: "chrome", symbolName: "globe", fallbackGlyph: "◎", color: .systemBlue),
            ],
            selectedIndex: 0),
        OnboardingTourDemoFocusSet(
            name: NSLocalizedString("Work", comment: "Onboarding demo Focus Set name"),
            symbolName: "briefcase.fill",
            fallbackGlyph: "◆",
            color: .systemBlue,
            apps: [
                OnboardingTourDemoApp(name: NSLocalizedString("Cursor", comment: "Onboarding demo app"), iconResourceName: "cursor", symbolName: "cursorarrow.rays", fallbackGlyph: "◇", color: .systemGray),
                OnboardingTourDemoApp(name: NSLocalizedString("Safari", comment: "Onboarding demo app"), iconResourceName: "safari", symbolName: "safari.fill", fallbackGlyph: "◉", color: .systemBlue),
                OnboardingTourDemoApp(name: NSLocalizedString("VS Code", comment: "Onboarding demo app"), iconResourceName: "vscode", symbolName: "chevron.left.forwardslash.chevron.right", fallbackGlyph: "</>", color: .systemBlue),
            ],
            selectedIndex: 1),
        OnboardingTourDemoFocusSet(
            name: NSLocalizedString("Side Projects", comment: "Onboarding demo Focus Set name"),
            symbolName: "hammer.fill",
            fallbackGlyph: "</>",
            color: .systemOrange,
            apps: [
                OnboardingTourDemoApp(name: NSLocalizedString("Finder", comment: "Onboarding demo app"), iconResourceName: "finder", symbolName: "folder.fill", fallbackGlyph: "□", color: .systemBlue),
                OnboardingTourDemoApp(name: NSLocalizedString("Notes", comment: "Onboarding demo app"), iconResourceName: "notes", symbolName: "note.text", fallbackGlyph: "≡", color: .systemYellow),
                OnboardingTourDemoApp(name: NSLocalizedString("Settings", comment: "Onboarding demo app"), iconResourceName: "settings", symbolName: "gearshape.fill", fallbackGlyph: "⚙", color: .systemGray),
            ],
            selectedIndex: 2),
    ]
}

enum OnboardingSwitcherPreviewLayout {
    case iconGrid
    case titleList
}

enum OnboardingTourCategoryBadgeImage {
    private static let size = NSSize(width: 20, height: 20)

    static func make(for focusSet: OnboardingTourDemoFocusSet) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            drawBackground(focusSet.color, in: rect)
            drawSymbol(focusSet, in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawBackground(_ color: NSColor, in rect: NSRect) {
        color.setFill()
        NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 5.5, yRadius: 5.5).fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 5.5, yRadius: 5.5)
        border.lineWidth = 1
        border.stroke()
    }

    private static func drawSymbol(_ focusSet: OnboardingTourDemoFocusSet, in rect: NSRect) {
        if #available(macOS 11.0, *), let symbol = NSImage(systemSymbolName: focusSet.symbolName, accessibilityDescription: nil) {
            let configured = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)) ?? symbol
            configured.tinted(.white).draw(in: rect.insetBy(dx: 4.5, dy: 4.5), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let glyph = focusSet.fallbackGlyph as NSString
        let glyphSize = glyph.size(withAttributes: attributes)
        let glyphRect = NSRect(x: rect.midX - glyphSize.width / 2, y: rect.midY - glyphSize.height / 2, width: glyphSize.width, height: glyphSize.height)
        glyph.draw(in: glyphRect, withAttributes: attributes)
    }
}

final class OnboardingSwitcherPreviewView: NSView {
    private enum Metrics {
        static let size = NSSize(width: 640, height: 210)
        static let iconPanelSize = NSSize(width: 536, height: 160)
        static let iconTileSize = NSSize(width: 136, height: 130)
        static let iconGap = DesignSystem.Metrics.sectionGap
        static let listPanelSize = NSSize(width: 536, height: 190)
        static let listTileSize = NSSize(width: 504, height: 52)
        static let listGap = CGFloat(6)
        static let animationDuration = CFTimeInterval(0.34)
        static let animationStagger = CFTimeInterval(0.045)
    }

    private let panel = NSView()
    private let tiles = (0..<3).map { _ in OnboardingSwitcherTileView() }
    private var apps = [OnboardingTourDemoApp]()
    private var previewLayout = OnboardingSwitcherPreviewLayout.iconGrid
    private var selectedIndex = 0
    private var accessibilityObserver: NSObjectProtocol?

    override var intrinsicContentSize: NSSize { Metrics.size }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshColors() }
        refreshColors()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    override func layout() {
        super.layout()
        applyFrames()
    }

    override func accessibilityChildren() -> [Any]? { [] }
    override func isAccessibilityElement() -> Bool { true }

    func apply(apps: [OnboardingTourDemoApp], layout: OnboardingSwitcherPreviewLayout, selectedIndex: Int, summary: String, animated: Bool) {
        let previousLayout = previewLayout
        let previousPanelFrame = panel.layer?.presentation()?.frame ?? panel.frame
        let previousFrames = tilePresentationFrames()
        let shouldAnimateGeometry = animated && previousLayout != layout && self.apps.count == min(apps.count, tiles.count)
        removeAllAnimations()
        self.apps = Array(apps.prefix(tiles.count))
        previewLayout = layout
        self.selectedIndex = max(0, min(selectedIndex, max(self.apps.count - 1, 0)))
        setAccessibilityLabel(summary)
        applyContent()
        applyFrames()
        guard animated, hasUsableBounds else { return }
        shouldAnimateGeometry ? animateLayoutTransition(from: previousPanelFrame, tileFrames: previousFrames) : animateEntry()
    }

    func animateSelectionTransition(from previousSelectedIndex: Int, duration: CFTimeInterval, changeKeyTime: Double) {
        guard apps.indices.contains(previousSelectedIndex), apps.indices.contains(selectedIndex), previousSelectedIndex != selectedIndex else { return }
        let movement = selectedIndex > previousSelectedIndex ? CGFloat(12) : CGFloat(-12)
        for (index, tile) in tiles.prefix(apps.count).enumerated() {
            let wasSelected = index == previousSelectedIndex
            guard wasSelected != (index == selectedIndex) else { continue }
            tile.animateSelectionTransition(wasSelected: wasSelected, duration: duration, changeKeyTime: changeKeyTime, movement: movement)
        }
    }

    func removeAllAnimations() {
        removeAnimations(from: self)
    }

    private var hasUsableBounds: Bool {
        bounds.width > 0 && bounds.height > 0 && panel.bounds.width > 0 && panel.bounds.height > 0
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        panel.translatesAutoresizingMaskIntoConstraints = true
        DesignSystemControlStyler.styleSurface(panel)
        addSubview(panel)
        tiles.forEach {
            $0.isHidden = true
            panel.addSubview($0)
        }
    }

    private func applyContent() {
        for (index, tile) in tiles.enumerated() {
            let isVisible = apps.indices.contains(index)
            tile.isHidden = !isVisible
            guard isVisible else { continue }
            tile.apply(app: apps[index], layout: previewLayout, selected: index == selectedIndex)
        }
    }

    private func applyFrames() {
        panel.frame = centeredFrame(size: previewLayout == .iconGrid ? Metrics.iconPanelSize : Metrics.listPanelSize, in: bounds)
        let visibleTiles = Array(tiles.prefix(apps.count))
        switch previewLayout {
        case .iconGrid: applyIconFrames(visibleTiles)
        case .titleList: applyListFrames(visibleTiles)
        }
    }

    private func applyIconFrames(_ visibleTiles: [OnboardingSwitcherTileView]) {
        let contentWidth = CGFloat(visibleTiles.count) * Metrics.iconTileSize.width + CGFloat(max(visibleTiles.count - 1, 0)) * Metrics.iconGap
        let origin = NSPoint(x: (panel.bounds.width - contentWidth) / 2, y: (panel.bounds.height - Metrics.iconTileSize.height) / 2)
        for (index, tile) in visibleTiles.enumerated() {
            tile.frame = NSRect(x: origin.x + CGFloat(index) * (Metrics.iconTileSize.width + Metrics.iconGap), y: origin.y, width: Metrics.iconTileSize.width, height: Metrics.iconTileSize.height)
        }
    }

    private func applyListFrames(_ visibleTiles: [OnboardingSwitcherTileView]) {
        let contentHeight = CGFloat(visibleTiles.count) * Metrics.listTileSize.height + CGFloat(max(visibleTiles.count - 1, 0)) * Metrics.listGap
        let origin = NSPoint(x: (panel.bounds.width - Metrics.listTileSize.width) / 2, y: (panel.bounds.height - contentHeight) / 2)
        for (index, tile) in visibleTiles.enumerated() {
            tile.frame = NSRect(x: origin.x, y: origin.y + CGFloat(visibleTiles.count - index - 1) * (Metrics.listTileSize.height + Metrics.listGap), width: Metrics.listTileSize.width, height: Metrics.listTileSize.height)
        }
    }

    private func centeredFrame(size: NSSize, in rect: NSRect) -> NSRect {
        NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func animateEntry() {
        layoutSubtreeIfNeeded()
        for (index, tile) in tiles.prefix(apps.count).enumerated() {
            guard let layer = tile.layer else { continue }
            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = NSPoint(x: layer.position.x + 18, y: layer.position.y)
            position.toValue = layer.position
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0
            opacity.toValue = 1
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = index == selectedIndex ? 0.94 : 0.97
            scale.toValue = 1
            position.duration = Metrics.animationDuration
            opacity.duration = Metrics.animationDuration
            scale.duration = Metrics.animationDuration
            let group = CAAnimationGroup()
            group.animations = [position, opacity, scale]
            group.duration = Metrics.animationDuration
            group.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + CFTimeInterval(index) * Metrics.animationStagger
            group.fillMode = .backwards
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(group, forKey: "onboarding.tiles.entry")
        }
    }

    private func tilePresentationFrames() -> [NSRect] {
        layoutSubtreeIfNeeded()
        return tiles.map { $0.layer?.presentation()?.frame ?? $0.frame }
    }

    private func animateLayoutTransition(from previousPanelFrame: NSRect, tileFrames: [NSRect]) {
        layoutSubtreeIfNeeded()
        animateFrame(of: panel.layer, from: previousPanelFrame, duration: Metrics.animationDuration + 0.08, key: "onboarding.panel.layout")
        for (index, tile) in tiles.prefix(apps.count).enumerated() {
            guard tileFrames.indices.contains(index) else { continue }
            animateFrame(of: tile.layer, from: tileFrames[index], duration: Metrics.animationDuration + 0.08, key: "onboarding.tile.layout")
        }
    }

    private func animateFrame(of layer: CALayer?, from oldFrame: NSRect, duration: CFTimeInterval, key: String) {
        guard let layer, oldFrame.width > 0, oldFrame.height > 0 else { return }
        let position = CABasicAnimation(keyPath: "position")
        position.fromValue = NSPoint(x: oldFrame.midX, y: oldFrame.midY)
        position.toValue = layer.position
        let bounds = CABasicAnimation(keyPath: "bounds")
        bounds.fromValue = NSRect(origin: layer.bounds.origin, size: oldFrame.size)
        bounds.toValue = layer.bounds
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.72
        opacity.toValue = 1
        position.duration = duration
        bounds.duration = duration
        opacity.duration = duration
        let group = CAAnimationGroup()
        group.animations = [position, bounds, opacity]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(group, forKey: key)
    }

    private func removeAnimations(from view: NSView) {
        removeAnimations(from: view.layer)
        view.subviews.forEach { removeAnimations(from: $0) }
    }

    private func removeAnimations(from layer: CALayer?) {
        layer?.removeAllAnimations()
        layer?.sublayers?.forEach { removeAnimations(from: $0) }
    }

    private func refreshColors() {
        removeAllAnimations()
        DesignSystemControlStyler.refreshSurface(panel)
        tiles.forEach { $0.refreshColors() }
    }
}

final class OnboardingTourKeycapView: DesignSystemFlatSurfaceView {
    private let label: NSTextField

    override var intrinsicContentSize: NSSize {
        let size = label.intrinsicContentSize
        return NSSize(width: ceil(size.width + 18), height: max(DesignSystem.Metrics.standardControlMinHeight, ceil(size.height + 12)))
    }

    init(_ text: String) {
        label = NSTextField(labelWithString: text)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func setup() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = DesignSystem.color(.textPrimary, appearance: effectiveAppearance)
        label.setAccessibilityElement(false)
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(false)
    }
}

private final class OnboardingSwitcherTileView: NSView {
    private let selectionView = NSView()
    private let icon = OnboardingTourAppIconView()
    private let title = NSTextField(labelWithString: "")
    private var previewLayout = OnboardingSwitcherPreviewLayout.iconGrid
    private var selected = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func layout() {
        super.layout()
        switch previewLayout {
        case .iconGrid: layoutIconTile()
        case .titleList: layoutTitleTile()
        }
    }

    func apply(app: OnboardingTourDemoApp, layout: OnboardingSwitcherPreviewLayout, selected: Bool) {
        previewLayout = layout
        self.selected = selected
        icon.apply(app)
        title.stringValue = app.name
        needsLayout = true
        refreshColors()
    }

    func refreshColors() {
        let selectionOpacity = selected ? Float(1) : Float(0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionView.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfaceSelected, in: self)
        selectionView.layer?.borderColor = DesignSystem.semanticCGColor(.borderSelected, in: self)
        selectionView.layer?.opacity = selectionOpacity
        title.layer?.opacity = 1
        CATransaction.commit()
        title.font = NSFont.systemFont(ofSize: 13, weight: selected ? .semibold : .medium)
        title.textColor = DesignSystem.color(selected ? .textPrimary : .textSecondary, appearance: effectiveAppearance)
    }

    func animateSelectionTransition(wasSelected: Bool, duration: CFTimeInterval, changeKeyTime: Double, movement: CGFloat) {
        guard wasSelected != selected, let selectionLayer = selectionView.layer, let iconLayer = icon.layer else { return }
        let end = min(max(changeKeyTime + 0.04, 0), 1)
        let start = min(max(changeKeyTime, 0), end)
        let keyTimes = [NSNumber(value: 0), NSNumber(value: start), NSNumber(value: end), NSNumber(value: 1)]
        let selectionOpacity = selectionKeyframes(keyPath: "opacity", from: wasSelected ? Float(1) : Float(0), to: selected ? Float(1) : Float(0), keyTimes: keyTimes)
        selectionOpacity.duration = duration
        selectionLayer.add(selectionOpacity, forKey: "onboarding.selection.opacity")
        let translation = selectionKeyframes(keyPath: "transform.translation.x", from: selected ? -movement : CGFloat(0), to: CGFloat(0), keyTimes: keyTimes)
        let scale = selectionKeyframes(keyPath: "transform.scale", from: selected ? CGFloat(0.96) : CGFloat(1), to: CGFloat(1), keyTimes: keyTimes)
        translation.duration = duration
        scale.duration = duration
        let iconGroup = CAAnimationGroup()
        iconGroup.animations = [translation, scale]
        iconGroup.duration = duration
        iconLayer.add(iconGroup, forKey: "onboarding.selection.icon")
    }

    private func setup() {
        wantsLayer = true
        selectionView.wantsLayer = true
        selectionView.layer?.borderWidth = DesignSystem.Metrics.selectionIndicatorBorderWidth
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        title.alignment = .center
        title.wantsLayer = true
        [selectionView, icon, title].forEach {
            $0.setAccessibilityElement(false)
            addSubview($0)
        }
        setAccessibilityElement(false)
    }

    private func layoutIconTile() {
        let iconSide = min(CGFloat(72), bounds.width - 32)
        icon.frame = NSRect(x: (bounds.width - iconSide) / 2, y: 40, width: iconSide, height: iconSide)
        selectionView.frame = icon.frame.insetBy(dx: -8, dy: -8)
        selectionView.layer?.cornerRadius = DesignSystem.Metrics.controlRadius
        title.frame = NSRect(x: 4, y: 7, width: bounds.width - 8, height: 20)
        title.alignment = .center
    }

    private func layoutTitleTile() {
        selectionView.frame = bounds
        selectionView.layer?.cornerRadius = DesignSystem.Metrics.controlRadius
        icon.frame = NSRect(x: 12, y: 9, width: 34, height: 34)
        title.frame = NSRect(x: 58, y: 15, width: bounds.width - 76, height: 22)
        title.alignment = .left
    }

    private func selectionKeyframes(keyPath: String, from: Any, to: Any, keyTimes: [NSNumber]) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = [from, from, to, to]
        animation.keyTimes = keyTimes
        animation.timingFunctions = [CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .linear)]
        return animation
    }
}

private final class OnboardingTourAppIconView: NSView {
    private let backdrop = NSView()
    private let imageView = NSImageView()
    private let fallbackLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func layout() {
        super.layout()
        backdrop.frame = bounds
        imageView.frame = bounds
        fallbackLabel.frame = bounds
        let radius = min(bounds.width, bounds.height) * 0.22
        backdrop.layer?.cornerRadius = radius
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    func apply(_ app: OnboardingTourDemoApp) {
        let image = OnboardingTourAppIconStore.image(named: app.iconResourceName)
        imageView.image = image
        imageView.isHidden = image == nil
        fallbackLabel.isHidden = image != nil
        fallbackLabel.stringValue = app.fallbackGlyph
        fallbackLabel.textColor = .white
        backdrop.layer?.backgroundColor = DesignSystem.resolvedCGColor(image == nil ? app.color : .clear, in: self)
        guard image == nil else { return }
        applyFallbackSymbol(app)
    }

    private func setup() {
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowRadius = 2.5
        layer?.shadowOffset = NSSize(width: 0, height: -1)
        backdrop.wantsLayer = true
        backdrop.layer?.masksToBounds = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setAccessibilityElement(false)
        fallbackLabel.alignment = .center
        fallbackLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        fallbackLabel.setAccessibilityElement(false)
        setAccessibilityElement(false)
        addSubview(backdrop)
        addSubview(imageView)
        addSubview(fallbackLabel)
    }

    private func applyFallbackSymbol(_ app: OnboardingTourDemoApp) {
        guard #available(macOS 11.0, *), let symbol = NSImage(systemSymbolName: app.symbolName, accessibilityDescription: nil) else { return }
        imageView.image = symbol
        imageView.contentTintColor = .white
        imageView.isHidden = false
        fallbackLabel.isHidden = true
    }
}

private enum OnboardingTourAppIconStore {
    private static var cache = [String: NSImage]()

    static func image(named name: String) -> NSImage? {
        if let image = cache[name] { return image }
        guard let url = Bundle.main.url(forResource: name + "@2x", withExtension: "heic"), let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }
}
