import Cocoa

class ImageTextButtonView: NSStackView {
    class ImageButton: NSButton {
        private var cardCornerRadius: CGFloat {
            return (superview as? ImageTextButtonView)?.buttonCornerRadius ?? ImageTextButtonView.cornerRadius
        }

        override var focusRingMaskBounds: NSRect {
            return bounds
        }

        override func drawFocusRingMask() {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                xRadius: cardCornerRadius, yRadius: cardCornerRadius)
            path.fill()
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            if window?.firstResponder == self && NSApp.isActive {
                NSColor.keyboardFocusIndicatorColor.setStroke()
                let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                    xRadius: cardCornerRadius, yRadius: cardCornerRadius)
                path.lineWidth = 2.0
                path.stroke()
            }
        }

        override func mouseDown(with event: NSEvent) {
            let parent = superview as? ImageTextButtonView
            parent?.isPressed = true
            parent?.updateStyle()
            // NSButton.mouseDown blocks until the click is released or canceled.
            super.mouseDown(with: event)
            parent?.isPressed = false
            parent?.updateStyle()
        }
    }

    /// Pass-through label: the click should activate the parent style tile, not the label itself.
    /// Returning `nil` from `hitTest` lets the click bubble up to `ImageTextButtonView.mouseDown`.
    /// `mouseDownCanMoveWindow=false` is required because `SettingsWindow.isMovableByWindowBackground`
    /// would otherwise drag the window from a label hit (NSTextField labels return `true` by default).
    class ClickableLabel: NSTextField {
        override var mouseDownCanMoveWindow: Bool { false }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    static let spacing = CGFloat(7)
    static let cornerRadius = DesignSystem.Metrics.joinedOuterRowRadius
    static let tileCornerRadius = DesignSystem.Metrics.sectionRadius
    static let borderWidth = CGFloat(1)
    static let selectedBorderWidth = CGFloat(2)
    static let outerPadding = CGFloat(4)
    static let previewInset = CGFloat(3)
    static let labelTopSpacing = CGFloat(8)

    var onClick: ActionClosure?
    var button: NSButton!
    var label: NSTextField!
    fileprivate(set) var isPressed = false
    private var imageContainer: NSView!
    private var imageView: NSImageView!
    private var baseCornerRadius = ImageTextButtonView.cornerRadius
    private var windowObservers = [NSObjectProtocol]()

    var state: NSControl.StateValue = .off {
        didSet {
            button.state = state
            updateStyle()
        }
    }

    init(title: String, rawName: String, image: WidthHeightImage,
         state: NSControl.StateValue = .off,
         spacing: CGFloat = ImageTextButtonView.spacing,
         cornerRadius: CGFloat = ImageTextButtonView.cornerRadius) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .centerX
        self.spacing = spacing
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = ImageTextButtonView.tileCornerRadius
        layer?.masksToBounds = false
        baseCornerRadius = cornerRadius
        makeButton(rawName, state, image, cornerRadius: cornerRadius)
        makeLabel(title)
        self.state = state
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func makeButton(_ rawName: String, _ state: NSControl.StateValue, _ image: WidthHeightImage,
                            cornerRadius: CGFloat = ImageTextButtonView.cornerRadius) {
        button = ImageButton(radioButtonWithTitle: "", target: nil, action: nil)
        button.imagePosition = .imageOnly
        button.focusRingType = .default
        button.translatesAutoresizingMaskIntoConstraints = false
        button.wantsLayer = true
        button.layer?.cornerRadius = max(cornerRadius + 2, DesignSystem.Metrics.controlRadius + 2)
        button.layer?.borderWidth = ImageTextButtonView.borderWidth
        button.state = state
        addArrangedSubview(button)
        imageContainer = NSView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.wantsLayer = true
        imageContainer.layer?.masksToBounds = true
        imageContainer.layer?.cornerRadius = previewCornerRadius
        imageView = NSImageView(image: NSImage(named: image.name + "_light")!)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = previewCornerRadius
        imageContainer.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
        ])
        button.addSubview(imageContainer)
        let imageAspectRatio = image.height / image.width
        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: button.topAnchor, constant: ImageTextButtonView.previewInset),
            imageContainer.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -ImageTextButtonView.previewInset),
            imageContainer.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: ImageTextButtonView.previewInset),
            imageContainer.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -ImageTextButtonView.previewInset),
            button.topAnchor.constraint(equalTo: topAnchor, constant: ImageTextButtonView.outerPadding),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: ImageTextButtonView.outerPadding),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -ImageTextButtonView.outerPadding),
            button.heightAnchor.constraint(equalTo: button.widthAnchor, multiplier: imageAspectRatio),
        ])
        button.identifier = NSUserInterfaceItemIdentifier(rawName)
        button.onAction = { control in
            self.state = .on
            self.onClick?(control)
        }
    }

    private func makeLabel(_ labelText: String) {
        label = ClickableLabel(labelWithString: labelText)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addArrangedSubview(label)
        setCustomSpacing(ImageTextButtonView.labelTopSpacing, after: button)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateStyle()
        var fired = false
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            if next.type == .leftMouseUp {
                let p = convert(next.locationInWindow, from: nil)
                if bounds.contains(p) { fired = true }
                break
            }
        }
        isPressed = false
        updateStyle()
        if fired { button.performClick(nil) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                self?.updateStyle()
            })
        }
        windowObservers.append(NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateStyle()
        })
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        updateStyle()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private var buttonCornerRadius: CGFloat {
        return max(baseCornerRadius + 2, DesignSystem.Metrics.controlRadius + 2)
    }

    private var previewCornerRadius: CGFloat {
        return max(buttonCornerRadius - ImageTextButtonView.previewInset, DesignSystem.Metrics.controlRadius + 1)
    }

    private func mixedColor(_ base: NSColor, _ accent: NSColor, fraction: CGFloat) -> NSColor {
        return base.blended(withFraction: fraction, of: accent) ?? base
    }

    func updateStyle() {
        let isSelected = button.state == .on
        let isKey = window?.isKeyWindow ?? false
        let isDark = DesignSystem.isDark(effectiveAppearance)
        let accent = DesignSystem.color(.accentPrimary, appearance: effectiveAppearance)
        let surfaceFlat = DesignSystem.color(.surfaceFlat, appearance: effectiveAppearance)
        let surfaceSelected = DesignSystem.color(.surfaceSelected, appearance: effectiveAppearance)
        let fillColor = isSelected ? mixedColor(surfaceSelected, accent.withAlphaComponent(isDark ? 0.82 : 0.68), fraction: isDark ? 0.32 : 0.18) : surfaceFlat
        let borderColor = isSelected ? mixedColor(DesignSystem.color(.borderSelected, appearance: effectiveAppearance), accent, fraction: 0.28) : DesignSystem.color(.borderSubtle, appearance: effectiveAppearance)
        let tileFillColor = isSelected ? accent.withAlphaComponent(isDark ? 0.13 : 0.08) : .clear
        let tileBorderColor = isSelected ? accent.withAlphaComponent(isDark ? 0.42 : 0.24) : .clear
        layer?.backgroundColor = DesignSystem.resolvedCGColor(tileFillColor, in: self)
        layer?.borderColor = DesignSystem.resolvedCGColor(tileBorderColor, in: self)
        layer?.borderWidth = isSelected ? 1 : 0
        layer?.shadowColor = DesignSystem.resolvedCGColor(accent.withAlphaComponent(isDark ? 0.28 : 0.18), in: self)
        layer?.shadowOpacity = isSelected ? 1 : 0
        layer?.shadowRadius = isSelected ? (isPressed ? 6 : 10) : 0
        layer?.shadowOffset = .zero
        button.layer?.cornerRadius = buttonCornerRadius
        button.layer?.backgroundColor = DesignSystem.resolvedCGColor(fillColor, in: self)
        button.layer?.borderColor = DesignSystem.resolvedCGColor(borderColor, in: self)
        button.layer?.borderWidth = isSelected ? ImageTextButtonView.selectedBorderWidth : ImageTextButtonView.borderWidth
        imageContainer.layer?.cornerRadius = previewCornerRadius
        imageView.layer?.cornerRadius = previewCornerRadius
        label.textColor = isSelected ? DesignSystem.color(.textPrimary, appearance: effectiveAppearance) : DesignSystem.color(.textSecondary, appearance: effectiveAppearance)
        label.font = NSFont.systemFont(ofSize: 12, weight: isSelected ? .semibold : .medium)
        alphaValue = isPressed ? 0.84 : (isKey ? 1.0 : 0.96)
    }
}
