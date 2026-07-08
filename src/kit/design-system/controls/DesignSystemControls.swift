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
        return base.insetBy(dx: DesignSystem.Metrics.controlTextInset, dy: 0)
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

final class DesignSystemFlatButton: NSButton {
    var drawsAppOwnedSurface: Bool { true }
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
        let lineWidth = isFocused ? CGFloat(1.5) : CGFloat(1)
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
        if usesDestructiveAccent {
            let alpha = isEnabled ? 0.32 : 0.18
            return DesignSystem.color(.statusDestructive, appearance: effectiveAppearance).withAlphaComponent(alpha)
        }
        if isFocused {
            return DesignSystem.color(.focusAccent, appearance: effectiveAppearance)
        }
        if isChoiceSelected {
            return DesignSystem.color(.borderSelected, appearance: effectiveAppearance)
        }
        return DesignSystem.color(.borderSubtle, appearance: effectiveAppearance)
    }

    private func titleColor() -> NSColor {
        guard isEnabled else { return DesignSystem.color(.textDisabled, appearance: effectiveAppearance) }
        return usesDestructiveAccent ? DesignSystem.color(.statusDestructive, appearance: effectiveAppearance) : DesignSystem.color(.textPrimary, appearance: effectiveAppearance)
    }

    private func titleFont() -> NSFont {
        guard isChoiceSelected else { return font ?? NSFont.systemFont(ofSize: 13) }
        return NSFont.systemFont(ofSize: font?.pointSize ?? 13, weight: .semibold)
    }

    private var isFocused: Bool { window?.firstResponder == self && NSApp.isActive }
}

final class DesignSystemChipSelectControl: NSControl {
    var drawsAppOwnedSurface: Bool { true }
    private let stack = NSStackView()
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
        didSet { buttons.forEach { $0.isEnabled = isEnabled } }
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
        selectedIndexStorage = max(0, min(index, buttons.count - 1))
        updateButtonStates()
        if notify { sendAction(action, to: target) }
    }

    private func updateButtonStates() {
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndexStorage
            button.state = isSelected ? .on : .off
            button.isChoiceSelected = isSelected
        }
    }
}

final class DesignSystemSegmentedControl: NSSegmentedControl {
    var drawsAppOwnedSurface: Bool { true }
    private var hoveredSegment = -1
    private var pressedSegment = -1
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
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
        super.mouseDown(with: event)
        pressedSegment = -1
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawPlateau()
        drawSegments()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
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
        let lineWidth = isFocused ? CGFloat(1.5) : CGFloat(1)
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
        drawSegmentContent(index, rect.insetBy(dx: 8, dy: 4), enabled: state != .disabled)
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
            drawImage(image, centeredIn: rect, enabled: enabled)
            return
        }
        drawTitle(title, image: image, in: rect, enabled: enabled)
    }

    private func drawImage(_ image: NSImage, centeredIn rect: CGRect, enabled: Bool) {
        let imageRect = fittedImageRect(image.size, centeredIn: rect, maximumDimension: 16)
        let drawableImage = image.isTemplate ? image.tinted(imageTintColor(enabled: enabled)) : image
        drawableImage.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: image.isTemplate || enabled ? 1 : 0.45)
    }

    private func drawTitle(_ title: String, image: NSImage?, in rect: CGRect, enabled: Bool) {
        let attrs = titleAttributes(enabled: enabled)
        let textSize = (title as NSString).size(withAttributes: attrs)
        let imageSide = image == nil ? CGFloat(0) : CGFloat(14)
        let gap = image == nil ? CGFloat(0) : CGFloat(4)
        let totalWidth = imageSide + gap + textSize.width
        var x = rect.midX - totalWidth / 2
        if let image {
            let imageRect = CGRect(x: x, y: rect.midY - imageSide / 2, width: imageSide, height: imageSide)
            drawImage(image, centeredIn: imageRect, enabled: enabled)
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
