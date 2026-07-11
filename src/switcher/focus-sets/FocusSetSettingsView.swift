import Cocoa
import ShortcutRecorder

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
        NSLocalizedString("Editing “%@”", comment: ""),
        NSLocalizedString("Move Focus Set Up", comment: ""),
        NSLocalizedString("Move Focus Set Down", comment: ""),
        NSLocalizedString("Move Up", comment: ""),
        NSLocalizedString("Move Down", comment: ""),
        NSLocalizedString("Delete", comment: ""),
        NSLocalizedString("Name", comment: ""),
        NSLocalizedString("Included Applications", comment: ""),
        NSLocalizedString("1 included application", comment: ""),
        NSLocalizedString("%d included applications", comment: ""),
        NSLocalizedString("Search applications", comment: ""),
        NSLocalizedString("Choose the applications whose windows belong to this Focus Set.", comment: ""),
        NSLocalizedString("No applications selected", comment: ""),
        NSLocalizedString("1 application selected", comment: ""),
        NSLocalizedString("%d applications selected", comment: ""),
        NSLocalizedString("No matching applications.", comment: ""),
        NSLocalizedString("Not currently open", comment: ""),
        NSLocalizedString("1 matching window", comment: ""),
        NSLocalizedString("%d matching windows", comment: ""),
        NSLocalizedString("Cancel", comment: ""),
        NSLocalizedString("Apply", comment: ""),
    ]

    private let store = FocusSetsStore()
    private let contentWidth: CGFloat
    private var configuration = FocusSetsConfiguration()
    private var candidateCounts = [UUID: Int]()
    private var candidateCountsByBundleIdentifier = [String: Int]()
    private var content: NSView?
    private var contentConstraints = [NSLayoutConstraint]()
    private var candidateCountLabels = [UUID: NSTextField]()
    private weak var profilePopup: PopupButtonLikeSystemSettings?
    private weak var profileShortcutSummaryLabel: NSTextField?
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
        let needsRebuild = content == nil ||
            configuration.sets != refreshedConfiguration.sets
        configuration = refreshedConfiguration
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
        return true
    }

    private func rebuildContent() {
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints.removeAll(keepingCapacity: true)
        content?.removeFromSuperview()
        content = nil
        profilePopup = nil
        profileShortcutSummaryLabel = nil
        candidateCountLabels.removeAll(keepingCapacity: true)
        let views = [makeProfileTable(), makeFocusSetsTable()]
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
        let shortcutSummary = NSTextField(labelWithString: selectedShortcutSummary())
        shortcutSummary.font = NSFont.systemFont(ofSize: 11)
        shortcutSummary.textColor = .secondaryLabelColor
        shortcutSummary.alignment = .left
        shortcutSummary.lineBreakMode = .byTruncatingTail
        let selection = NSStackView(views: [popup, shortcutSummary])
        selection.orientation = .vertical
        selection.alignment = .leading
        selection.spacing = 1
        selection.translatesAutoresizingMaskIntoConstraints = false
        profilePopup = popup
        profileShortcutSummaryLabel = shortcutSummary
        _ = table.addRow(leftText: NSLocalizedString("Focus Sets profile", comment: ""),
                         rightViews: [selection],
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
            let controls = makeSetControls(for: focusSet, at: index)
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
            popup.addItem(withTitle: shortcutTitle(index))
            popup.item(at: popup.numberOfItems - 1)?.representedObject = identifier
            if identifier == configuration.presentationShortcutIdentifier {
                popup.selectItem(at: popup.numberOfItems - 1)
            }
        }
    }

    private func refreshProfilePopup() {
        guard let profilePopup else { return }
        configureProfilePopup(profilePopup)
        profileShortcutSummaryLabel?.stringValue = selectedShortcutSummary()
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

    private func makeSetControls(for focusSet: FocusSet, at index: Int) -> NSStackView {
        let edit = DesignSystemControlStyler.makeButton(NSLocalizedString("Edit", comment: ""), target: self, action: #selector(editFocusSet(_:)))
        edit.identifier = NSUserInterfaceItemIdentifier(focusSet.id.uuidString)
        let delete = DesignSystemControlStyler.makeButton(NSLocalizedString("Delete", comment: ""), destructive: true)
        delete.onAction = { [weak self] _ in self?.deleteFocusSet(with: focusSet.id) }
        let move = makeReorderMenu(for: focusSet, at: index)
        let controls = NSStackView(views: [move, edit, delete])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = TableGroupView.toolRowSpacing
        controls.translatesAutoresizingMaskIntoConstraints = false
        return controls
    }

    private func makeReorderMenu(for focusSet: FocusSet, at index: Int) -> PopupButtonLikeSystemSettings {
        let button = PopupButtonLikeSystemSettings(frame: .zero, pullsDown: true)
        button.addItem(withTitle: "↕")
        let label = NSLocalizedString("Move Up", comment: "") + " / " + NSLocalizedString("Move Down", comment: "")
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.isEnabled = configuration.sets.count > 1
        guard let menu = button.menu else { return button }
        let up = menu.addItem(withTitle: NSLocalizedString("Move Up", comment: ""), action: #selector(moveFocusSet(_:)), keyEquivalent: "")
        up.target = self
        up.representedObject = focusSet.id.uuidString
        up.tag = -1
        up.isEnabled = index > 0
        let down = menu.addItem(withTitle: NSLocalizedString("Move Down", comment: ""), action: #selector(moveFocusSet(_:)), keyEquivalent: "")
        down.target = self
        down.representedObject = focusSet.id.uuidString
        down.tag = 1
        down.isEnabled = index < configuration.sets.count - 1
        return button
    }

    private func availableShortcutIdentifiers() -> [String] {
        (0..<Preferences.shortcutCount).map { Preferences.shortcutIdentifier(at: $0) }
    }

    private func shortcutTitle(_ index: Int) -> String {
        NSLocalizedString("Shortcut", comment: "") + " " + String(index + 1)
    }

    private func shortcutSummary(_ index: Int) -> String {
        ControlsTab.shortcutSummary(index)
    }

    private func selectedShortcutSummary() -> String {
        let identifier = configuration.presentationShortcutIdentifier
        let index = Preferences.shortcutIndex(forIdentifier: identifier) ?? 0
        return shortcutSummary(index)
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
        let applicationCount = FocusSetSettingsResolver.includedApplicationCount(focusSet.rules)
        let applications = applicationCount == 1
            ? NSLocalizedString("1 included application", comment: "")
            : String(format: NSLocalizedString("%d included applications", comment: ""), applicationCount)
        let windows = count == 1
            ? NSLocalizedString("1 matching window", comment: "")
            : String(format: NSLocalizedString("%d matching windows", comment: ""), count)
        return applications + " · " + windows
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

    private func persist(_ sets: [FocusSet]) {
        let next = FocusSetsConfiguration(version: configuration.version,
                                          presentationShortcutIdentifier: configuration.presentationShortcutIdentifier,
                                          sets: sets)
        guard store.set(next, availableShortcutIdentifiers: availableShortcutIdentifiers()) else {
            NSSound.beep()
            return
        }
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
        showFocusSetEditor(focusSet)
    }

    @objc private func editFocusSet(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue,
              let identifier = UUID(uuidString: value),
              let focusSet = configuration.sets.first(where: { $0.id == identifier }) else { return }
        showFocusSetEditor(focusSet)
    }

    @objc private func moveFocusSet(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let identifier = UUID(uuidString: value),
              let sets = FocusSetSettingsResolver.movedFocusSets(
                  moving: identifier,
                  by: sender.tag,
                  in: configuration.sets) else { return }
        persist(sets)
    }

    private func showFocusSetEditor(_ focusSet: FocusSet) {
        refreshCandidateCounts()
        let sheet = FocusSetEditorSheet(
            focusSet: focusSet,
            applications: liveApplications(),
            onApply: { [weak self] focusSet, conflictingShortcutIdentifier in
                self?.saveFocusSet(focusSet, unassigningShortcut: conflictingShortcutIdentifier)
            }
        )
        SettingsWindow.shared.beginSheetWithSearchHighlight(sheet)
    }

    private func saveFocusSet(_ focusSet: FocusSet, unassigningShortcut actionIdentifier: String?) {
        let next = FocusSetSettingsResolver.configurationBySavingFocusSet(
            focusSet,
            unassigningShortcutActionIdentifier: actionIdentifier,
            in: configuration)
        guard store.set(next, availableShortcutIdentifiers: availableShortcutIdentifiers()) else {
            NSSound.beep()
            return
        }
        if let actionIdentifier,
           FocusSetShortcutBindingResolver.focusSetIdentifier(from: actionIdentifier) == nil {
            ControlsTab.unassignShortcutConflict(actionIdentifier)
        }
        refresh()
        App.refreshOpenUiAfterFocusSetConfigurationChange()
    }

    private func deleteFocusSet(with identifier: UUID) {
        guard let next = FocusSetSettingsResolver.configurationByDeletingFocusSet(identifier, from: configuration) else {
            NSSound.beep()
            refresh()
            return
        }
        guard store.set(next, availableShortcutIdentifiers: availableShortcutIdentifiers()) else {
            NSSound.beep()
            return
        }
        let persisted = store.read(availableShortcutIdentifiers: availableShortcutIdentifiers())
        guard persisted == next else {
            NSSound.beep()
            refresh()
            return
        }
        configuration = persisted
        refreshCandidateCounts()
        rebuildContent()
        App.refreshOpenUiAfterFocusSetConfigurationChange()
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

private final class FocusSetEditorSheet: SheetWindow {
    private let nameField = NSTextField()
    private let shortcutRecorder = CustomRecorderControl(nil, true, "focusSetShortcut:pending")
    private let searchField = NSSearchField()
    private let selectionCountLabel = NSTextField(labelWithString: "")
    private let rows = NSStackView()
    private var applicationOptions = [FocusSetApplicationOption]()
    private var applicationsByIdentity = [FocusSetApplicationIdentity: FocusSetPickerApplication]()
    private var selectedIdentities = Set<FocusSetApplicationIdentity>()
    private var currentRules = [FocusSetRule]()
    private var identityBySwitch = [ObjectIdentifier: FocusSetApplicationIdentity]()
    private var switchesByIdentity = [FocusSetApplicationIdentity: Switch]()
    private weak var resultsScrollView: NSScrollView?
    private var focusSet = FocusSet(name: "", rules: [])
    private var searchQuery = ""
    private var shortcutKeyEquivalent: String?
    private var conflictingShortcutActionIdentifier: String?
    private var textObserver: NSObjectProtocol?
    private var onApply: ((FocusSet, String?) -> Void)?

    deinit {
        if let textObserver {
            NotificationCenter.default.removeObserver(textObserver)
        }
    }

    convenience init(focusSet: FocusSet,
                     applications: [FocusSetPickerApplication],
                     onApply: @escaping (FocusSet, String?) -> Void) {
        self.init()
        self.focusSet = focusSet
        self.onApply = onApply
        configureApplications(applications)
        currentRules = focusSet.rules
        selectedIdentities = Set(FocusSetSettingsResolver.applicationPickerRows(
            applications: applicationOptions,
            rules: currentRules
        ).filter(\.isSelected).map(\.identity))
        nameField.stringValue = focusSet.name
        configureShortcutRecorder(focusSet)
        updateTitle()
        doneButton.title = NSLocalizedString("Apply", comment: "")
        doneButton.target = self
        doneButton.action = #selector(applySelection(_:))
        addCancelButton()
        installSearchObserver()
        rebuildRows(scrollToTop: true)
        initialFirstResponder = nameField
    }

    override func makeContentView() -> NSView {
        configureNameField()
        configureSearchField()
        configureSelectionCountLabel()
        return TableGroupSetView(
            originalViews: [
                makeNameTable(),
                makeApplicationsTable(scroll: makeResultsScrollView()),
            ],
            padding: 0)
    }

    private func configureNameField() {
        nameField.setAccessibilityLabel(NSLocalizedString("Name", comment: ""))
        DesignSystemControlStyler.styleTextField(nameField)
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let minimumWidth = nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: contentWidth * 0.55)
        minimumWidth.priority = .defaultHigh
        minimumWidth.isActive = true
    }

    private func configureSearchField() {
        searchField.placeholderString = NSLocalizedString("Search applications", comment: "")
        searchField.setAccessibilityLabel(NSLocalizedString("Search applications", comment: ""))
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        searchField.translatesAutoresizingMaskIntoConstraints = false
        DesignSystemControlStyler.styleMainSearchField(searchField)
        searchField.widthAnchor.constraint(equalToConstant: contentWidth - 2 * TableGroupView.rowHorizontalPadding).isActive = true
    }

    private func configureSelectionCountLabel() {
        selectionCountLabel.font = NSFont.systemFont(ofSize: 12)
        selectionCountLabel.textColor = .secondaryLabelColor
        selectionCountLabel.alignment = .right
        selectionCountLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeNameTable() -> TableGroupView {
        let table = TableGroupView(width: contentWidth)
        _ = table.addRow(leftText: NSLocalizedString("Name", comment: ""), rightViews: [nameField])
        _ = table.addRow(leftText: NSLocalizedString("Shortcut", comment: ""), rightViews: [shortcutRecorder])
        return table
    }

    private func configureShortcutRecorder(_ focusSet: FocusSet) {
        shortcutRecorder.identifier = NSUserInterfaceItemIdentifier(
            FocusSetShortcutBindingResolver.actionIdentifier(for: focusSet.id))
        shortcutRecorder.allowsModifierFlagsOnlyShortcut = false
        shortcutKeyEquivalent = focusSet.shortcutKeyEquivalent
        shortcutRecorder.objectValue = focusSet.shortcutKeyEquivalent.flatMap(Shortcut.init(keyEquivalent:))
        shortcutRecorder.setAccessibilityLabel(NSLocalizedString("Shortcut", comment: ""))
        shortcutRecorder.transactionalCandidateHandler = { [weak self] shortcut, acceptance in
            self?.acceptShortcut(shortcut, acceptance: acceptance) ?? false
        }
        shortcutRecorder.onAction = { [weak self] _ in
            guard let self, self.shortcutRecorder.objectValue == nil else { return }
            self.shortcutKeyEquivalent = nil
            self.conflictingShortcutActionIdentifier = nil
        }
    }

    private func acceptShortcut(_ shortcut: Shortcut, acceptance: ShortcutAcceptance) -> Bool {
        switch acceptance {
        case .accepted:
            shortcutKeyEquivalent = shortcut.keyEquivalent
            conflictingShortcutActionIdentifier = nil
            return true
        case .modifiersOnlyButContainsKeycode:
            return false
        case .nonModifierKeyRequired:
            return false
        case .conflictWithExistingShortcut(let actionIdentifier):
            guard shortcutRecorder.confirmUnassigningShortcut(actionIdentifier) else { return false }
            shortcutKeyEquivalent = shortcut.keyEquivalent
            conflictingShortcutActionIdentifier = actionIdentifier
            return true
        case .reservedByMacos(let actionIdentifier):
            guard shortcutRecorder.confirmUnassigningShortcutReservedByMacos(actionIdentifier) else { return false }
            shortcutKeyEquivalent = shortcut.keyEquivalent
            conflictingShortcutActionIdentifier = actionIdentifier
            return true
        }
    }

    private func makeApplicationsTable(scroll: NSScrollView) -> TableGroupView {
        let table = TableGroupView(
            title: NSLocalizedString("Included Applications", comment: ""),
            subTitle: NSLocalizedString("Choose the applications whose windows belong to this Focus Set.", comment: ""),
            hasHeader: true,
            width: contentWidth)
        let selectionCountHeader = makeSelectionCountHeader()
        table.addHeader(views: [selectionCountHeader])
        selectionCountHeader.widthAnchor.constraint(equalTo: table.widthAnchor).isActive = true
        _ = table.addRow(leftViews: [searchField])
        _ = table.addRow(leftViews: nil,
                         rightViews: nil,
                         secondaryViews: [scroll],
                         secondaryViewsAlignment: .centerX)
        return table
    }

    private func makeSelectionCountHeader() -> NSStackView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [spacer, selectionCountLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false
        return header
    }

    private func makeResultsScrollView() -> NSScrollView {
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
        scroll.widthAnchor.constraint(equalToConstant: contentWidth - 2 * TableGroupView.rowHorizontalPadding).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 240).isActive = true
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            document.heightAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.heightAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor),
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor),
        ])
        return scroll
    }

    private func configureApplications(_ applications: [FocusSetPickerApplication]) {
        applicationOptions = applications.map {
            FocusSetApplicationOption(bundleIdentifier: $0.bundleIdentifier, presentationName: $0.name)
        }
        applicationsByIdentity.removeAll(keepingCapacity: true)
        for (application, option) in zip(applications, applicationOptions) {
            if applicationsByIdentity[option.identity] == nil {
                applicationsByIdentity[option.identity] = application
            }
        }
    }

    private func updateTitle() {
        title = String(format: NSLocalizedString("Editing “%@”", comment: ""), focusSet.name)
    }

    private func installSearchObserver() {
        textObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: searchField,
            queue: .main
        ) { [weak self] _ in
            self?.updateSearchQuery()
        }
    }

    private func updateSearchQuery() {
        let query = searchField.stringValue
        guard searchQuery != query else { return }
        searchQuery = query
        rebuildRows(scrollToTop: true)
    }

    private func rebuildRows(scrollToTop shouldScrollToTop: Bool = false) {
        let focusedIdentity = focusedApplicationIdentity()
        selectionCountLabel.stringValue = selectionCount()
        rows.arrangedSubviews.forEach {
            rows.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        identityBySwitch.removeAll(keepingCapacity: true)
        switchesByIdentity.removeAll(keepingCapacity: true)
        let entries = filteredEntries()
        if entries.isEmpty {
            let label = NSTextField(wrappingLabelWithString: NSLocalizedString("No matching applications.", comment: ""))
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            rows.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        } else {
            for entry in entries {
                let row = makeRow(entry)
                rows.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            }
        }
        if shouldScrollToTop { scrollToTop() }
        restoreFocusedApplication(focusedIdentity)
    }

    private func focusedApplicationIdentity() -> FocusSetApplicationIdentity? {
        guard let toggle = firstResponder as? Switch else { return nil }
        return identityBySwitch[ObjectIdentifier(toggle)]
    }

    private func restoreFocusedApplication(_ identity: FocusSetApplicationIdentity?) {
        guard let identity, let toggle = switchesByIdentity[identity] else { return }
        makeFirstResponder(toggle)
    }

    private func scrollToTop() {
        guard let resultsScrollView else { return }
        resultsScrollView.contentView.scroll(to: .zero)
        resultsScrollView.reflectScrolledClipView(resultsScrollView.contentView)
    }

    private func filteredEntries() -> [FocusSetPickerEntry] {
        FocusSetSettingsResolver.filteredApplicationPickerRows(
            applications: applicationOptions,
            rules: currentRules,
            matching: searchQuery
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
        switchesByIdentity[entry.identity] = toggle
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [icon, labels, spacer, toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = TableGroupView.spacing
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignSystem.Metrics.standardControlMinHeight).isActive = true
        return row
    }

    private func selectionCount() -> String {
        switch selectedIdentities.count {
        case 0:
            return NSLocalizedString("No applications selected", comment: "")
        case 1:
            return NSLocalizedString("1 application selected", comment: "")
        default:
            return String(format: NSLocalizedString("%d applications selected", comment: ""), selectedIdentities.count)
        }
    }

    private func addCancelButton() {
        let cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel(_:)))
        cancelButton.keyEquivalent = "\u{1b}"
        DesignSystemControlStyler.styleButton(cancelButton)
        addFooterButton(cancelButton)
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
        updateSearchQuery()
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
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            NSSound.beep()
            makeFirstResponder(nameField)
            return
        }
        onApply?(
            FocusSet(
                id: focusSet.id,
                name: name,
                rules: currentRules,
                shortcutKeyEquivalent: shortcutKeyEquivalent),
            conflictingShortcutActionIdentifier)
        sheetParent?.endSheet(self)
    }
}
