import Cocoa

final class SettingsFormView: NSStackView {
    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = DesignMetric.sectionGap
        edgeInsets = NSEdgeInsets(top: DesignMetric.formOuterPadding, left: DesignMetric.formOuterPadding, bottom: DesignMetric.formOuterPadding, right: DesignMetric.formOuterPadding)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func addSection(_ section: SettingsSectionView) {
        addArrangedSubview(section)
        section.leadingAnchor.constraint(equalTo: leadingAnchor, constant: edgeInsets.left).isActive = true
        section.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -edgeInsets.right).isActive = true
    }
}

final class SettingsSectionView: NSStackView {
    private let headerLabel = NSTextField(labelWithString: "")
    private let footerLabel = NSTextField(wrappingLabelWithString: "")
    private let rowsStack = NSStackView()
    private let surface = MaterialSurfaceView(role: .plateau)

    init(title: String? = nil, footer: String? = nil) {
        super.init(frame: .zero)
        setupView()
        setTitle(title)
        setFooter(footer)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func setTitle(_ title: String?) {
        headerLabel.stringValue = title ?? ""
        headerLabel.isHidden = title?.isEmpty ?? true
    }

    func setFooter(_ footer: String?) {
        footerLabel.stringValue = footer ?? ""
        footerLabel.isHidden = footer?.isEmpty ?? true
    }

    func addRow(_ row: SettingsRowView) {
        rowsStack.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: rowsStack.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor).isActive = true
    }

    private func setupView() {
        orientation = .vertical
        alignment = .leading
        spacing = DesignMetric.sectionHeaderFooterGap
        translatesAutoresizingMaskIntoConstraints = false
        setupLabels()
        setupRows()
    }

    private func setupLabels() {
        headerLabel.font = DesignTypography.sectionHeader
        headerLabel.textColor = .secondaryLabelColor
        footerLabel.font = DesignTypography.footnoteText
        footerLabel.textColor = .secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        addArrangedSubview(headerLabel)
    }

    private func setupRows() {
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 0
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        surface.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(rowsStack)
        addArrangedSubview(surface)
        addArrangedSubview(footerLabel)
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: surface.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
        ])
    }
}

class SettingsRowView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    let contentStack = NSStackView()
    /// Stable identifier shared with the matching `SettingsSearchDescriptor`, set by
    /// `registerFocusAnchor`. `SettingsWindow.resolvePendingFocusAnchor` uses it to scroll,
    /// highlight, and focus the row after a search-result navigation.
    var anchorIdentifier: String?
    /// Optional control to make first responder when this row receives search focus. Pages set
    /// this to the recorder/field/switch they want keyboard users to land on.
    var focalControl: NSView?
    private let textStack = NSStackView()
    private let separator = NSBox()

    init(title: String, subtitle: String? = nil, content: [NSView] = [], showsSeparator: Bool = true) {
        super.init(frame: .zero)
        setupView()
        setText(title: title, subtitle: subtitle)
        setContent(content)
        separator.isHidden = !showsSeparator
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func setText(title: String, subtitle: String?) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.isHidden = subtitle?.isEmpty ?? true
        toolTip = subtitle == nil ? title : "\(title)\n\(subtitle!)"
    }

    func setContent(_ views: [NSView]) {
        contentStack.setViews(views, in: .leading)
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        setupText()
        setupContent()
        setupSeparator()
        let spacer = NSView()
        addSubview(textStack)
        addSubview(contentStack)
        addSubview(spacer)
        addSubview(separator)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: DesignMetric.standardControlMinHeight + DesignMetric.rowVerticalPadding * 2),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: DesignMetric.rowVerticalPadding),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignMetric.rowHorizontalPadding),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -DesignMetric.rowVerticalPadding),
            spacer.leadingAnchor.constraint(equalTo: textStack.trailingAnchor, constant: DesignMetric.rowContentGap),
            spacer.trailingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: -DesignMetric.rowContentGap),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignMetric.rowHorizontalPadding),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignMetric.rowHorizontalPadding),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupText() {
        titleLabel.font = DesignTypography.rowTitle
        subtitleLabel.font = DesignTypography.supportingText
        subtitleLabel.textColor = .secondaryLabelColor
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = DesignMetric.compactTextStackGap
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
    }

    private func setupContent() {
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = DesignMetric.rowContentGap
        contentStack.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupSeparator() {
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
    }
}

final class SettingsToggleRow: SettingsRowView {
    let toggle: Switch

    init(title: String, subtitle: String? = nil, isOn: Bool = false, action: ActionClosure? = nil) {
        toggle = Switch(isOn)
        super.init(title: title, subtitle: subtitle, content: [toggle])
        toggle.onAction = action
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }
}
