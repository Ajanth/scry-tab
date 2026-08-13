import Cocoa

private final class DesignSystemInsetTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        textRect(forBounds: rect)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        textRect(forBounds: rect)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: textRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: textRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    private func textRect(forBounds rect: NSRect) -> NSRect {
        let base = super.drawingRect(forBounds: rect)
        return base.insetBy(
            dx: DesignSystem.Metrics.controlTextInset,
            dy: DesignSystem.Metrics.controlTextVerticalInset)
    }
}

private final class DesignSystemInsetSearchFieldCell: NSSearchFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        searchTextRect(forBounds: rect)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        searchTextRect(forBounds: rect)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: searchTextRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: searchTextRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func searchButtonRect(forBounds rect: NSRect) -> NSRect {
        let buttonRect = super.searchButtonRect(forBounds: rect)
        return buttonRect.offsetBy(dx: DesignSystem.Metrics.searchGlyphInset, dy: 0)
    }

    override func cancelButtonRect(forBounds rect: NSRect) -> NSRect {
        let buttonRect = super.cancelButtonRect(forBounds: rect)
        return buttonRect.offsetBy(dx: -DesignSystem.Metrics.searchGlyphInset / 2, dy: 0)
    }

    override func searchTextRect(forBounds rect: NSRect) -> NSRect {
        let base = super.searchTextRect(forBounds: rect)
        let adjusted = base.offsetBy(dx: DesignSystem.Metrics.searchTextInset, dy: 0)
        return NSRect(x: adjusted.minX,
                      y: adjusted.minY,
                      width: max(adjusted.width - DesignSystem.Metrics.searchTextInset, 0),
                      height: adjusted.height)
    }
}

private func copyTextCellState(from source: NSTextFieldCell, to destination: NSTextFieldCell) {
    destination.alignment = source.alignment
    destination.allowsEditingTextAttributes = source.allowsEditingTextAttributes
    destination.backgroundColor = source.backgroundColor
    destination.baseWritingDirection = source.baseWritingDirection
    destination.font = source.font
    destination.formatter = source.formatter
    destination.isBezeled = source.isBezeled
    destination.isBordered = source.isBordered
    destination.isEditable = source.isEditable
    destination.isScrollable = source.isScrollable
    destination.isSelectable = source.isSelectable
    destination.lineBreakMode = source.lineBreakMode
    destination.placeholderAttributedString = source.placeholderAttributedString
    destination.placeholderString = source.placeholderString
    destination.usesSingleLineMode = source.usesSingleLineMode
    destination.wraps = source.wraps
}

private final class DesignSystemSelectedControlIndicator {
    private enum Motion {
        static let visibilityDuration = CFTimeInterval(0.14)
        static let springMass = CGFloat(1)
        static let springStiffness = CGFloat(600)
        static let springDamping = CGFloat(50)
    }

    static let inset = CGFloat(2)
    let layer = CALayer()

    func install(on view: NSView) {
        layer.zPosition = 1
        layer.borderWidth = DesignSystem.Metrics.selectionIndicatorBorderWidth
        layer.opacity = 0
        view.layer?.addSublayer(layer)
    }

    func show(in rect: NSRect, on view: NSView, animated: Bool) {
        let previousPosition = layer.presentation()?.position ?? layer.position
        let wasVisible = layer.opacity > 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.bounds = NSRect(origin: .zero, size: rect.size)
        layer.position = NSPoint(x: rect.midX, y: rect.midY)
        layer.cornerRadius = DesignSystem.Metrics.controlRadius - 1
        layer.borderColor = DesignSystem.semanticCGColor(.borderSelected, in: view)
        layer.borderWidth = DesignSystem.Metrics.selectionIndicatorBorderWidth
        layer.opacity = 1
        CATransaction.commit()
        guard animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        if wasVisible {
            animatePosition(from: previousPosition, to: layer.position)
        } else {
            animateVisibility(from: 0, to: 1)
        }
    }

    func hide(animated: Bool) {
        guard layer.opacity > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = 0
        CATransaction.commit()
        guard animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        animateVisibility(from: 1, to: 0)
    }

    private func animatePosition(from: Any, to: Any) {
        let animation = CASpringAnimation(keyPath: "position")
        animation.fromValue = from
        animation.toValue = to
        animation.mass = Motion.springMass
        animation.stiffness = Motion.springStiffness
        animation.damping = Motion.springDamping
        animation.duration = animation.settlingDuration
        layer.add(animation, forKey: "selectedControlIndicator.position")
    }

    private func animateVisibility(from: CGFloat, to: CGFloat) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = Motion.visibilityDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "selectedControlIndicator.opacity")
    }
}

final class DesignSystemPageIndicator: NSView {
    private enum Motion {
        static let duration = CFTimeInterval(0.24)
    }

    private let pageCount: Int
    private let selectedLayer = CALayer()
    private var dotLayers = [CALayer]()
    private var selectedIndex = 0
    private var accessibilityObserver: NSObjectProtocol?

    init(pageCount: Int) {
        self.pageCount = max(pageCount, 0)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
    }

