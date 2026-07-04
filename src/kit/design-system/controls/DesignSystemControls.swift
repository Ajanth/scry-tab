import Cocoa

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
        drawFocusRingIfNeeded()
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
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: DesignSystem.Metrics.controlRadius, yRadius: DesignSystem.Metrics.controlRadius)
        DesignSystem.color(.surfaceFlat, appearance: effectiveAppearance).setFill()
        path.fill()
        DesignSystem.color(.borderSubtle, appearance: effectiveAppearance).setStroke()
        path.lineWidth = 1
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
            if state == .selected {
                DesignSystem.color(.borderSelected, appearance: effectiveAppearance).setStroke()
                path.lineWidth = 1
                path.stroke()
            }
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
        let side = min(16, rect.width, rect.height)
        let imageRect = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: enabled ? 1 : 0.45)
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
            image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: enabled ? 1 : 0.45)
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

    private func drawFocusRingIfNeeded() {
        guard window?.firstResponder == self, NSApp.isActive else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: DesignSystem.Metrics.controlRadius + 1, yRadius: DesignSystem.Metrics.controlRadius + 1)
        DesignSystem.color(.borderSelected, appearance: effectiveAppearance).setStroke()
        path.lineWidth = 2
        path.stroke()
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
}

enum DesignSystemControlStyler {
    static func styleButton(_ button: NSButton, destructive: Bool = false) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 13)
        ensureMinimumHeight(button)
        if destructive, #available(macOS 11.0, *) {
            button.hasDestructiveAction = true
        }
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
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 13)
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
            cell.isBordered = false
            cell.isBezeled = false
            cell.backgroundColor = .clear
        }
        field.wantsLayer = true
        field.layer?.cornerRadius = DesignSystem.Metrics.controlRadius
        field.layer?.borderWidth = 1
        field.layer?.backgroundColor = DesignSystem.semanticCGColor(.surfaceFlat, in: field)
        field.layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: field)
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
