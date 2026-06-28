import Cocoa

class SurfaceButton: NSButton {
    var surfaceRole = DesignSurfaceRole.flat {
        didSet { updateStyle() }
    }
    private var isHovered = false
    private var isPressed = false

    convenience init(title: String, role: DesignSurfaceRole = .flat, action: ActionClosure? = nil) {
        self.init(title: title, target: nil, action: nil)
        surfaceRole = role
        onAction = action
        setupButton()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var isEnabled: Bool {
        didSet { updateStyle() }
    }

    override var state: NSControl.StateValue {
        didSet { updateStyle() }
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        updateStyle()
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        updateStyle()
        return result
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateStyle()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateStyle()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateStyle()
        super.mouseDown(with: event)
        isPressed = false
        updateStyle()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private func setupButton() {
        translatesAutoresizingMaskIntoConstraints = false
        bezelStyle = .regularSquare
        isBordered = false
        wantsLayer = true
        layer?.masksToBounds = true
        font = DesignTypography.rowTitleEmphasized
        heightAnchor.constraint(greaterThanOrEqualToConstant: DesignMetric.standardControlMinHeight).isActive = true
        updateStyle()
    }

    private func updateStyle() {
        let component = DesignComponentState(isEnabled: isEnabled, isPressed: isPressed, isSelected: state == .on, isHovered: isHovered, isFocused: window?.firstResponder == self)
        let environment = DesignSystemEnvironment.current(for: self)
        let style = DesignSurfaceStyle.resolve(role: surfaceRole, state: component, environment: environment)
        DesignSystemColors.withAppearance(currentAppearance) {
            layer?.cornerRadius = style.cornerRadius
            layer?.backgroundColor = DesignSystemColors.color(style.fillRole, environment: environment).cgColor
            layer?.borderWidth = max(style.borderWidth, style.focusRingWidth)
            layer?.borderColor = (style.focusRingRole ?? style.borderRole).map { DesignSystemColors.color($0, environment: environment).cgColor }
            if #available(macOS 10.14, *) {
                contentTintColor = isEnabled ? DesignSystemColors.color(.textPrimary, environment: environment) : DesignSystemColors.color(.textDisabled, environment: environment)
            }
        }
    }

    private var currentAppearance: NSAppearance {
        if #available(macOS 10.14, *) { return effectiveAppearance }
        return NSAppearance(named: .aqua)!
    }
}

final class CompactPicker: NSPopUpButton {
    convenience init(items: [String], selectedIndex: Int = 0, action: ActionClosure? = nil) {
        self.init(frame: .zero, pullsDown: false)
        translatesAutoresizingMaskIntoConstraints = false
        addItems(withTitles: items)
        if !items.isEmpty {
            selectItem(at: max(0, min(selectedIndex, items.count - 1)))
        }
        controlSize = .small
        onAction = action
        heightAnchor.constraint(greaterThanOrEqualToConstant: DesignMetric.standardControlMinHeight).isActive = true
    }
}

final class SegmentedPicker: NSStackView {
    let control: NSSegmentedControl

    init(items: [String], selectedIndex: Int = 0, action: ActionClosure? = nil) {
        control = NSSegmentedControl(labels: items, trackingMode: .selectOne, target: nil, action: nil)
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        if !items.isEmpty {
            control.selectedSegment = max(0, min(selectedIndex, items.count - 1))
        }
        control.onAction = action
        addArrangedSubview(control)
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignMetric.standardControlMinHeight).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }
}

final class ChoiceCardView: SurfaceButton {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let textStack = NSStackView()

    init(title: String, subtitle: String? = nil, image: NSImage? = nil, action: ActionClosure? = nil) {
        super.init(frame: .zero)
        self.title = ""
        surfaceRole = .plateau
        onAction = action
        setupCard()
        setContent(title: title, subtitle: subtitle, image: image)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func setContent(title: String, subtitle: String?, image: NSImage?) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.isHidden = subtitle?.isEmpty ?? true
        iconView.image = image
        iconView.isHidden = image == nil
        toolTip = subtitle == nil ? title : "\(title)\n\(subtitle!)"
    }

