import Cocoa

final class AppBundleDragSourceView: NSView, NSDraggingSource, NSPasteboardItemDataProvider {
    private let rowView = NSStackView()
    private var isDragging = false
    private var mouseUpMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        removeMouseUpMonitor()
        restoreMouseEvents()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isDragging { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setDataProvider(self, forTypes: [.fileURL])
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(draggingFrame(), contents: draggingImage())
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        DesignSystemControlStyler.refreshSurface(rowView)
    }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        guard type == .fileURL else { return }
        item.setData(App.bundleURL.dataRepresentation, forType: .fileURL)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        isDragging = true
        rowView.isHidden = true
        // Let drops land in System Settings behind this floating guide.
        window?.ignoresMouseEvents = true
        installMouseUpMonitor()
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        finishDragging()
        SystemPermissions.recheckNow()
    }

    private func finishDragging() {
        removeMouseUpMonitor()
        isDragging = false
        rowView.isHidden = false
        restoreMouseEvents()
    }

    private func restoreMouseEvents() {
        window?.ignoresMouseEvents = false
    }

    /// Global mouse-up catches the case where the session end callback is delayed or missed,
    /// which would otherwise leave Done untouchable. Deferred so the drop can finish first.
    private func installMouseUpMonitor() {
        removeMouseUpMonitor()
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.finishDragging()
            }
        }
    }

    private func removeMouseUpMonitor() {
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
            self.mouseUpMonitor = nil
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        rowView.orientation = .horizontal
        rowView.alignment = .centerY
        rowView.spacing = DesignSystem.Metrics.formOuterPadding
        rowView.edgeInsets = NSEdgeInsets(
            top: TableGroupView.rowVerticalPadding,
            left: TableGroupView.rowHorizontalPadding,
            bottom: TableGroupView.rowVerticalPadding,
            right: TableGroupView.rowHorizontalPadding)
        rowView.translatesAutoresizingMaskIntoConstraints = false
        let iconSize = NSSize(width: 22, height: 22)
        let icon = NSImageView(image: App.appIcon(for: iconSize).nsImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.fit(iconSize.width, iconSize.height)
        let label = NSTextField(labelWithString: App.displayName)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rowView.addArrangedSubview(icon)
        rowView.addArrangedSubview(label)
        addSubview(rowView)
        DesignSystemControlStyler.styleSurface(rowView)
        NSLayoutConstraint.activate([
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowView.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowView.heightAnchor.constraint(greaterThanOrEqualToConstant: TableGroupView.minimumRowHeight),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(String(
            format: NSLocalizedString("Drag “%@” into the Accessibility list", comment: ""),
            App.displayName))
    }

    private func draggingFrame() -> NSRect {
        return convert(rowView.bounds, from: rowView)
    }

    private func draggingImage() -> NSImage {
        let size = rowView.bounds.size
        guard size.width > 0, size.height > 0 else { return NSImage(size: NSSize(width: 1, height: 1)) }
        return NSImage(size: size, flipped: false) { [weak self] rect in
            guard let self, let context = NSGraphicsContext.current else { return false }
            self.rowView.displayIgnoringOpacity(self.rowView.bounds, in: context)
            return true
        }
    }
}
