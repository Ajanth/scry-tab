import Cocoa

final class FocusSetSettingsView: NSView {
    static let searchableStrings = [
        NSLocalizedString("Focus Sets", comment: ""),
        NSLocalizedString("Open Focus Sets", comment: ""),
        NSLocalizedString("Choose a global shortcut to open the Focus Sets picker.", comment: ""),
        NSLocalizedString("Focus Sets profile", comment: ""),
        NSLocalizedString("Uses this shortcut’s filters when counting and showing windows.", comment: ""),
        NSLocalizedString("Saved Focus Sets", comment: ""),
        NSLocalizedString("Add Focus Set", comment: ""),
        NSLocalizedString("No Focus Sets", comment: ""),
        NSLocalizedString("Create a set to browse the applications you use together.", comment: ""),
        NSLocalizedString("Edit", comment: ""),
        NSLocalizedString("Move Focus Set Up", comment: ""),
        NSLocalizedString("Move Focus Set Down", comment: ""),
        NSLocalizedString("Delete", comment: ""),
        NSLocalizedString("Edit Focus Set", comment: ""),
        NSLocalizedString("Name", comment: ""),
        NSLocalizedString("Included Applications", comment: ""),
        NSLocalizedString("Choose Applications…", comment: ""),
        NSLocalizedString("No applications selected.", comment: ""),
        NSLocalizedString("Search applications", comment: ""),
        NSLocalizedString("No matching applications.", comment: ""),
        NSLocalizedString("Not currently open", comment: ""),
        NSLocalizedString("1 matching window", comment: ""),
        NSLocalizedString("%d matching windows", comment: ""),
    ]

    private let store = FocusSetsStore()
    private let contentWidth: CGFloat
    private var configuration = FocusSetsConfiguration()
    private var selectedSetIdentifier: UUID?
    private var candidateCounts = [UUID: Int]()
    private var candidateCountsByBundleIdentifier = [String: Int]()
    private var content: NSView?
    private var contentConstraints = [NSLayoutConstraint]()
    private var candidateCountLabels = [UUID: NSTextField]()
    private weak var nameField: NSTextField?
    private weak var profilePopup: PopupButtonLikeSystemSettings?
    private let candidateCountRefreshThrottler = Throttler(delayInMs: 200)
    private var inventoryObserver: NSObjectProtocol?

    init(width: CGFloat) {
        contentWidth = width
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        inventoryObserver = NotificationCenter.default.addObserver(
            forName: App.windowInventoryDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleCandidateCountRefresh()
        }
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let inventoryObserver {
            NotificationCenter.default.removeObserver(inventoryObserver)
        }
    }

    func refresh() {
        let refreshedConfiguration = store.read(availableShortcutIdentifiers: availableShortcutIdentifiers())
        let refreshedSelection = FocusSetSettingsResolver.selectedFocusSetIdentifier(
            preferredIdentifier: selectedSetIdentifier,
            sets: refreshedConfiguration.sets)
        let needsRebuild = content == nil ||
            configuration.sets != refreshedConfiguration.sets ||
            selectedSetIdentifier != refreshedSelection
        configuration = refreshedConfiguration
        selectedSetIdentifier = refreshedSelection
        refreshCandidateCounts()
        if needsRebuild {
            rebuildContent()
        } else {
            refreshProfilePopup()
            refreshCandidateCountLabels()
        }
    }

    private func scheduleCandidateCountRefresh() {
        guard updatesCandidateCountsWhileVisible else { return }
        candidateCountRefreshThrottler.throttleOrProceed { [weak self] in
            self?.refreshVisibleCandidateCounts()
        }
    }

    private func refreshVisibleCandidateCounts() {
        guard updatesCandidateCountsWhileVisible else { return }
        refreshCandidateCounts()
        refreshCandidateCountLabels()
    }

    private var updatesCandidateCountsWhileVisible: Bool {
        guard window?.isVisible == true,
              window?.attachedSheet == nil,
              !isHiddenOrHasHiddenAncestor else { return false }
        return !isEditingName
    }

