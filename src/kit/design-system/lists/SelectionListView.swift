import Cocoa

final class SelectionListView: NSStackView {
    private(set) var rows = [SelectionListItemView]()
    var selectedIdentifier: String? {
        didSet { refreshSelection() }
    }
    var onSelect: ((String) -> Void)?

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = DesignMetric.listStackGap
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func setRows(_ rows: [SelectionListItemView]) {
        arrangedSubviews.forEach { removeArrangedSubview($0); $0.removeFromSuperview() }
        self.rows = rows
        rows.forEach(addConfiguredRow)
        refreshSelection()
    }

    private func addConfiguredRow(_ row: SelectionListItemView) {
        row.onSelect = { [weak self, weak row] in
            guard let self, let row else { return }
            selectedIdentifier = row.identifierValue
            onSelect?(row.identifierValue)
        }
        addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    }

    private func refreshSelection() {
        rows.forEach { $0.isSelected = $0.identifierValue == selectedIdentifier }
    }
}

final class SelectionListItemView: NSView {
    let identifierValue: String
    var onSelect: (() -> Void)?
    var isSelected = false {
        didSet { updateStyle() }
    }
    private let surface = MaterialSurfaceView(role: .selection)
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let textStack = NSStackView()
    private var isHovered = false

    init(identifier: String, title: String, subtitle: String? = nil, image: NSImage? = nil, rich: Bool = false) {
        identifierValue = identifier
        super.init(frame: .zero)
        setupView(rich: rich)
        setContent(title: title, subtitle: subtitle, image: image)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var acceptsFirstResponder: Bool { true }

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
        window?.makeFirstResponder(self)
        onSelect?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 {
            onSelect?()
        } else {
            super.keyDown(with: event)
        }
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    func setContent(title: String, subtitle: String?, image: NSImage?) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.isHidden = subtitle?.isEmpty ?? true
        iconView.image = image
        iconView.isHidden = image == nil
        toolTip = subtitle == nil ? title : "\(title)\n\(subtitle!)"
    }

    private func setupView(rich: Bool) {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setupChildren()
        let height = rich ? DesignMetric.richListRowHeight : DesignMetric.standardListRowHeight
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignMetric.listItemHorizontalPadding),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: rich ? DesignMetric.richListItemIconSize : DesignMetric.listItemIconSize),
            iconView.heightAnchor.constraint(equalToConstant: rich ? DesignMetric.richListItemIconSize : DesignMetric.listItemIconSize),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DesignMetric.listItemIconTextGap),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignMetric.listItemHorizontalPadding),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        updateStyle()
    }

    private func setupChildren() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        titleLabel.font = DesignTypography.rowTitle
        subtitleLabel.font = DesignTypography.footnoteText
        subtitleLabel.textColor = .secondaryLabelColor
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = DesignMetric.compactTextStackGap
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        addSubview(surface)
        addSubview(iconView)
        addSubview(textStack)
    }

    private func updateStyle() {
        surface.componentState = DesignComponentState(isEnabled: true, isPressed: false, isSelected: isSelected, isHovered: isHovered, isFocused: window?.firstResponder == self)
        titleLabel.font = isSelected ? DesignTypography.rowTitleEmphasized : DesignTypography.rowTitle
    }
}