    override var intrinsicContentSize: NSSize {
        guard pageCount > 0 else { return .zero }
        let dotWidth = CGFloat(pageCount) * DesignSystem.Metrics.pageIndicatorDotDiameter
        let spacingWidth = CGFloat(pageCount - 1) * DesignSystem.Metrics.pageIndicatorDotSpacing
        return NSSize(width: dotWidth + spacingWidth, height: DesignSystem.Metrics.pageIndicatorDotDiameter)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopAnimating()
            self?.refreshColors()
        }
        refreshColors()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    override func layout() {
        super.layout()
        let diameter = DesignSystem.Metrics.pageIndicatorDotDiameter
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, dotLayer) in dotLayers.enumerated() {
            dotLayer.bounds = NSRect(x: 0, y: 0, width: diameter, height: diameter)
            dotLayer.position = position(for: index)
            dotLayer.cornerRadius = diameter / 2
        }
        selectedLayer.bounds = NSRect(x: 0, y: 0, width: diameter, height: diameter)
        selectedLayer.position = position(for: selectedIndex)
        selectedLayer.cornerRadius = diameter / 2
        CATransaction.commit()
    }

    func selectPage(_ index: Int, animated: Bool) {
        guard dotLayers.indices.contains(index) else { return }
        let previousPosition = selectedLayer.presentation()?.position ?? selectedLayer.position
        selectedIndex = index
        needsLayout = true
        layoutSubtreeIfNeeded()
        guard animated, previousPosition != selectedLayer.position,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            stopAnimating()
            return
        }
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = previousPosition
        animation.toValue = selectedLayer.position
        animation.duration = Motion.duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        selectedLayer.add(animation, forKey: "pageIndicator.position")
    }

    func stopAnimating() {
        selectedLayer.removeAnimation(forKey: "pageIndicator.position")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        for _ in 0..<pageCount {
            let dotLayer = CALayer()
            layer?.addSublayer(dotLayer)
            dotLayers.append(dotLayer)
        }
        selectedLayer.zPosition = 1
        layer?.addSublayer(selectedLayer)
        refreshColors()
    }

    private func position(for index: Int) -> NSPoint {
        let diameter = DesignSystem.Metrics.pageIndicatorDotDiameter
        let step = diameter + DesignSystem.Metrics.pageIndicatorDotSpacing
        return NSPoint(x: diameter / 2 + CGFloat(index) * step, y: bounds.midY)
    }

    private func refreshColors() {
        let inactiveColor = DesignSystem.semanticCGColor(.textDisabled, in: self)
        dotLayers.forEach { $0.backgroundColor = inactiveColor }
        selectedLayer.backgroundColor = DesignSystem.semanticCGColor(.progressAccent, in: self)
    }
}

final class DesignSystemFlatButton: NSButton {
    var drawsAppOwnedSurface: Bool { true }
    var usesPrimaryAccent = false {
        didSet {
            refreshTitle()
            needsDisplay = true
        }
    }
    var isChoiceSelected = false {
        didSet {
            refreshTitle()
            needsDisplay = true
        }
    }
    var usesDestructiveAccent = false {
        didSet {
            if #available(macOS 11.0, *) { hasDestructiveAction = usesDestructiveAccent }
            refreshTitle()
            needsDisplay = true
        }
    }

    private var hovered = false
    private var pressed = false
    private var trackingArea: NSTrackingArea?
    private var windowObservers = [NSObjectProtocol]()
    private var accessibilityObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    convenience init(title: String, target: Any?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target as AnyObject?
        self.action = action
        refreshTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
    }

    override var isEnabled: Bool {
        didSet {
            refreshTitle()
            needsDisplay = true
        }
    }

    override var title: String {
        didSet {
            refreshTitle()
            invalidateIntrinsicContentSize()
        }
    }

    override var image: NSImage? {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        let width = max(base.width, 0) + 2 * DesignSystem.Metrics.buttonHorizontalPadding
        let height = max(max(base.height, 0) + 2 * DesignSystem.Metrics.buttonVerticalPadding,
                         DesignSystem.Metrics.standardControlMinHeight)
        return NSSize(width: ceil(width), height: ceil(height))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        pressed = false
        needsDisplay = true
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        pressed = true
        needsDisplay = true
        super.mouseDown(with: event)
        pressed = false
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.needsDisplay = true
                })
            }
        }
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.needsDisplay = true
        }
        needsDisplay = true
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshTitle()
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { needsDisplay = true }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { needsDisplay = true }
        return resigned
    }

    override func draw(_ dirtyRect: NSRect) {
        drawSurface()
        super.draw(dirtyRect)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        bezelStyle = .rounded
        focusRingType = .none
        font = NSFont.systemFont(ofSize: 13)
        imagePosition = .imageLeading
        setButtonType(.momentaryPushIn)
        cell?.lineBreakMode = .byTruncatingTail
        refreshTitle()
    }

    private func refreshTitle() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let color = titleColor()
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: titleFont(),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
        attributedAlternateTitle = attributedTitle
        if #available(macOS 10.14, *) {
            contentTintColor = color
        }
    }

    private func drawSurface() {
        let lineWidth = showsOwnFocusAccent ? CGFloat(1.5) : CGFloat(1)
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: rect, xRadius: DesignSystem.Metrics.controlRadius, yRadius: DesignSystem.Metrics.controlRadius)
        surfaceFillColor().setFill()
        path.fill()
        borderColor().setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func surfaceFillColor() -> NSColor {
        if usesPrimaryAccent {
            let accent = DesignSystem.color(.accentPrimary, appearance: effectiveAppearance)
            guard isEnabled else { return accent.withAlphaComponent(0.5) }
            if pressed { return accent.shadow(withLevel: 0.12) ?? accent }
            if hovered { return accent.highlight(withLevel: 0.08) ?? accent }
            return accent
        }
        let base: NSColor
        if !isEnabled {
            base = DesignSystem.color(.surfaceFlat, appearance: effectiveAppearance).withAlphaComponent(0.5)
        } else if pressed {
            base = DesignSystem.color(.surfacePressed, appearance: effectiveAppearance)
        } else if isChoiceSelected {
            base = DesignSystem.color(.surfaceSelected, appearance: effectiveAppearance)
        } else if hovered {
            base = DesignSystem.color(.surfaceHover, appearance: effectiveAppearance)
        } else {
            base = DesignSystem.color(.surfaceFlat, appearance: effectiveAppearance)
        }
        if usesDestructiveAccent && isEnabled && (hovered || pressed) {
            let destructive = DesignSystem.color(.statusDestructive, appearance: effectiveAppearance)
            return destructive.withAlphaComponent(pressed ? 0.14 : 0.08).blended(withFraction: 0.7, of: base) ?? base
        }
        return base
    }

    private func borderColor() -> NSColor {
        if usesPrimaryAccent {
            return DesignSystem.color(showsOwnFocusAccent ? .textOnAccent : .accentPrimary, appearance: effectiveAppearance)
        }
        if usesDestructiveAccent {
            let alpha = isEnabled ? 0.32 : 0.18
            return DesignSystem.color(.statusDestructive, appearance: effectiveAppearance).withAlphaComponent(alpha)
        }
        if showsOwnFocusAccent {
            return DesignSystem.color(.focusAccent, appearance: effectiveAppearance)
        }
        if isChoiceSelected {
            return DesignSystem.color(.borderSelected, appearance: effectiveAppearance)
        }
        return DesignSystem.color(.borderSubtle, appearance: effectiveAppearance)
    }

    private func titleColor() -> NSColor {
        guard isEnabled else { return DesignSystem.color(.textDisabled, appearance: effectiveAppearance) }
        if usesPrimaryAccent { return DesignSystem.color(.textOnAccent, appearance: effectiveAppearance) }
        return usesDestructiveAccent ? DesignSystem.color(.statusDestructive, appearance: effectiveAppearance) : DesignSystem.color(.textPrimary, appearance: effectiveAppearance)
    }

    private func titleFont() -> NSFont {
        guard isChoiceSelected else { return font ?? NSFont.systemFont(ofSize: 13) }
        return NSFont.systemFont(ofSize: font?.pointSize ?? 13, weight: .semibold)
    }

    var hasKeyboardFocus: Bool { isEnabled && window?.firstResponder == self && NSApp.isActive }
    private var showsOwnFocusAccent: Bool { hasKeyboardFocus }
}

