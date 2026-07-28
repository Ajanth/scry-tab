import Cocoa

final class AccessibilityGuideOverlayController {
    private static let nudgeKey = "accessibilityGuideArrowNudge"
    private static let nudgeDistance = CGFloat(6)
    private static let panelWidth = CGFloat(300)

    private let panel: AccessibilityGuideOverlayPanel
    private let arrowView = NSImageView()
    private let onDismiss: () -> Void
    private var reduceMotionObserver: NSObjectProtocol?
    private var isVisible = false
    private var dockEdge: AccessibilityGuideOverlayLayout.DockEdge = .trailing
    private var rowStack: NSStackView?
    private var cardView: NSView?

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        panel = AccessibilityGuideOverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        configurePanel()
        configureArrow()
        panel.contentView = makeContentView()
        reduceMotionObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopNudge()
        }
    }

    deinit {
        tearDownObserversAndAnimations()
        panel.orderOut(nil)
    }

    func present(settingsFrame: CGRect, visibleFrame: CGRect, from sourceFrame: CGRect? = nil, animated: Bool) {
        let target = resolvedPlacement(settingsFrame: settingsFrame, visibleFrame: visibleFrame)
        if isVisible {
            panel.setFrame(target.frame, display: true)
            return
        }
        isVisible = true
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = 0
        panel.setFrame(shouldAnimate ? entranceFrame(target: target, sourceFrame: sourceFrame) : target.frame, display: false)
        panel.orderFront(nil)
        panel.setFrame(target.frame, display: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
        nudgeArrowOnce()
    }

    func updatePosition(settingsFrame: CGRect, visibleFrame: CGRect) {
        guard isVisible else {
            present(settingsFrame: settingsFrame, visibleFrame: visibleFrame, animated: false)
            return
        }
        let target = resolvedPlacement(settingsFrame: settingsFrame, visibleFrame: visibleFrame)
        panel.setFrame(target.frame, display: true)
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        stopNudge()
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
    }

    func close() {
        hide()
        tearDownObserversAndAnimations()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
    }

    private func configureArrow() {
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.wantsLayer = true
        if #available(macOS 10.14, *) {
            arrowView.contentTintColor = .labelColor
        }
        arrowView.setAccessibilityElement(false)
    }

    private func makeContentView() -> NSView {
        let column = NSStackView(views: [makeHeader(), makeInstruction(), AppBundleDragSourceView(), makeDismissButton()])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = DesignSystem.Metrics.sectionGap
        column.translatesAutoresizingMaskIntoConstraints = false
        column.widthAnchor.constraint(equalToConstant: Self.panelWidth).isActive = true
        column.arrangedSubviews.forEach { $0.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true }
        let padded = NSView()
        padded.translatesAutoresizingMaskIntoConstraints = false
        padded.addSubview(column)
        let pad = DesignSystem.Metrics.formOuterPadding
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: padded.topAnchor, constant: pad),
            column.leadingAnchor.constraint(equalTo: padded.leadingAnchor, constant: pad),
            column.trailingAnchor.constraint(equalTo: padded.trailingAnchor, constant: -pad),
            column.bottomAnchor.constraint(equalTo: padded.bottomAnchor, constant: -pad),
        ])
        let card = DesignSystemWindowContentView(content: padded)
        card.wantsLayer = true
        card.layer?.cornerRadius = DesignSystem.Metrics.windowRadius
        card.layer?.masksToBounds = true
        let row = NSStackView(views: [card])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DesignSystem.Metrics.headerFooterGap
        row.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        self.rowStack = row
        self.cardView = card
        return container
    }

    private func makeHeader() -> NSView {
        let title = BoldLabel(String(
            format: NSLocalizedString("Enable Accessibility for “%@”", comment: ""),
            App.displayName))
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor
        return title
    }

    private func makeInstruction() -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: String(
            format: NSLocalizedString(
                "Drag “%@” into the Accessibility list, or turn on its toggle in System Settings.",
                comment: ""),
            App.displayName))
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = Self.panelWidth
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    private func makeDismissButton() -> NSView {
        let button = DesignSystemControlStyler.makeButton(
            NSLocalizedString("Done", comment: ""),
            target: self,
            action: #selector(dismissClicked(_:)))
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.addView(button, in: .trailing)
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func layoutPanel() {
        guard let contentView = panel.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        panel.setContentSize(contentView.fittingSize)
    }

    /// Attach the arrow for the chosen edge, then measure so placement accounts for arrow width.
    private func resolvedPlacement(settingsFrame: CGRect, visibleFrame: CGRect) -> AccessibilityGuideOverlayLayout.Placement {
        layoutPanel()
        let target = placement(settingsFrame: settingsFrame, visibleFrame: visibleFrame)
        apply(edge: target.edge)
        layoutPanel()
        let sized = placement(settingsFrame: settingsFrame, visibleFrame: visibleFrame)
        guard sized.edge != target.edge else { return sized }
        apply(edge: sized.edge)
        layoutPanel()
        return placement(settingsFrame: settingsFrame, visibleFrame: visibleFrame)
    }

    private func placement(settingsFrame: CGRect, visibleFrame: CGRect) -> AccessibilityGuideOverlayLayout.Placement {
        let size = panel.frame.size.width > 0 ? panel.frame.size : (panel.contentView?.fittingSize ?? .zero)
        return AccessibilityGuideOverlayLayout.placement(
            panelSize: size,
            settingsFrame: settingsFrame,
            visibleFrame: visibleFrame,
            gap: DesignSystem.Metrics.formOuterPadding)
    }

    /// Rebuild the horizontal row so the arrow sits outside the card on the side facing Settings
    /// and points at the list. Docked trailing → leading-edge arrow pointing left; docked leading →
    /// trailing-edge arrow pointing right.
    private func apply(edge: AccessibilityGuideOverlayLayout.DockEdge) {
        guard let rowStack, let cardView, edge != dockEdge || arrowView.superview == nil else { return }
        dockEdge = edge
        arrowView.image = Self.caretImage(pointingRight: edge == .leading)
        arrowView.fit(arrowView.image?.size.width ?? 0, arrowView.image?.size.height ?? 0)
        arrowView.removeFromSuperview()
        rowStack.removeArrangedSubview(cardView)
        let ordered = edge == .leading ? [cardView, arrowView] : [arrowView, cardView]
        ordered.forEach { rowStack.addArrangedSubview($0) }
    }

    private func entranceFrame(target: AccessibilityGuideOverlayLayout.Placement, sourceFrame: CGRect?) -> CGRect {
        if let sourceFrame {
            let size = target.frame.size
            return CGRect(x: sourceFrame.midX - size.width * 0.5, y: sourceFrame.midY - size.height * 0.5, width: size.width, height: size.height)
        }
        let offset = target.edge == .leading ? -Self.nudgeDistance * 4 : Self.nudgeDistance * 4
        return target.frame.offsetBy(dx: offset, dy: 0)
    }

    private func nudgeArrowOnce() {
        stopNudge()
        guard isVisible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let layer = arrowView.layer else { return }
        arrowView.layoutSubtreeIfNeeded()
        let base = layer.position.x
        let direction = dockEdge == .leading ? Self.nudgeDistance : -Self.nudgeDistance
        let animation = CAKeyframeAnimation(keyPath: "position.x")
        animation.values = [0, 1, 0, 0.6, 0].map { NSNumber(value: Double(base + direction * $0)) }
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        animation.duration = 0.9
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: Self.nudgeKey)
    }

    private func stopNudge() {
        arrowView.layer?.removeAnimation(forKey: Self.nudgeKey)
    }

    private func tearDownObserversAndAnimations() {
        stopNudge()
        if let reduceMotionObserver {
            NotificationCenter.default.removeObserver(reduceMotionObserver)
            self.reduceMotionObserver = nil
        }
    }

    /// Stroked chevron matching disclosure-caret metrics, oriented toward the Settings list.
    private static func caretImage(pointingRight: Bool) -> NSImage {
        let metrics = DesignSystem.Metrics.self
        let width = metrics.disclosureCaretHeight + 2
        let height = metrics.disclosureCaretWidth + 4
        let stroke = metrics.disclosureCaretStrokeWidth
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = stroke / 2
            let caretRect = rect.insetBy(dx: inset, dy: inset)
            let path = NSBezierPath()
            if pointingRight {
                path.move(to: NSPoint(x: caretRect.minX, y: caretRect.minY))
                path.line(to: NSPoint(x: caretRect.maxX, y: caretRect.midY))
                path.line(to: NSPoint(x: caretRect.minX, y: caretRect.maxY))
            } else {
                path.move(to: NSPoint(x: caretRect.maxX, y: caretRect.minY))
                path.line(to: NSPoint(x: caretRect.minX, y: caretRect.midY))
                path.line(to: NSPoint(x: caretRect.maxX, y: caretRect.maxY))
            }
            path.lineWidth = stroke
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func dismissClicked(_ sender: Any?) {
        onDismiss()
    }
}

private final class AccessibilityGuideOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