    private var isEditingName: Bool {
        guard let nameField, let firstResponder = window?.firstResponder else { return false }
        if firstResponder === nameField { return true }
        guard let editor = nameField.currentEditor() else { return false }
        return firstResponder === editor
    }

    private func rebuildContent() {
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints.removeAll(keepingCapacity: true)
        content?.removeFromSuperview()
        content = nil
        nameField = nil
        profilePopup = nil
        candidateCountLabels.removeAll(keepingCapacity: true)
        let views = [makeProfileTable(), makeFocusSetsTable()] + (selectedFocusSet.map { [makeEditorTable(for: $0)] } ?? [])
        let content = TableGroupSetView(originalViews: views, padding: 0)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        let constraints = [
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        self.content = content
        contentConstraints = constraints
    }

    private func makeProfileTable() -> TableGroupView {
        let table = TableGroupView(title: NSLocalizedString("Focus Sets", comment: ""), width: contentWidth)
        let openPickerShortcut = LabelAndControl.makeLabelWithRecorder(
            NSLocalizedString("Open Focus Sets", comment: ""),
            "openFocusSetsShortcut",
            Preferences.openFocusSetsShortcut,
            labelPosition: .right)[0]
        _ = table.addRow(
            leftText: NSLocalizedString("Open Focus Sets", comment: ""),
            rightViews: [openPickerShortcut],
            subText: NSLocalizedString("Choose a global shortcut to open the Focus Sets picker.", comment: ""))
        let popup = PopupButtonLikeSystemSettings()
        configureProfilePopup(popup)
        popup.target = self
        popup.action = #selector(profileChanged(_:))
        DesignSystemControlStyler.stylePopupButton(popup)
        profilePopup = popup
        _ = table.addRow(leftText: NSLocalizedString("Focus Sets profile", comment: ""),
                         rightViews: [popup],
                         subText: NSLocalizedString("Uses this shortcut’s filters when counting and showing windows.", comment: ""))
        return table
    }

    private func makeFocusSetsTable() -> TableGroupView {
        let table = TableGroupView(title: NSLocalizedString("Saved Focus Sets", comment: ""), width: contentWidth)
        candidateCountLabels.removeAll(keepingCapacity: true)
        if configuration.sets.isEmpty {
            let add = DesignSystemControlStyler.makeButton(NSLocalizedString("Add Focus Set", comment: ""), target: self, action: #selector(addFocusSet(_:)))
            _ = table.addRow(leftText: NSLocalizedString("No Focus Sets", comment: ""),
                             rightViews: [add],
                             subText: NSLocalizedString("Create a set to browse the applications you use together.", comment: ""))
            return table
        }
        for (index, focusSet) in configuration.sets.enumerated() {
            let controls = makeSetControls(focusSet, index: index)
            let candidateCountLabel = makeCandidateCountLabel(for: focusSet)
            candidateCountLabels[focusSet.id] = candidateCountLabel
            _ = table.addRow(leftViews: [TableGroupView.makeText(focusSet.name)],
                             rightViews: [controls],
                             secondaryViews: [candidateCountLabel])
        }
        let add = DesignSystemControlStyler.makeButton(NSLocalizedString("Add Focus Set", comment: ""), target: self, action: #selector(addFocusSet(_:)))
        _ = table.addRow(leftText: nil, rightViews: [add])
        return table
    }

    private func configureProfilePopup(_ popup: PopupButtonLikeSystemSettings) {
        popup.removeAllItems()
        for index in 0..<Preferences.shortcutCount {
            let identifier = Preferences.shortcutIdentifier(at: index)
            popup.addItem(withTitle: shortcutLabel(index))
            popup.item(at: popup.numberOfItems - 1)?.representedObject = identifier
            if identifier == configuration.presentationShortcutIdentifier {
                popup.selectItem(at: popup.numberOfItems - 1)
            }
        }
    }

    private func refreshProfilePopup() {
        guard let profilePopup else { return }
        configureProfilePopup(profilePopup)
    }

    private func makeCandidateCountLabel(for focusSet: FocusSet) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: candidateCountLabel(for: focusSet))
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    private func refreshCandidateCountLabels() {
        for focusSet in configuration.sets {
            candidateCountLabels[focusSet.id]?.stringValue = candidateCountLabel(for: focusSet)
        }
    }

    private func makeSetControls(_ focusSet: FocusSet, index: Int) -> NSStackView {
        let edit = DesignSystemControlStyler.makeButton(NSLocalizedString("Edit", comment: ""), target: self, action: #selector(editFocusSet(_:)))
        edit.identifier = NSUserInterfaceItemIdentifier(focusSet.id.uuidString)
        edit.isEnabled = focusSet.id != selectedSetIdentifier
        let up = makeIconButton(symbol: .caretUp,
                                label: NSLocalizedString("Move Focus Set Up", comment: ""),
                                identifier: focusSet.id,
                                action: #selector(moveFocusSet(_:)))
        up.tag = -1
        up.isEnabled = index > 0
        let down = makeIconButton(symbol: .caretDown,
                                  label: NSLocalizedString("Move Focus Set Down", comment: ""),
                                  identifier: focusSet.id,
                                  action: #selector(moveFocusSet(_:)))
        down.tag = 1
        down.isEnabled = index < configuration.sets.count - 1
        let delete = DesignSystemControlStyler.makeButton(NSLocalizedString("Delete", comment: ""), destructive: true, target: self, action: #selector(deleteFocusSet(_:)))
        delete.identifier = NSUserInterfaceItemIdentifier(focusSet.id.uuidString)
        let controls = NSStackView(views: [edit, up, down, delete])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = TableGroupView.toolRowSpacing
        controls.translatesAutoresizingMaskIntoConstraints = false
        return controls
    }

    private func makeIconButton(symbol: Symbols,
                                label: String,
                                identifier: UUID,
                                action: Selector) -> NSButton {
        let button = NSButton()
        button.image = NSImage.fromSymbol(symbol, pointSize: 11)
        button.target = self
        button.action = action
        button.identifier = NSUserInterfaceItemIdentifier(identifier.uuidString)
        button.toolTip = label
        button.setAccessibilityLabel(label)
        DesignSystemControlStyler.styleIconButton(button, size: 24)
        return button
    }

    private func makeEditorTable(for focusSet: FocusSet) -> TableGroupView {
        let table = TableGroupView(title: NSLocalizedString("Edit Focus Set", comment: ""), width: contentWidth)
        let nameField = NSTextField(string: focusSet.name)
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(commitName(_:))
        nameField.widthAnchor.constraint(equalToConstant: max(240, contentWidth * 0.55)).isActive = true
        DesignSystemControlStyler.styleTextField(nameField)
        self.nameField = nameField
        _ = table.addRow(leftText: NSLocalizedString("Name", comment: ""), rightViews: [nameField])
        let applicationsButton = DesignSystemControlStyler.makeButton(NSLocalizedString("Choose Applications…", comment: ""), target: self, action: #selector(chooseApplications(_:)))
        _ = table.addRow(leftText: NSLocalizedString("Included Applications", comment: ""),
                         rightViews: [applicationsButton],
                         subText: applicationSummary(focusSet.rules))
        return table
    }

    private var selectedFocusSet: FocusSet? {
        guard let selectedSetIdentifier else { return nil }
        return configuration.sets.first { $0.id == selectedSetIdentifier }
    }

    private func availableShortcutIdentifiers() -> [String] {
        (0..<Preferences.shortcutCount).map { Preferences.shortcutIdentifier(at: $0) }
    }

    private func shortcutLabel(_ index: Int) -> String {
        let title = NSLocalizedString("Shortcut", comment: "") + " " + String(index + 1)
        let hold = Preferences.shortcut(Preferences.indexToName("holdShortcut", index))?.keyEquivalent ?? ""
        let next = Preferences.shortcut(Preferences.indexToName("nextWindowShortcut", index))?.keyEquivalent ?? ""
        let keyEquivalent = [hold, next].filter { !$0.isEmpty }.joined(separator: " + ")
        return keyEquivalent.isEmpty ? title : title + " — " + keyEquivalent
    }

    private func refreshCandidateCounts() {
        let snapshot = FocusSetPresentationSnapshotBuilder.make(configuration: configuration)
        candidateCounts = Dictionary(uniqueKeysWithValues: configuration.sets.map {
            ($0.id, snapshot.candidateCounts[.set(id: $0.id)] ?? 0)
        })
        candidateCountsByBundleIdentifier = snapshot.candidateCountsByBundleIdentifier
    }

    private func candidateCountLabel(for focusSet: FocusSet) -> String {
        let count = candidateCounts[focusSet.id] ?? 0
        if count == 1 { return NSLocalizedString("1 matching window", comment: "") }
        return String(format: NSLocalizedString("%d matching windows", comment: ""), count)
    }

    private func applicationSummary(_ rules: [FocusSetRule]) -> String {
        let names = rules.compactMap { rule -> String? in
            let name = displayName(for: rule)
            return name.isEmpty ? nil : name
        }
        if names.isEmpty { return NSLocalizedString("No applications selected.", comment: "") }
        return names.joined(separator: ", ")
    }

    private func displayName(for rule: FocusSetRule) -> String {
        let name = rule.cachedApplicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != rule.applicationBundleIdentifier { return name }
        return NSLocalizedString("Unavailable application", comment: "")
    }

    private func liveApplications() -> [FocusSetPickerApplication] {
        var identifiers = Set<String>()
        var applications = [FocusSetPickerApplication]()
        for application in Applications.list {
            guard let bundleIdentifier = application.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !bundleIdentifier.isEmpty,
                  identifiers.insert(bundleIdentifier).inserted,
                  let name = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            applications.append(FocusSetPickerApplication(bundleIdentifier: bundleIdentifier,
                                                          name: name,
                                                          icon: application.runningApplication.icon ?? AppDisplayInfo.genericIcon,
                                                          candidateCount: candidateCountsByBundleIdentifier[bundleIdentifier] ?? 0))
        }
        return applications
    }

    private func replaceSelectedSet(name: String? = nil, rules: [FocusSetRule]? = nil) {
        guard let selectedSetIdentifier,
              let index = configuration.sets.firstIndex(where: { $0.id == selectedSetIdentifier }) else { return }
        let current = configuration.sets[index]
        var sets = configuration.sets
        sets[index] = FocusSet(id: current.id, name: name ?? current.name, rules: rules ?? current.rules)
        persist(sets, preferredSelection: selectedSetIdentifier)
    }

    private func persist(_ sets: [FocusSet], preferredSelection: UUID?) {
        let next = FocusSetsConfiguration(version: configuration.version,
                                          presentationShortcutIdentifier: configuration.presentationShortcutIdentifier,
                                          sets: sets)
        guard store.set(next, availableShortcutIdentifiers: availableShortcutIdentifiers()) else {
            NSSound.beep()
            return
        }
        selectedSetIdentifier = FocusSetSettingsResolver.selectedFocusSetIdentifier(
            preferredIdentifier: preferredSelection,
            sets: sets)
        refresh()
        App.refreshOpenUiAfterFocusSetConfigurationChange()
    }

    @objc private func profileChanged(_ sender: NSPopUpButton) {
        guard let identifier = sender.selectedItem?.representedObject as? String else { return }
        let next = FocusSetsConfiguration(version: configuration.version,
                                          presentationShortcutIdentifier: identifier,
                                          sets: configuration.sets)
        guard store.set(next, availableShortcutIdentifiers: availableShortcutIdentifiers()) else {
            NSSound.beep()
            return
        }
        refresh()
        App.refreshOpenUiAfterFocusSetConfigurationChange()
    }

    @objc private func addFocusSet(_ sender: NSButton) {
        let focusSet = FocusSet(name: NSLocalizedString("New Focus Set", comment: ""), rules: [])
        persist(configuration.sets + [focusSet], preferredSelection: focusSet.id)
        nameField?.selectText(nil)
    }

    @objc private func editFocusSet(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue,
              let identifier = UUID(uuidString: value),
              configuration.sets.contains(where: { $0.id == identifier }),
              selectedSetIdentifier != identifier else { return }
        selectedSetIdentifier = identifier
        rebuildContent()
    }

    @objc private func deleteFocusSet(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue,
              let identifier = UUID(uuidString: value),
              configuration.sets.contains(where: { $0.id == identifier }) else { return }
        let sets = configuration.sets.filter { $0.id != identifier }
        persist(sets, preferredSelection: selectedSetIdentifier)
    }

    @objc private func moveFocusSet(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue,
              let identifier = UUID(uuidString: value),
              let index = configuration.sets.firstIndex(where: { $0.id == identifier }) else { return }
        let destination = index + sender.tag
        guard configuration.sets.indices.contains(destination) else { return }
        var sets = configuration.sets
        sets.swapAt(index, destination)
        persist(sets, preferredSelection: selectedSetIdentifier)
    }

    @objc private func commitName(_ sender: NSTextField) {
        let name = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            sender.stringValue = selectedFocusSet?.name ?? ""
            NSSound.beep()
            return
        }
        replaceSelectedSet(name: name)
    }

    @objc private func chooseApplications(_ sender: NSButton) {
        guard let focusSet = selectedFocusSet else { return }
        refreshCandidateCounts()
        let sheet = FocusSetApplicationPickerSheet(applications: liveApplications(),
                                                   selectedRules: focusSet.rules) { [weak self] rules in
            self?.replaceSelectedSet(rules: rules)
        }
        SettingsWindow.shared.beginSheetWithSearchHighlight(sheet)
    }
}

extension FocusSetSettingsView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === nameField else { return }
        commitName(field)
    }
}

private struct FocusSetPickerApplication {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage
    let candidateCount: Int
}

private struct FocusSetPickerEntry {
    let identity: FocusSetApplicationIdentity
    let name: String
    let icon: NSImage
    let candidateCount: Int
    let isAvailable: Bool
    let isSelected: Bool
}

private final class FocusSetApplicationPickerSheet: SheetWindow {
    private let searchField = NSSearchField()
    private let rows = NSStackView()
    private var applicationOptions = [FocusSetApplicationOption]()
    private var applicationsByIdentity = [FocusSetApplicationIdentity: FocusSetPickerApplication]()
    private var selectedIdentities = Set<FocusSetApplicationIdentity>()
    private var currentRules = [FocusSetRule]()
    private var identityBySwitch = [ObjectIdentifier: FocusSetApplicationIdentity]()
    private weak var resultsScrollView: NSScrollView?
    private var onApply: (([FocusSetRule]) -> Void)?

    convenience init(applications: [FocusSetPickerApplication],
                     selectedRules: [FocusSetRule],
                     onApply: @escaping ([FocusSetRule]) -> Void) {
        self.init()
        self.onApply = onApply
        applicationOptions = applications.map {
            FocusSetApplicationOption(bundleIdentifier: $0.bundleIdentifier, presentationName: $0.name)
        }
        for (application, option) in zip(applications, applicationOptions) {
            if applicationsByIdentity[option.identity] == nil {
                applicationsByIdentity[option.identity] = application
            }
        }
        currentRules = selectedRules
        selectedIdentities = Set(FocusSetSettingsResolver.applicationPickerRows(
            applications: applicationOptions,
            rules: currentRules
        ).filter(\.isSelected).map(\.identity))
        doneButton.title = NSLocalizedString("Apply", comment: "")
        doneButton.target = self
        doneButton.action = #selector(applySelection(_:))
        rebuildRows()
    }

    override func makeContentView() -> NSView {
        searchField.placeholderString = NSLocalizedString("Search applications", comment: "")
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        searchField.sendsSearchStringImmediately = true
        DesignSystemControlStyler.styleSearchField(searchField)

        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = TableGroupView.rowVerticalPadding
        rows.translatesAutoresizingMaskIntoConstraints = false

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rows)
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.scrollerStyle = .overlay
        scroll.documentView = document
        resultsScrollView = scroll
        scroll.heightAnchor.constraint(equalToConstant: 280).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: contentWidth - 2 * TableGroupView.rowHorizontalPadding).isActive = true
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            document.heightAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.heightAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor),
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor),
        ])

        let table = TableGroupView(title: NSLocalizedString("Included Applications", comment: ""), width: contentWidth)
        _ = table.addRow(leftText: nil, rightViews: [searchField])
        _ = table.addRow(leftViews: nil,
                         rightViews: nil,
                         secondaryViews: [scroll],
                         secondaryViewsAlignment: .centerX)
        return table
    }

    private func rebuildRows() {
        rows.arrangedSubviews.forEach {
            rows.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        identityBySwitch.removeAll(keepingCapacity: true)
        defer { scrollToTop() }
        let entries = filteredEntries()
        if entries.isEmpty {
            let label = NSTextField(wrappingLabelWithString: NSLocalizedString("No matching applications.", comment: ""))
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            rows.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            return
        }
        for entry in entries {
            let row = makeRow(entry)
            rows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
    }

    private func scrollToTop() {
        guard let resultsScrollView else { return }
        resultsScrollView.contentView.scroll(to: .zero)
        resultsScrollView.reflectScrolledClipView(resultsScrollView.contentView)
    }

    private func filteredEntries() -> [FocusSetPickerEntry] {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return orderedEntries().filter {
            query.isEmpty || $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func orderedEntries() -> [FocusSetPickerEntry] {
        FocusSetSettingsResolver.applicationPickerRows(
            applications: applicationOptions,
            rules: currentRules
        ).map { row in
            let application = applicationsByIdentity[row.identity]
            return FocusSetPickerEntry(
                identity: row.identity,
                name: displayName(row),
                icon: application?.icon ?? AppDisplayInfo.genericIcon,
                candidateCount: application?.candidateCount ?? 0,
                isAvailable: row.isAvailable,
                isSelected: row.isSelected)
        }
    }

    private func makeRow(_ entry: FocusSetPickerEntry) -> NSStackView {
        let icon = NSImageView(image: entry.icon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let title = NSTextField(labelWithString: entry.name)
        title.font = NSFont.systemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingTail
        let subtitle = NSTextField(labelWithString: subtitle(for: entry))
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let toggle = Switch(entry.isSelected)
        toggle.target = self
        toggle.action = #selector(selectionChanged(_:))
        toggle.toolTip = entry.name
        toggle.setAccessibilityLabel(entry.name)
        identityBySwitch[ObjectIdentifier(toggle)] = entry.identity
        let row = NSStackView(views: [icon, labels, toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = TableGroupView.spacing
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignSystem.Metrics.standardControlMinHeight).isActive = true
        return row
    }

    private func subtitle(for entry: FocusSetPickerEntry) -> String {
        if !entry.isAvailable { return NSLocalizedString("Not currently open", comment: "") }
        if entry.candidateCount == 1 { return NSLocalizedString("1 matching window", comment: "") }
        return String(format: NSLocalizedString("%d matching windows", comment: ""), entry.candidateCount)
    }

    private func displayName(_ row: FocusSetApplicationPickerRow) -> String {
        let name = row.presentationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return NSLocalizedString("Unavailable application", comment: "")
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        rebuildRows()
    }

    @objc private func selectionChanged(_ sender: Switch) {
        guard let identity = identityBySwitch[ObjectIdentifier(sender)] else { return }
        if sender.state == .on {
            selectedIdentities.insert(identity)
        } else {
            selectedIdentities.remove(identity)
        }
        currentRules = FocusSetSettingsResolver.rules(
            selectedApplicationIdentities: selectedIdentities,
            applications: applicationOptions,
            existingRules: currentRules)
        rebuildRows()
    }

    @objc private func applySelection(_ sender: NSButton) {
        onApply?(currentRules)
        sheetParent?.endSheet(self)
    }
}