enum DesignSystemDisclosureCaretDirection: Equatable {
    case up
    case down
}

private enum DesignSystemDisclosureCaretImage {
    private static let up = draw(.up)
    private static let down = draw(.down)

    static func make(_ direction: DesignSystemDisclosureCaretDirection) -> NSImage {
        switch direction {
        case .up: return up
        case .down: return down
        }
    }

    private static func draw(_ direction: DesignSystemDisclosureCaretDirection) -> NSImage {
        let metrics = DesignSystem.Metrics.self
        let size = NSSize(width: metrics.disclosureCaretTitleSpacing + metrics.disclosureCaretWidth,
                          height: metrics.disclosureCaretHeight)
        let image = NSImage(size: size, flipped: false) { _ in
            let strokeInset = metrics.disclosureCaretStrokeWidth / 2
            let caretRect = NSRect(x: metrics.disclosureCaretTitleSpacing, y: 0,
                                   width: metrics.disclosureCaretWidth, height: metrics.disclosureCaretHeight)
                .insetBy(dx: strokeInset, dy: strokeInset)
            let path = NSBezierPath()
            let outsideY = direction == .down ? caretRect.maxY : caretRect.minY
            let centerY = direction == .down ? caretRect.minY : caretRect.maxY
            path.move(to: NSPoint(x: caretRect.minX, y: outsideY))
            path.line(to: NSPoint(x: caretRect.midX, y: centerY))
            path.line(to: NSPoint(x: caretRect.maxX, y: outsideY))
            path.lineWidth = metrics.disclosureCaretStrokeWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// A compact, app-styled disclosure action followed by optional content. The content height and
/// opacity animate together so sections reveal their additional settings without adding custom
/// chrome or intercepting native button / keyboard behavior.
final class DesignSystemDisclosureSection: NSStackView {
    private enum Motion {
        static let duration = TimeInterval(0.2)
    }

    private let collapsedTitle: String
    private let expandedTitle: String
    private let disclosureButton: DesignSystemFlatButton
    private let contentContainer = NSView()
    private let content: NSView
    private var contentHeightConstraint: NSLayoutConstraint!
    private var disclosureButtonWidthConstraint: NSLayoutConstraint!

    private(set) var isExpanded = true
    var title: String { disclosureButton.title }
    var isContentVisible: Bool { !contentContainer.isHidden }
    var caretDirection: DesignSystemDisclosureCaretDirection { isExpanded ? .up : .down }
    var hasTrailingCaret: Bool { disclosureButton.image != nil && disclosureButton.imagePosition == .imageTrailing }
    var disclosureButtonWidth: CGFloat { disclosureButtonWidthConstraint.constant }
    var caretImageSize: NSSize { disclosureButton.image?.size ?? .zero }
    var caretTrailingPadding: CGFloat {
        let buttonBounds = NSRect(origin: .zero, size: NSSize(width: disclosureButtonWidth, height: disclosureButton.intrinsicContentSize.height))
        return buttonBounds.maxX - (disclosureButton.cell?.imageRect(forBounds: buttonBounds).maxX ?? buttonBounds.maxX)
    }

    init(collapsedTitle: String, expandedTitle: String, content: NSView) {
        self.collapsedTitle = collapsedTitle
        self.expandedTitle = expandedTitle
        self.content = content
        disclosureButton = DesignSystemControlStyler.makeButton(collapsedTitle)
        super.init(frame: .zero)
        setupView()
        setExpanded(false, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        refreshDisclosureButton()
        disclosureButton.setAccessibilityExpanded(expanded)
        let targetHeight = expanded ? resolvedContentHeight() : 0
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if expanded {
            contentContainer.isHidden = false
            contentContainer.alphaValue = shouldAnimate ? 0 : 1
        }
        guard shouldAnimate else {
            contentHeightConstraint.constant = targetHeight
            contentContainer.alphaValue = expanded ? 1 : 0
            contentContainer.isHidden = !expanded
            layoutParent()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Motion.duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            contentHeightConstraint.animator().constant = targetHeight
            contentContainer.animator().alphaValue = expanded ? 1 : 0
            layoutParent()
        }, completionHandler: { [weak self] in
            guard let self, self.isExpanded == expanded else { return }
            self.contentContainer.isHidden = !expanded
        })
    }

    @objc private func toggleDisclosure(_ sender: NSButton) {
        setExpanded(!isExpanded)
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        orientation = .vertical
        alignment = .centerX
        spacing = DesignSystem.Metrics.sectionGap
        disclosureButton.target = self
        disclosureButton.action = #selector(toggleDisclosure(_:))
        disclosureButton.imagePosition = .imageTrailing
        disclosureButton.imageHugsTitle = true
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.wantsLayer = true
        contentContainer.clipsToBounds = true
        contentContainer.addSubview(content)
        addArrangedSubview(disclosureButton)
        addArrangedSubview(contentContainer)
        stabilizeDisclosureButtonWidth()
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentContainer.widthAnchor.constraint(equalTo: content.widthAnchor),
            disclosureButton.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor),
            widthAnchor.constraint(equalTo: content.widthAnchor),
        ])
        contentHeightConstraint = contentContainer.heightAnchor.constraint(equalToConstant: 0)
        contentHeightConstraint.isActive = true
    }