    private func setupCard() {
        alignment = .natural
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleLabel.font = DesignTypography.rowTitleEmphasized
        subtitleLabel.font = DesignTypography.supportingText
        subtitleLabel.textColor = .secondaryLabelColor
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = DesignMetric.choiceCardTextGap
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        addSubview(iconView)
        addSubview(textStack)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignMetric.choiceCardOuterPadding),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: DesignMetric.choiceCardIconSize),
            iconView.heightAnchor.constraint(equalToConstant: DesignMetric.choiceCardIconSize),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: DesignMetric.choiceCardVerticalPadding),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DesignMetric.choiceCardIconTextGap),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignMetric.choiceCardOuterPadding),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignMetric.choiceCardVerticalPadding),
        ])
    }
}

final class ChoicePickerView: NSStackView {
    private(set) var cards = [ChoiceCardView]()
    private var selectedIndex = 0

    init(cards: [ChoiceCardView], selectedIndex: Int = 0) {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .top
        distribution = .fillEqually
        spacing = DesignMetric.choicePickerGap
        translatesAutoresizingMaskIntoConstraints = false
        setCards(cards, selectedIndex: selectedIndex)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func setCards(_ cards: [ChoiceCardView], selectedIndex: Int) {
        arrangedSubviews.forEach { removeArrangedSubview($0); $0.removeFromSuperview() }
        self.cards = cards
        self.selectedIndex = max(0, min(selectedIndex, max(0, cards.count - 1)))
        for (index, card) in cards.enumerated() {
            card.setButtonType(.toggle)
            card.onAction = { [weak self] _ in self?.select(index) }
            addArrangedSubview(card)
        }
        refreshSelection()
    }

    func select(_ index: Int) {
        selectedIndex = max(0, min(index, max(0, cards.count - 1)))
        refreshSelection()
    }

    private func refreshSelection() {
        for (index, card) in cards.enumerated() {
            card.state = index == selectedIndex ? .on : .off
        }
    }
}

final class SurfaceTextField: NSTextField {
    convenience init(placeholder: String = "") {
        self.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        placeholderString = placeholder
        isBordered = false
        isBezeled = false
        drawsBackground = true
        wantsLayer = true
        font = DesignTypography.rowTitle
        heightAnchor.constraint(greaterThanOrEqualToConstant: DesignMetric.standardControlMinHeight).isActive = true
        updateStyle()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private func updateStyle() {
        let environment = DesignSystemEnvironment.current(for: self)
        DesignSystemColors.withAppearance(currentAppearance) {
            backgroundColor = DesignSystemColors.color(.surfaceFlat, environment: environment)
            textColor = DesignSystemColors.color(.textPrimary, environment: environment)
            layer?.cornerRadius = DesignMetric.joinedRowRadius
            layer?.borderWidth = 1
            layer?.borderColor = DesignSystemColors.color(.borderSubtle, environment: environment).cgColor
        }
    }

    private var currentAppearance: NSAppearance {
        if #available(macOS 10.14, *) { return effectiveAppearance }
        return NSAppearance(named: .aqua)!
    }
}

final class SurfaceTextEditor: NSScrollView {
    let textView = NSTextView()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        hasVerticalScroller = true
        hasHorizontalScroller = false
        drawsBackground = false
        borderType = .noBorder
        wantsLayer = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        documentView = textView
        heightAnchor.constraint(greaterThanOrEqualToConstant: DesignMetric.textEditorMinHeight).isActive = true
        updateStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private func updateStyle() {
        let environment = DesignSystemEnvironment.current(for: self)
        DesignSystemColors.withAppearance(currentAppearance) {
            layer?.cornerRadius = DesignMetric.joinedRowRadius
            layer?.borderWidth = 1
            layer?.borderColor = DesignSystemColors.color(.borderSubtle, environment: environment).cgColor
            textView.backgroundColor = DesignSystemColors.color(.surfaceFlat, environment: environment)
            textView.textColor = DesignSystemColors.color(.textPrimary, environment: environment)
        }
    }

    private var currentAppearance: NSAppearance {
        if #available(macOS 10.14, *) { return effectiveAppearance }
        return NSAppearance(named: .aqua)!
    }
}

final class ShortcutRecorderRow: SettingsRowView {
    init(title: String, recorder: NSView, subtitle: String? = nil) {
        super.init(title: title, subtitle: subtitle, content: [recorder])
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }
}
