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
    private let bundleIdField = SurfaceTextField(placeholder: NSLocalizedString("e.g. com.example.app", comment: ""))
    private let hideDropdown = PopupButtonLikeSystemSettings()
    private let ignoreDropdown = PopupButtonLikeSystemSettings()
    private var patternsRow: SettingsRowView?
    private var patternsListStack = NSStackView()
    private var section: SettingsSectionView!

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
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
        outerStack.spacing = DesignMetric.sectionGap
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        let header = makeHeader()
        section = makeBehaviorSection()

        outerStack.addArrangedSubview(header)
        outerStack.addArrangedSubview(section)

        addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            section.leadingAnchor.constraint(equalTo: outerStack.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: outerStack.trailingAnchor),
        ])
    }

    private func makeHeader() -> NSView {
        headerIconView.translatesAutoresizingMaskIntoConstraints = false
        headerIconView.imageScaling = .scaleProportionallyUpOrDown
        headerIconView.widthAnchor.constraint(equalToConstant: DesignMetric.richListItemIconSize).isActive = true
        headerIconView.heightAnchor.constraint(equalToConstant: DesignMetric.richListItemIconSize).isActive = true

        headerNameLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        headerNameLabel.lineBreakMode = .byTruncatingTail

        let row = NSStackView(views: [headerIconView, headerNameLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DesignMetric.rowContentGap
        return row
    }

    private func makeBehaviorSection() -> SettingsSectionView {
        let section = SettingsSectionView()
        section.addRow(makeBundleIdRow())
        section.addRow(makeHideRow())
        let patterns = makePatternsRow()
        patternsRow = patterns
        section.addRow(patterns)
        section.addRow(makeIgnoreRow())
        return section
    }

    private func makeBundleIdRow() -> SettingsRowView {
        bundleIdField.cell?.sendsActionOnEndEditing = true
        bundleIdField.target = self
        bundleIdField.action = #selector(bundleIdChanged(_:))
        bundleIdField.lineBreakMode = .byTruncatingHead
        bundleIdField.usesSingleLineMode = true
        bundleIdField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        return SettingsRowView(title: NSLocalizedString("Bundle ID", comment: ""), content: [bundleIdField])
    }

    private func makeHideRow() -> SettingsRowView {
        hideDropdown.translatesAutoresizingMaskIntoConstraints = false
        hideDropdown.removeAllItems()
        hideDropdown.addItems(withTitles: ExceptionHidePreference.allCases.map { c -> String in
            c == .none ? NSLocalizedString("Don't hide", comment: "") : c.localizedString
        })
        hideDropdown.target = self
        hideDropdown.action = #selector(hideChanged(_:))
        return SettingsRowView(title: NSLocalizedString("Hide windows", comment: ""), content: [hideDropdown])
    }

    private func makeIgnoreRow() -> SettingsRowView {
        ignoreDropdown.translatesAutoresizingMaskIntoConstraints = false
        ignoreDropdown.removeAllItems()
        ignoreDropdown.addItems(withTitles: ExceptionIgnorePreference.allCases.map { c -> String in
            c == .none ? NSLocalizedString("Never", comment: "") : c.localizedString
        })
        ignoreDropdown.target = self
        ignoreDropdown.action = #selector(ignoreChanged(_:))
        return SettingsRowView(title: NSLocalizedString("Ignore shortcuts", comment: ""), content: [ignoreDropdown])
    }

    private func makePatternsRow() -> SettingsRowView {
        patternsListStack.orientation = .vertical
        patternsListStack.alignment = .leading
        patternsListStack.spacing = DesignMetric.compactTextStackGap
        patternsListStack.translatesAutoresizingMaskIntoConstraints = false

        let addButton = SurfaceButton(title: NSLocalizedString("Add a pattern", comment: ""), role: .flat) { [weak self] _ in
            self?.addPatternTapped()
        }
        addButton.image = NSImage.fromSymbol(.plus, pointSize: 11)
        addButton.imagePosition = .imageLeading

        let column = NSStackView(views: [patternsListStack, addButton])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = DesignMetric.rowContentGap
        column.translatesAutoresizingMaskIntoConstraints = false
        return SettingsRowView(title: NSLocalizedString("Title patterns", comment: ""), subtitle: NSLocalizedString("Hide windows whose title contains any of these patterns.", comment: ""), content: [column])
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
        let field = SurfaceTextField(placeholder: NSLocalizedString("e.g. Debug", comment: ""))
        field.stringValue = initial
        field.delegate = self
        field.usesSingleLineMode = true
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        let removeButton = NSButton()
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.bezelStyle = .circular
        removeButton.isBordered = false
        removeButton.image = NSImage.fromSymbol(.minusCircleFill, pointSize: 14)
        if #available(macOS 10.14, *) { removeButton.contentTintColor = .tertiaryLabelColor }
        removeButton.imagePosition = .imageOnly
        removeButton.target = self
        removeButton.action = #selector(removePatternTapped(_:))
        removeButton.widthAnchor.constraint(equalToConstant: 18).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let row = NSStackView(views: [field, removeButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
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