    private func stabilizeDisclosureButtonWidth() {
        let states = [(collapsedTitle, DesignSystemDisclosureCaretDirection.down),
                      (expandedTitle, DesignSystemDisclosureCaretDirection.up)]
        let widths = states.map { title, direction -> CGFloat in
            disclosureButton.title = title
            disclosureButton.image = DesignSystemDisclosureCaretImage.make(direction)
            return disclosureButton.intrinsicContentSize.width
        }
        disclosureButtonWidthConstraint = disclosureButton.widthAnchor.constraint(equalToConstant: ceil(widths.max() ?? 0))
        disclosureButtonWidthConstraint.priority = .defaultHigh
        disclosureButtonWidthConstraint.isActive = true
    }

    private func refreshDisclosureButton() {
        disclosureButton.title = isExpanded ? expandedTitle : collapsedTitle
        disclosureButton.image = DesignSystemDisclosureCaretImage.make(caretDirection)
    }

    private func resolvedContentHeight() -> CGFloat {
        content.layoutSubtreeIfNeeded()
        return ceil(content.fittingSize.height)
    }

    private func layoutParent() {
        if let contentView = window?.contentView {
            contentView.layoutSubtreeIfNeeded()
        } else {
            superview?.layoutSubtreeIfNeeded()
        }
    }
}

final class DesignSystemChipSelectControl: NSControl {
    var drawsAppOwnedSurface: Bool { true }
    var usesAnimatedSelectionIndicator: Bool { true }
    private let stack = NSStackView()
    private let selectionIndicator = DesignSystemSelectedControlIndicator()
    private var buttons = [DesignSystemFlatButton]()
    private var selectedIndexStorage: Int

    var selectedIndex: Int {
        get { selectedIndexStorage }
        set { selectIndex(newValue, notify: false) }
    }

    init(labels: [String], selectedIndex: Int = 0, chipWidth: CGFloat = -1, equalWidth: Bool = false) {
        selectedIndexStorage = max(0, min(selectedIndex, max(labels.count - 1, 0)))
        super.init(frame: .zero)
        setupStack()
        makeButtons(labels, chipWidth: chipWidth, equalWidth: equalWidth)
        updateButtonStates()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var intrinsicContentSize: NSSize {
        stack.fittingSize
    }

    override var isEnabled: Bool {
        didSet {
            buttons.forEach { $0.isEnabled = isEnabled }
            updateSelectionIndicator(animated: false)
        }
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSelectionIndicator(animated: false)
    }

    override func layout() {
        super.layout()
        updateSelectionIndicator(animated: false)
    }

    var chipCount: Int { buttons.count }

    func chipTitle(at index: Int) -> String? {
        guard buttons.indices.contains(index) else { return nil }
        return buttons[index].title
    }

    func isChipSelected(at index: Int) -> Bool {
        guard buttons.indices.contains(index) else { return false }
        return buttons[index].state == .on
    }

    @objc private func chipPressed(_ sender: DesignSystemFlatButton) {
        selectIndex(sender.tag, notify: true)
    }

    private func setupStack() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        selectionIndicator.install(on: self)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func makeButtons(_ labels: [String], chipWidth: CGFloat, equalWidth: Bool) {
        let buttonWidths = labels.enumerated().map { index, label -> (DesignSystemFlatButton, CGFloat) in
            let button = DesignSystemControlStyler.makeButton(label, target: self, action: #selector(chipPressed(_:)))
            button.setButtonType(.toggle)
            button.tag = index
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            return (button, stabilizedButtonWidth(button, minimumWidth: chipWidth))
        }
        let resolvedEqualWidth = equalWidth ? buttonWidths.map { $0.1 }.max() ?? 0 : 0
        buttons = buttonWidths.map {
            let button = $0.0
            let width = equalWidth ? resolvedEqualWidth : $0.1
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
            stack.addArrangedSubview(button)
            return button
        }
    }

    private func stabilizedButtonWidth(_ button: DesignSystemFlatButton, minimumWidth: CGFloat) -> CGFloat {
        let wasSelected = button.isChoiceSelected
        let regularWidth = button.intrinsicContentSize.width
        button.isChoiceSelected = true
        let selectedWidth = button.intrinsicContentSize.width
        button.isChoiceSelected = wasSelected
        return ceil(max(regularWidth, selectedWidth, minimumWidth))
    }

    private func selectIndex(_ index: Int, notify: Bool) {
        guard !buttons.isEmpty else { return }
        let selectedIndex = max(0, min(index, buttons.count - 1))
        let changed = selectedIndex != selectedIndexStorage
        selectedIndexStorage = selectedIndex
        updateButtonStates()
        updateSelectionIndicator(animated: changed)
        if notify { sendAction(action, to: target) }
    }

    private func updateButtonStates() {
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndexStorage
            button.state = isSelected ? .on : .off
            button.isChoiceSelected = isSelected
        }
    }

    private func updateSelectionIndicator(animated: Bool) {
        guard isEnabled, buttons.indices.contains(selectedIndexStorage) else {
            selectionIndicator.hide(animated: animated)
            return
        }
        let button = buttons[selectedIndexStorage]
        let rect = button.convert(button.bounds, to: self).insetBy(dx: DesignSystemSelectedControlIndicator.inset, dy: DesignSystemSelectedControlIndicator.inset)
        selectionIndicator.show(in: rect, on: self, animated: animated)
    }
}

final class DesignSystemCenteredDetailPage: NSView {
    private let content: NSView
    private let pageWidth: CGFloat
    private let verticalInset: CGFloat

