import Cocoa

class ExceptionEditorView: NSView {
    private var entry: ExceptionEntry = ExceptionEntry(bundleIdentifier: "", hide: .none, ignore: .none, windowTitleContains: nil)
    private var onChange: ((ExceptionEntry) -> Void)?
    /// Last bundle ID for which the header (icon + name) has been fully resolved. Used to avoid
    /// the placeholder-then-fetch flash when binding to a different entry that happens to share
    /// the same bundle ID, or when refreshing for non-bundle-id edits.
    private var resolvedHeaderBundleId: String?

    private let outerStack = NSStackView()
    private let headerIconView = NSImageView()
    private let headerNameLabel = NSTextField(labelWithString: "")
    private let bundleIdField = NSTextField(string: "")
    private let hideDropdown = PopupButtonLikeSystemSettings()
    private let ignoreDropdown = PopupButtonLikeSystemSettings()
    private var patternsRow: NSView?
    private var patternsListStack = NSStackView()
    private var behaviorGroup: NSStackView!
    private var accessibilityObserver: NSObjectProtocol?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupLayout()
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshDesignSystemLayers()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        refreshDesignSystemLayers()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshDesignSystemLayers()
    }

    private func refreshDesignSystemLayers() {
        DesignSystemControlStyler.refreshSurface(behaviorGroup)
        DesignSystemControlStyler.refreshEditableFields(in: self)
    }

    func bind(to entry: ExceptionEntry, onChange: @escaping (ExceptionEntry) -> Void) {
        self.entry = entry
        self.onChange = onChange
        outerStack.isHidden = false
        refreshFromEntry()
    }

    func clear() {
        outerStack.isHidden = true
    }

    private func setupLayout() {
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 18
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        let header = makeHeader()
        let group = makeBehaviorGroup()

        outerStack.addArrangedSubview(header)
        outerStack.addArrangedSubview(group)

        addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            // Force the behavior group to fill the editor's full width so its rows can extend
            // to the right edge. NSStackView's .leading alignment leaves it at intrinsic width
            // otherwise.
            group.trailingAnchor.constraint(equalTo: outerStack.trailingAnchor),
        ])
    }

    private func makeHeader() -> NSView {
        headerIconView.translatesAutoresizingMaskIntoConstraints = false
        headerIconView.imageScaling = .scaleProportionallyUpOrDown
        headerIconView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        headerIconView.heightAnchor.constraint(equalToConstant: 56).isActive = true

        headerNameLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        headerNameLabel.lineBreakMode = .byTruncatingTail

        let row = NSStackView(views: [headerIconView, headerNameLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func makeBehaviorGroup() -> NSStackView {
        let group = NSStackView()
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = 0
        group.distribution = .fill
        group.translatesAutoresizingMaskIntoConstraints = false
        DesignSystemControlStyler.styleSurface(group)
        behaviorGroup = group

        let bundleRow = makeBundleIdRow()
        let hideRow = makeHideRow()
        let patternsRow = makePatternsRow()
        let ignoreRow = makeIgnoreRow()
        self.patternsRow = patternsRow

        addToGroup(group, view: bundleRow, addSeparator: false)
        addToGroup(group, view: hideRow, addSeparator: true)
        group.addArrangedSubview(patternsRow)
        patternsRow.leadingAnchor.constraint(equalTo: group.leadingAnchor).isActive = true
        patternsRow.trailingAnchor.constraint(equalTo: group.trailingAnchor).isActive = true
        addToGroup(group, view: ignoreRow, addSeparator: true)
        return group
    }

    private func addToGroup(_ group: NSStackView, view: NSView, addSeparator: Bool) {
        if addSeparator {
            let sep = makeSeparator()
            group.addArrangedSubview(sep)
            sep.leadingAnchor.constraint(equalTo: group.leadingAnchor).isActive = true
            sep.trailingAnchor.constraint(equalTo: group.trailingAnchor).isActive = true
        }
        group.addArrangedSubview(view)
        view.leadingAnchor.constraint(equalTo: group.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: group.trailingAnchor).isActive = true
    }

    private func makeSeparator() -> NSView {
        let sep = DesignSystemDividerView()
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return sep
    }

    private func makeBundleIdRow() -> NSView {
        let label = makeRowLabel(NSLocalizedString("Bundle ID", comment: ""))
        bundleIdField.translatesAutoresizingMaskIntoConstraints = false
        bundleIdField.placeholderString = NSLocalizedString("e.g. com.example.app", comment: "")
        bundleIdField.cell?.sendsActionOnEndEditing = true
        bundleIdField.target = self
        bundleIdField.action = #selector(bundleIdChanged(_:))
        bundleIdField.lineBreakMode = .byTruncatingHead
        bundleIdField.usesSingleLineMode = true
        DesignSystemControlStyler.styleTextField(bundleIdField)
        return makeRow(label: label, control: bundleIdField, controlMinWidth: 200)
    }

    private func makeHideRow() -> NSView {
        let label = makeRowLabel(NSLocalizedString("Hide windows", comment: ""))
        hideDropdown.translatesAutoresizingMaskIntoConstraints = false
        hideDropdown.removeAllItems()
        hideDropdown.addItems(withTitles: ExceptionHidePreference.allCases.map { c -> String in
            c == .none ? NSLocalizedString("Don't hide", comment: "") : c.localizedString
        })
        hideDropdown.target = self
        hideDropdown.action = #selector(hideChanged(_:))
        return makeRow(label: label, control: hideDropdown)
    }

    private func makeIgnoreRow() -> NSView {
        let label = makeRowLabel(NSLocalizedString("Ignore shortcuts", comment: ""))
        ignoreDropdown.translatesAutoresizingMaskIntoConstraints = false
        ignoreDropdown.removeAllItems()
        ignoreDropdown.addItems(withTitles: ExceptionIgnorePreference.allCases.map { c -> String in
            c == .none ? NSLocalizedString("Never", comment: "") : c.localizedString
        })
        ignoreDropdown.target = self
        ignoreDropdown.action = #selector(ignoreChanged(_:))
        return makeRow(label: label, control: ignoreDropdown)
    }

    private func makePatternsRow() -> NSView {
        patternsListStack.orientation = .vertical
        patternsListStack.alignment = .leading
        patternsListStack.spacing = TableGroupView.rowVerticalPadding
        patternsListStack.translatesAutoresizingMaskIntoConstraints = false

        let addButton = DesignSystemControlStyler.makeButton(NSLocalizedString("Add a pattern", comment: ""), target: self, action: #selector(addPatternTapped))
        addButton.image = NSImage.fromSymbol(.plus, pointSize: 11)
        addButton.imagePosition = .imageLeading

        let column = NSStackView(views: [patternsListStack, addButton])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = TableGroupView.rowVerticalPadding
        column.translatesAutoresizingMaskIntoConstraints = false
        // Indent under "Hide windows" to signify the hierarchy.
        column.edgeInsets = NSEdgeInsets(top: TableGroupView.rowIntraSpacing, left: TableGroupView.nestedContentIndent, bottom: TableGroupView.rowHorizontalPadding, right: TableGroupView.rowHorizontalPadding)
        return column
    }

    private func rebuildPatternsList() {
        patternsListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let initial = entry.windowTitleContains ?? []
        if initial.isEmpty {
            patternsListStack.addArrangedSubview(makePatternFieldRow(initial: ""))
        } else {
            for p in initial {
                patternsListStack.addArrangedSubview(makePatternFieldRow(initial: p))
            }
        }
    }

    private func makePatternFieldRow(initial: String) -> NSView {
        let field = NSTextField(string: initial)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholderString = NSLocalizedString("e.g. Debug", comment: "")
        field.delegate = self
        field.usesSingleLineMode = true
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        DesignSystemControlStyler.styleTextField(field)

        let removeButton = NSButton()
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.isBordered = false
        removeButton.image = NSImage.fromSymbol(.minusCircleFill, pointSize: 14)
        if #available(macOS 10.14, *) { removeButton.contentTintColor = .tertiaryLabelColor }
        removeButton.imagePosition = .imageOnly
        removeButton.target = self
        removeButton.action = #selector(removePatternTapped(_:))
        DesignSystemControlStyler.styleIconButton(removeButton, size: 18)

        let row = NSStackView(views: [field, removeButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = TableGroupView.spacing
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeRow(label: NSTextField, control: NSView, controlMinWidth: CGFloat = 0) -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = TableGroupView.rowHorizontalPadding
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: TableGroupView.rowVerticalPadding, left: TableGroupView.rowHorizontalPadding, bottom: TableGroupView.rowVerticalPadding, right: TableGroupView.rowHorizontalPadding)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: TableGroupView.minimumRowHeight).isActive = true
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        if controlMinWidth > 0 {
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: controlMinWidth).isActive = true
        }
        return row
    }

    private func makeRowLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func refreshFromEntry() {
        let bundleId = entry.bundleIdentifier
        bundleIdField.stringValue = bundleId
        let hideIndex = entry.hide.index
        if hideIndex >= 0, hideIndex < hideDropdown.numberOfItems {
            hideDropdown.selectItem(at: hideIndex)
        }
        let ignoreIndex = entry.ignore.index
        if ignoreIndex >= 0, ignoreIndex < ignoreDropdown.numberOfItems {
            ignoreDropdown.selectItem(at: ignoreIndex)
        }
        rebuildPatternsList()
        updatePatternsVisibility()
        // Header icon/name only refresh if bundle ID actually changed since last resolution.
        if resolvedHeaderBundleId != bundleId {
            headerIconView.image = AppDisplayInfo.genericIcon
            headerNameLabel.stringValue = bundleId
            resolveHeaderAsync(for: bundleId)
        }
    }

    @objc private func bundleIdChanged(_ sender: NSTextField) {
        let newBundleId = sender.stringValue
        entry.bundleIdentifier = newBundleId
        emitChange()
        if resolvedHeaderBundleId != newBundleId {
            headerNameLabel.stringValue = newBundleId
            headerIconView.image = AppDisplayInfo.genericIcon
            resolveHeaderAsync(for: newBundleId)
        }
    }

    private func resolveHeaderAsync(for bundleId: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let info = AppDisplayInfo.resolve(bundleId: bundleId)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.entry.bundleIdentifier == bundleId else { return }
                self.headerIconView.image = info.icon
                self.headerNameLabel.stringValue = info.name
                self.resolvedHeaderBundleId = bundleId
            }
        }
    }

    @objc private func hideChanged(_ sender: NSPopUpButton) {
        let i = sender.indexOfSelectedItem
        if i >= 0 && i < ExceptionHidePreference.allCases.count {
            entry.hide = ExceptionHidePreference.allCases[i]
            updatePatternsVisibility()
            emitChange()
        }
    }

    @objc private func ignoreChanged(_ sender: NSPopUpButton) {
        let i = sender.indexOfSelectedItem
        if i >= 0 && i < ExceptionIgnorePreference.allCases.count {
            entry.ignore = ExceptionIgnorePreference.allCases[i]
            emitChange()
        }
    }

    @objc private func addPatternTapped() {
        let row = makePatternFieldRow(initial: "")
        patternsListStack.addArrangedSubview(row)
        if let stack = row as? NSStackView, let field = stack.arrangedSubviews.first as? NSTextField {
            field.window?.makeFirstResponder(field)
        }
        commitPatterns()
    }

    @objc private func removePatternTapped(_ sender: NSButton) {
        var view: NSView? = sender
        while let v = view, !(v is NSStackView && v.superview === patternsListStack) {
            view = v.superview
        }
        if let row = view {
            patternsListStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        if patternsListStack.arrangedSubviews.isEmpty {
            patternsListStack.addArrangedSubview(makePatternFieldRow(initial: ""))
        }
        commitPatterns()
    }

    private func commitPatterns() {
        let patterns = patternsListStack.arrangedSubviews.compactMap { row -> String? in
            guard let stack = row as? NSStackView, let field = stack.arrangedSubviews.first as? NSTextField else { return nil }
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        entry.windowTitleContains = patterns.isEmpty ? nil : patterns
        emitChange()
    }

    private func updatePatternsVisibility() {
        let show = entry.hide == .windowTitleContains
        patternsRow?.isHidden = !show
    }

    private func emitChange() {
        onChange?(entry)
    }
}

extension ExceptionEditorView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        // Only pattern fields use this delegate; bundle ID field uses target/action.
        if field !== bundleIdField, isPatternField(field) {
            commitPatterns()
        }
    }

    private func isPatternField(_ field: NSTextField) -> Bool {
        var view: NSView? = field
        while let v = view {
            if v === patternsListStack { return true }
            view = v.superview
        }
        return false
    }
}