    static func contentWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth, 0), DesignSystem.Metrics.centeredSettingsContentMaxWidth)
    }

    init(content: NSView,
         width: CGFloat,
         verticalInset: CGFloat = DesignSystem.Metrics.centeredDetailPageVerticalInset) {
        self.content = content
        pageWidth = width
        self.verticalInset = verticalInset
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: pageWidth),
            content.topAnchor.constraint(equalTo: topAnchor, constant: verticalInset),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalInset),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: Self.contentWidth(for: pageWidth)),
        ])
    }
}

final class DesignSystemSegmentedControl: NSSegmentedControl {
    var drawsAppOwnedSurface: Bool { true }
    var usesAnimatedSelectionIndicator: Bool { trackingMode == .selectOne }
    var segmentImageDimension = CGFloat(14) { didSet { needsDisplay = true } }
    var segmentImageTitleSpacing = DesignSystem.Metrics.headerFooterGap { didSet { needsDisplay = true } }
    var segmentHorizontalContentInset = DesignSystem.Metrics.rowHorizontalPadding { didSet { needsDisplay = true } }
    private(set) var segmentProgressLayers = [CALayer]()
    private var hoveredSegment = -1
    private var pressedSegment = -1
    private var isTrackingNativeSelection = false
    private var trackingArea: NSTrackingArea?
    private let selectionIndicator = DesignSystemSelectedControlIndicator()
    private var segmentProgressValues = [CGFloat]()
    private var windowObservers = [NSObjectProtocol]()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override var selectedSegment: Int {
        didSet {
            if !isTrackingNativeSelection { updateSelectionIndicator(animated: false) }
            needsDisplay = true
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateSelectionIndicator(animated: false)
            updateProgressVisibility()
            needsDisplay = true
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.updateSelectionIndicator(animated: false)
                    self?.needsDisplay = true
                })
            }
        }
        windowObservers.append(NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateSelectionIndicator(animated: false)
            self?.needsDisplay = true
        })
        updateSelectionIndicator(animated: false)
        refreshProgressColors()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSelectionIndicator(animated: false)
        refreshProgressColors()
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            updateSelectionIndicator(animated: false)
            needsDisplay = true
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            updateSelectionIndicator(animated: false)
            needsDisplay = true
        }
        return resigned
    }

    override func layout() {
        super.layout()
        updateSelectionIndicator(animated: false)
        layoutProgressLayers()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        setHoveredSegment(segmentIndex(at: convert(event.locationInWindow, from: nil)))
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        setHoveredSegment(-1)
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        pressedSegment = segmentIndex(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
        isTrackingNativeSelection = true
        super.mouseDown(with: event)
        isTrackingNativeSelection = false
        pressedSegment = -1
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        isTrackingNativeSelection = true
        super.keyDown(with: event)
        isTrackingNativeSelection = false
    }

    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        let sent = super.sendAction(action, to: target)
        updateSelectionIndicator(animated: isTrackingNativeSelection)
        return sent
    }

    override func draw(_ dirtyRect: NSRect) {
        drawPlateau()
        drawSegments()
    }

    @discardableResult
    func equalizeSegmentWidths(minimumTotalWidth: CGFloat, maximumTotalWidth: CGFloat) -> CGFloat {
        guard segmentCount > 0 else { return 0 }
        let count = CGFloat(segmentCount)
        let minimumWidth = max(minimumTotalWidth, 0) / count
        let maximumWidth = max(max(maximumTotalWidth, minimumTotalWidth), 0) / count
        let preferredWidth = (0..<segmentCount).map(preferredWidth(forSegment:)).max() ?? 0
        let width = min(max(preferredWidth, minimumWidth), maximumWidth)
        for index in 0..<segmentCount { setWidth(width, forSegment: index) }
        invalidateIntrinsicContentSize()
        return width * count
    }

    func preferredWidth(forSegment index: Int) -> CGFloat {
        guard index >= 0, index < segmentCount else { return 0 }
        let title = label(forSegment: index) ?? ""
        let titleWidth = ceil((title as NSString).size(withAttributes: titleAttributes(enabled: true)).width)
        let hasImage = image(forSegment: index) != nil
        let imageWidth = hasImage ? segmentImageDimension : 0
        let spacing = hasImage && !title.isEmpty ? segmentImageTitleSpacing : 0
        return 2 * segmentHorizontalContentInset + imageWidth + spacing + titleWidth
    }

    func setProgress(_ fraction: CGFloat, forSegment index: Int, animationDuration: TimeInterval? = nil) {
        guard index >= 0, index < segmentCount else { return }
        synchronizeProgressLayers()
        layoutProgressLayers()
        let progress = min(max(fraction, 0), 1)
        let previous = segmentProgressValues[index]
        segmentProgressValues[index] = progress
        let layer = segmentProgressLayers[index]
        layer.removeAnimation(forKey: "segmentedControl.progress")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = isEnabled && progress > 0 ? 1 : 0
        layer.transform = CATransform3DMakeScale(progress, 1, 1)
        CATransaction.commit()
        guard let animationDuration, animationDuration > 0, previous != progress,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale.x")
        animation.fromValue = previous
        animation.toValue = progress
        animation.duration = animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(animation, forKey: "segmentedControl.progress")
    }

    func clearProgress() {
        guard !segmentProgressLayers.isEmpty else { return }
        segmentProgressValues = Array(repeating: 0, count: segmentProgressLayers.count)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in segmentProgressLayers {
            layer.removeAllAnimations()
            layer.opacity = 0
            layer.transform = CATransform3DMakeScale(0, 1, 1)
        }
        CATransaction.commit()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        selectionIndicator.install(on: self)
        segmentStyle = .rounded
        controlSize = .regular
        font = NSFont.systemFont(ofSize: 13)
        focusRingType = .none
    }

    private func setHoveredSegment(_ segment: Int) {
        guard hoveredSegment != segment else { return }
        hoveredSegment = segment
        needsDisplay = true
    }

    private func segmentIndex(at point: NSPoint) -> Int {
        segmentRects().firstIndex { $0.contains(point) } ?? -1
    }

    private func drawPlateau() {
        let lineWidth = isFocused ? DesignSystem.Metrics.focusIndicatorBorderWidth : CGFloat(1)
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: rect, xRadius: DesignSystem.Metrics.controlRadius, yRadius: DesignSystem.Metrics.controlRadius)
        DesignSystem.color(.surfaceFlat, appearance: effectiveAppearance).setFill()
        path.fill()
        borderColor().setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func drawSegments() {
        segmentRects().enumerated().forEach { index, rect in
            drawSegment(index, rect)
            if index < segmentCount - 1 { drawSeparator(after: index, rect) }
        }
    }

    private func drawSegment(_ index: Int, _ rect: CGRect) {
        let state = segmentState(index)
        let fill = fillColor(for: state)
        if state == .pressed || state == .selected || state == .hovered {
            let selectedRect = rect.insetBy(dx: 2, dy: 2)
            let path = NSBezierPath(roundedRect: selectedRect, xRadius: DesignSystem.Metrics.controlRadius - 1, yRadius: DesignSystem.Metrics.controlRadius - 1)
            fill.setFill()
            path.fill()
        }
        drawSegmentContent(index, rect.insetBy(dx: segmentHorizontalContentInset, dy: DesignSystem.Metrics.rowVerticalPadding), enabled: state != .disabled)
    }

    private func drawSeparator(after index: Int, _ rect: CGRect) {
        guard selectedSegment != index, selectedSegment != index + 1 else { return }
        let separator = NSRect(x: rect.maxX - 0.5, y: bounds.minY + 6, width: 1, height: max(bounds.height - 12, 0))
        DesignSystem.color(.borderSubtle, appearance: effectiveAppearance).setFill()
        separator.fill()
    }

    private func drawSegmentContent(_ index: Int, _ rect: CGRect, enabled: Bool) {
        let image = self.image(forSegment: index)
        let title = label(forSegment: index) ?? ""
        if title.isEmpty, let image {
            drawImage(image, centeredIn: rect, maximumDimension: 16, enabled: enabled)
            return
        }
        drawTitle(title, image: image, in: rect, enabled: enabled)
    }

    // `NSSegmentedControl` is flipped (top-left origin). Plain `NSImage.draw(in:from:operation:fraction:)`
    // doesn't account for that — it renders asymmetric glyphs (e.g. the search magnifying glass) upside
    // down. `respectFlipped: true` tells AppKit to orient the image for the current context's flippedness.
    private func drawImage(_ image: NSImage, centeredIn rect: CGRect, maximumDimension: CGFloat, enabled: Bool) {
        let imageRect = fittedImageRect(image.size, centeredIn: rect, maximumDimension: maximumDimension)
        let drawableImage = image.isTemplate ? image.tinted(imageTintColor(enabled: enabled)) : image
        drawableImage.draw(in: imageRect, from: .zero, operation: .sourceOver,
            fraction: image.isTemplate || enabled ? 1 : 0.45, respectFlipped: true, hints: nil)
    }

    private func drawTitle(_ title: String, image: NSImage?, in rect: CGRect, enabled: Bool) {
        let attrs = titleAttributes(enabled: enabled)
        let textSize = (title as NSString).size(withAttributes: attrs)
        let imageSide = image == nil ? CGFloat(0) : segmentImageDimension
        let gap = image == nil ? CGFloat(0) : segmentImageTitleSpacing
        let totalWidth = imageSide + gap + textSize.width
        var x = rect.midX - totalWidth / 2
        if let image {
            let imageRect = CGRect(x: x, y: rect.midY - imageSide / 2, width: imageSide, height: imageSide)
            drawImage(image, centeredIn: imageRect, maximumDimension: segmentImageDimension, enabled: enabled)
            x += imageSide + gap
        }
        let textRect = CGRect(x: x, y: rect.midY - textSize.height / 2, width: min(textSize.width, max(rect.maxX - x, 0)), height: textSize.height)
        (title as NSString).draw(in: textRect, withAttributes: attrs)
    }

    private func titleAttributes(enabled: Bool) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return [
            .font: font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: enabled ? DesignSystem.color(.textPrimary, appearance: effectiveAppearance) : DesignSystem.color(.textDisabled, appearance: effectiveAppearance),
            .paragraphStyle: paragraph,
        ]
    }

    func fittedImageRect(_ imageSize: CGSize, centeredIn rect: CGRect, maximumDimension: CGFloat) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let availableDimension = min(maximumDimension, rect.width, rect.height)
        let scale = min(availableDimension / imageSize.width, availableDimension / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: rect.midX - fittedSize.width / 2,
                      y: rect.midY - fittedSize.height / 2,
                      width: fittedSize.width,
                      height: fittedSize.height)
    }

    func imageTintColor(enabled: Bool) -> NSColor {
        DesignSystem.color(enabled ? .textPrimary : .textDisabled, appearance: effectiveAppearance)
    }

    private enum SegmentState {
        case disabled, pressed, selected, hovered, normal
    }

    private func segmentState(_ index: Int) -> SegmentState {
        guard isEnabled, isEnabled(forSegment: index) else { return .disabled }
        if pressedSegment == index { return .pressed }
        if selectedSegment == index { return .selected }
        if hoveredSegment == index { return .hovered }
        return .normal
    }

    private func fillColor(for state: SegmentState) -> NSColor {
        switch state {
        case .disabled, .normal: return .clear
        case .pressed: return DesignSystem.color(.surfacePressed, appearance: effectiveAppearance)
        case .selected: return DesignSystem.color(.surfaceSelected, appearance: effectiveAppearance)
        case .hovered: return DesignSystem.color(.surfaceHover, appearance: effectiveAppearance)
        }
    }

    private func borderColor() -> NSColor {
        isFocused ? DesignSystem.color(.focusAccent, appearance: effectiveAppearance) : DesignSystem.color(.borderSubtle, appearance: effectiveAppearance)
    }

    private func updateSelectionIndicator(animated: Bool) {
        guard usesAnimatedSelectionIndicator, isEnabled, selectedSegment >= 0, selectedSegment < segmentCount, isEnabled(forSegment: selectedSegment) else {
            selectionIndicator.hide(animated: animated)
            return
        }
        let rect = segmentRects()[selectedSegment].insetBy(dx: DesignSystemSelectedControlIndicator.inset, dy: DesignSystemSelectedControlIndicator.inset)
        selectionIndicator.show(in: rect, on: self, animated: animated)
    }

    private func synchronizeProgressLayers() {
        while segmentProgressLayers.count > segmentCount {
            segmentProgressLayers.removeLast().removeFromSuperlayer()
            segmentProgressValues.removeLast()
        }
        while segmentProgressLayers.count < segmentCount {
            let progressLayer = CALayer()
            progressLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
            progressLayer.cornerRadius = DesignSystem.Metrics.controlProgressHeight / 2
            progressLayer.opacity = 0
            progressLayer.zPosition = 0.5
            layer?.addSublayer(progressLayer)
            segmentProgressLayers.append(progressLayer)
            segmentProgressValues.append(0)
        }
        refreshProgressColors()
    }

    private func layoutProgressLayers() {
        guard !segmentProgressLayers.isEmpty else { return }
        synchronizeProgressLayers()
        let rects = segmentRects()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, progressLayer) in segmentProgressLayers.enumerated() where rects.indices.contains(index) {
            let segmentRect = rects[index]
            let width = max(segmentRect.width - 2 * DesignSystem.Metrics.controlTextInset, 0)
            let y = segmentRect.maxY - DesignSystem.Metrics.controlProgressBottomInset - DesignSystem.Metrics.controlProgressHeight
            progressLayer.bounds = CGRect(x: 0, y: 0, width: width, height: DesignSystem.Metrics.controlProgressHeight)
            progressLayer.position = CGPoint(x: segmentRect.minX + DesignSystem.Metrics.controlTextInset,
                                             y: y + DesignSystem.Metrics.controlProgressHeight / 2)
        }
        CATransaction.commit()
    }

    private func refreshProgressColors() {
        let color = DesignSystem.semanticCGColor(.progressAccent, in: self)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, progressLayer) in segmentProgressLayers.enumerated() {
            let progress = segmentProgressValues.indices.contains(index) ? segmentProgressValues[index] : 0
            progressLayer.backgroundColor = color
            progressLayer.opacity = isEnabled && progress > 0 ? 1 : 0
        }
        CATransaction.commit()
    }

    private func updateProgressVisibility() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, progressLayer) in segmentProgressLayers.enumerated() {
            let progress = segmentProgressValues.indices.contains(index) ? segmentProgressValues[index] : 0
            progressLayer.opacity = isEnabled && progress > 0 ? 1 : 0
        }
        CATransaction.commit()
    }

    private func segmentRects() -> [CGRect] {
        if segmentCount <= 0 { return [] }
        let widths = (0..<segmentCount).map { max(width(forSegment: $0), 0) }
        let explicitWidthTotal = widths.reduce(0) { $0 + ($1 > 0 ? $1 : 0) }
        let autoSegmentCount = widths.filter { $0 == 0 }.count
        let autoSegmentWidth = autoSegmentCount > 0 ? max(bounds.width - explicitWidthTotal, 0) / CGFloat(autoSegmentCount) : 0
        var currentX = bounds.minX
        return widths.enumerated().map { index, width in
            let resolvedWidth = width > 0 ? width : autoSegmentWidth
            let isLastSegment = index == segmentCount - 1
            let segmentWidth = isLastSegment ? max(bounds.maxX - currentX, 0) : resolvedWidth
            defer { currentX += segmentWidth }
            return CGRect(x: currentX, y: bounds.minY, width: segmentWidth, height: bounds.height)
        }
    }

    private var isFocused: Bool { window?.firstResponder == self && NSApp.isActive }
}

enum DesignSystemControlStyler {
    static func makeButton(_ title: String, destructive: Bool = false, target: Any? = nil, action: Selector? = nil) -> DesignSystemFlatButton {
        let button = DesignSystemFlatButton(title: title, target: target, action: action)
        styleButton(button, destructive: destructive)
        return button
    }

    static func makePrimaryButton(_ title: String, target: Any? = nil, action: Selector? = nil) -> DesignSystemFlatButton {
        let button = DesignSystemFlatButton(title: title, target: target, action: action)
        styleButton(button)
        button.usesPrimaryAccent = true
        button.keyEquivalent = "\r"
        return button
    }

    static func styleButton(_ button: NSButton, destructive: Bool = false) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.font = NSFont.systemFont(ofSize: 13)
        if let button = button as? DesignSystemFlatButton {
            button.usesDestructiveAccent = destructive
        } else {
            button.bezelStyle = .rounded
            button.controlSize = .regular
            if destructive, #available(macOS 11.0, *) {
                button.hasDestructiveAction = true
            }
        }
        ensureMinimumHeight(button)
    }

    static func styleIconButton(_ button: NSButton, size: CGFloat = 24) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
    }

    static func stylePopupButton(_ button: NSPopUpButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 13)
        if button is PopupButtonLikeSystemSettings {
            button.isBordered = false
            button.focusRingType = .none
        } else {
            button.bezelStyle = .rounded
        }
        ensureMinimumHeight(button)
    }

    static func styleSegmentedControl(_ control: NSSegmentedControl) {
        control.translatesAutoresizingMaskIntoConstraints = false
        if control is DesignSystemSegmentedControl {
            control.segmentStyle = .rounded
        }
        control.controlSize = .regular
        control.font = NSFont.systemFont(ofSize: 13)
        ensureMinimumHeight(control)
    }

    static func styleTextField(_ field: NSTextField) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .exterior
        field.font = NSFont.systemFont(ofSize: 13)
        if let cell = field.cell as? NSTextFieldCell {
            let paddedCell: NSTextFieldCell
            if let existing = cell as? DesignSystemInsetTextFieldCell {
                paddedCell = existing
            } else {
                let replacement = DesignSystemInsetTextFieldCell(textCell: field.stringValue)
                copyTextCellState(from: cell, to: replacement)
                field.cell = replacement
                paddedCell = replacement
            }
            paddedCell.isBordered = false
            paddedCell.isBezeled = false
            paddedCell.backgroundColor = .clear
        }
        field.wantsLayer = true
        field.layer?.cornerRadius = DesignSystem.Metrics.controlRadius
        field.layer?.borderWidth = 1
        field.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfaceFlat, in: field)
        field.layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: field)
        ensureMinimumHeight(field)
    }

    static func styleSearchField(_ field: NSSearchField) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 13)
        field.controlSize = .regular
        if let cell = field.cell as? NSSearchFieldCell {
            let paddedCell: NSSearchFieldCell
            if let existing = cell as? DesignSystemInsetSearchFieldCell {
                paddedCell = existing
            } else {
                let replacement = DesignSystemInsetSearchFieldCell(textCell: field.stringValue)
                copyTextCellState(from: cell, to: replacement)
                field.cell = replacement
                paddedCell = replacement
            }
            paddedCell.isBordered = false
            paddedCell.isBezeled = false
            paddedCell.backgroundColor = .clear
            paddedCell.focusRingType = .none
        }
        field.wantsLayer = true
        field.layer?.cornerRadius = DesignSystem.Metrics.controlRadius
        field.layer?.borderWidth = 1
        refreshSearchField(field)
        ensureMinimumHeight(field)
    }

    static func styleMainSearchField(_ field: NSSearchField) {
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = true
        field.bezelStyle = .roundedBezel
        if #available(macOS 26.0, *) {
            field.controlSize = .extraLarge
        } else if #available(macOS 13.0, *) {
            field.controlSize = .large
        } else {
            field.controlSize = .regular
        }
        field.usesSingleLineMode = true
    }

    static func styleSurface(_ view: NSView, radius: CGFloat = DesignSystem.Metrics.sectionRadius) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.borderWidth = 1
        view.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfacePlateau, in: view)
        view.layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: view)
    }

    static func refreshSurface(_ view: NSView) {
        view.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfacePlateau, in: view)
        view.layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: view)
    }

    static func refreshFlatField(_ field: NSTextField) {
        field.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfaceFlat, in: field)
        field.layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: field)
    }

    static func refreshSearchField(_ field: NSSearchField) {
        let isFocused: Bool
        if let window = field.window {
            isFocused = window.firstResponder == field.currentEditor() || window.firstResponder == field
        } else {
            isFocused = false
        }
        field.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfaceFlat, in: field)
        field.layer?.borderColor = DesignSystem.semanticCGColor(isFocused ? .focusAccent : .borderSubtle, in: field)
        field.layer?.borderWidth = isFocused ? 1.5 : 1
    }

    static func refreshEditableFields(in view: NSView) {
        if let field = view as? NSTextField, field.isEditable {
            refreshFlatField(field)
        }
        view.subviews.forEach { refreshEditableFields(in: $0) }
    }

    private static func ensureMinimumHeight(_ view: NSView) {
        let existing = view.constraints.first {
            $0.firstAnchor == view.heightAnchor && $0.secondAnchor == nil && $0.relation == .greaterThanOrEqual
        }
        guard existing == nil else { return }
        view.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignSystem.Metrics.standardControlMinHeight).isActive = true
    }
}
