import Cocoa
import ShortcutRecorder

final class FocusSetSettingsView: NSView {
    static let focusSetsCategoryLabel = NSLocalizedString("Focus Sets", comment: "")
    static let behaviorCategoryLabel = NSLocalizedString("Behavior", comment: "")
    static let behaviorTableTitle = NSLocalizedString("Focus Set Behavior", comment: "")
    static let directShortcutReleaseSubtitle = NSLocalizedString("Applies to every direct Focus Set shortcut.", comment: "")
    static let appearanceAndOrganizationSubtitle = NSLocalizedString("Direct Focus Set shortcuts use the standard appearance and window organization.", comment: "")
    static let focusSetsDetailSubtitle = NSLocalizedString("Choose a Focus Set to review its shortcut and included applications.", comment: "")
    static let focusSetManagerSearchableStrings = [
        focusSetsCategoryLabel,
        focusSetsDetailSubtitle,
        NSLocalizedString("Add Focus Set", comment: ""),
        NSLocalizedString("No Focus Sets", comment: ""),
        NSLocalizedString("Create a Focus Set to browse the applications you use together.", comment: ""),
        NSLocalizedString("Shortcut", comment: ""),
        NSLocalizedString("Not assigned", comment: ""),
        NSLocalizedString("Edit Focus Set…", comment: ""),
        NSLocalizedString("Editing “%@”", comment: ""),
        NSLocalizedString("Move Up", comment: ""),
        NSLocalizedString("Move Down", comment: ""),
        NSLocalizedString("Name", comment: ""),
        ShortcutTriggerRow.triggerLabel,
        ShortcutTriggerRow.holdLabelText,
        ShortcutTriggerRow.andPressText,
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
        NSLocalizedString("Cancel", comment: ""),
        NSLocalizedString("Apply", comment: ""),
    ]
    static let behaviorSearchableStrings = [
        behaviorCategoryLabel,
        behaviorTableTitle,
        NSLocalizedString("After keys are released", comment: ""),
        directShortcutReleaseSubtitle,
        NSLocalizedString("Visibility", comment: ""),
        NSLocalizedString("Shows applications from all Spaces and screens, with standard handling for hidden, minimized, fullscreen, and windowless windows.", comment: ""),
        NSLocalizedString("Appearance and organization", comment: ""),
        appearanceAndOrganizationSubtitle,
        NSLocalizedString("Open Appearance Settings", comment: ""),
    ] + ShortcutStylePreference.allCases.map(\.localizedString)
    static let searchableStrings = focusSetManagerSearchableStrings + behaviorSearchableStrings

    private let store = FocusSetsStore()
    private let contentWidth: CGFloat
    private var configuration = FocusSetsConfiguration()
    private var selectedFocusSetIdentifier: UUID?
    private var content: NSView?
    private var contentConstraints = [NSLayoutConstraint]()
    private let focusSetsCategoryIndex = 0
    private let behaviorCategoryIndex = 1
    private var selectedCategoryIndex = 0
    private weak var categoryControl: NSSegmentedControl?
    private weak var focusSetManagerView: NSView?
    private weak var behaviorView: NSView?
    private let focusSetSidebarWidth = CGFloat(280)
    private let focusSetSidebarRowHeight = CGFloat(56)
    private var focusSetRows = [SidebarListRow]()
    private weak var focusSetRowsStackView: NSStackView?
    private weak var focusSetRowsScrollView: NSScrollView?
    private weak var focusSetSidebarSection: SidebarListContainer?
    private weak var focusSetDetailPane: NSView?
    private var focusSetRowsScrollObserver: NSObjectProtocol?
    private weak var focusSetCountButtons: NSSegmentedControl?

    init(width: CGFloat) {
        contentWidth = width
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let focusSetRowsScrollObserver {
            NotificationCenter.default.removeObserver(focusSetRowsScrollObserver)
        }
    }

    func refresh() {
        let refreshedConfiguration = store.read()
        let setsChanged = configuration.sets != refreshedConfiguration.sets
        configuration = refreshedConfiguration
        selectedFocusSetIdentifier = FocusSetSettingsResolver.selectedFocusSetIdentifier(
            preferredIdentifier: selectedFocusSetIdentifier,
            sets: configuration.sets)
        if content == nil {
            rebuildContent()
        } else if setsChanged {
            refreshFocusSetManager()
        }
    }

    func registerSidebarRowsSearchContent() {
        focusSetRows.forEach { $0.registerSearchContent() }
    }

    private func rebuildContent() {
        clearFocusSetManagerReferences()
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints.removeAll(keepingCapacity: true)
        content?.removeFromSuperview()
        content = nil
        categoryControl = nil
        focusSetManagerView = nil
        behaviorView = nil
        let manager = makeFocusSetManager()
        let behavior = makeBehaviorTable()
        focusSetManagerView = manager
        behaviorView = behavior
        let content = NSStackView(views: [makeCategoryControl(), manager, behavior])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = TableGroupSetView.othersSpacing
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
        refreshVisibleCategory()
        refreshFocusSetManager()
    }

    private func makeCategoryControl() -> NSSegmentedControl {
        let labels = [Self.focusSetsCategoryLabel, Self.behaviorCategoryLabel]
        let control = DesignSystemSegmentedControl(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        control.selectedSegment = selectedCategoryIndex
        LabelAndControl.applySystemSelectedSegmentStyle(control)
        control.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        let segmentWidth = contentWidth / CGFloat(labels.count)
        for index in labels.indices { control.setWidth(segmentWidth, forSegment: index) }
        control.onAction = { [weak self, weak control] _ in
            guard let self, let control else { return }
            self.selectCategory(control.selectedSegment)
        }
        FocusSetSettingsResolver.registerCategorySearchContent(
            for: ObjectIdentifier(control),
            focusSetManagerStrings: Self.focusSetManagerSearchableStrings,
            behaviorStrings: Self.behaviorSearchableStrings,
            in: &FocusSetsTab.tabSegmentSearchableStrings)
        categoryControl = control
        return control
    }

    private func selectCategory(_ index: Int) {
        guard index == focusSetsCategoryIndex || index == behaviorCategoryIndex else { return }
        selectedCategoryIndex = index
        refreshVisibleCategory()
    }

    private func refreshVisibleCategory() {
        categoryControl?.selectedSegment = selectedCategoryIndex
        focusSetManagerView?.isHidden = selectedCategoryIndex != focusSetsCategoryIndex
        behaviorView?.isHidden = selectedCategoryIndex != behaviorCategoryIndex
    }

    private func makeBehaviorTable() -> NSView {
        let table = TableGroupView(
            title: Self.behaviorTableTitle,
            width: DesignSystemCenteredDetailPage.contentWidth(for: contentWidth))
        let releaseStyle = LabelAndControl.makeDropdown("focusSetsShortcutStyle", ShortcutStylePreference.allCases)
        _ = table.addRow(
            leftText: NSLocalizedString("After keys are released", comment: ""),
            rightViews: [releaseStyle],
            subText: Self.directShortcutReleaseSubtitle)
        _ = table.addRow(
            leftText: NSLocalizedString("Visibility", comment: ""),
            subText: NSLocalizedString("Shows applications from all Spaces and screens, with standard handling for hidden, minimized, fullscreen, and windowless windows.", comment: ""))
        let appearanceButton = DesignSystemControlStyler.makeButton(
            NSLocalizedString("Open Appearance Settings", comment: ""),
            target: self,
            action: #selector(openAppearanceSettings(_:)))
        _ = table.addRow(
            leftText: NSLocalizedString("Appearance and organization", comment: ""),
            rightViews: [appearanceButton],
            subText: Self.appearanceAndOrganizationSubtitle)
        return DesignSystemCenteredDetailPage(content: table, width: contentWidth)
    }

    private func makeFocusSetManager() -> NSView {
        makeSidebarEditorContainer(
            sidebar: makeFocusSetSidebar(),
            editor: makeFocusSetDetailPane(),
            fixedSidebarHeight: DesignSystem.Metrics.settingsEditorSidebarHeight,
            chrome: .plain,
            layout: .spaced)
    }

    private func makeFocusSetSidebar() -> NSView {
        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(equalToConstant: focusSetSidebarWidth).isActive = true
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let section = SidebarListContainer()
        section.onArrowKey = { [weak self] direction in
            self?.moveFocusSetSelection(direction)
        }
        focusSetSidebarSection = section
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        focusSetRowsStackView = rows
        let scrollView = ForwardingVerticalScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.verticalScrollElasticity = .none
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.usesPredominantAxisScrolling = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        let documentView = ForwardingVerticalDocumentView(frame: .zero)
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        documentView.addSubview(rows)
        focusSetRowsScrollView = scrollView
        installFocusSetSidebarHoverObserver(scrollView)
        let buttons = makeFocusSetCountButtons()
        section.addSubview(scrollView)
        container.addSubview(section)
        container.addSubview(buttons)
        sidebar.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: sidebar.topAnchor),
            container.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            rows.topAnchor.constraint(equalTo: documentView.topAnchor),
            rows.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            rows.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor),
            section.topAnchor.constraint(equalTo: container.topAnchor, constant: TableGroupView.padding),
            section.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            section.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -TableGroupView.padding),
            scrollView.topAnchor.constraint(equalTo: section.topAnchor, constant: DesignSystem.Metrics.rowHorizontalPadding),
            scrollView.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: DesignSystem.Metrics.rowHorizontalPadding),
            scrollView.trailingAnchor.constraint(equalTo: section.trailingAnchor, constant: -DesignSystem.Metrics.rowHorizontalPadding),
            scrollView.bottomAnchor.constraint(equalTo: section.bottomAnchor, constant: -DesignSystem.Metrics.rowHorizontalPadding),
            buttons.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignSystem.Metrics.headerFooterGap),
            buttons.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -TableGroupView.sidebarToolRowHorizontalPadding),
            buttons.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -TableGroupView.padding),
        ])
        return sidebar
    }

    private func makeFocusSetCountButtons() -> NSView {
        let plus = NSImage.fromSymbol(.plus, pointSize: 11)
        let minus = NSImage.fromSymbol(.minus, pointSize: 11)
        let buttons = DesignSystemSegmentedControl(
            images: [plus, minus],
            trackingMode: .momentary,
            target: self,
            action: #selector(focusSetCountButtonClicked(_:)))
        DesignSystemControlStyler.styleSegmentedControl(buttons)
        buttons.setWidth(28, forSegment: 0)
        buttons.setWidth(28, forSegment: 1)
        buttons.toolTip = NSLocalizedString("Add or remove Focus Sets", comment: "")
        buttons.setAccessibilityLabel(NSLocalizedString("Focus Set actions", comment: ""))
        focusSetCountButtons = buttons
        let row = StackView([buttons], .horizontal, false)
        row.alignment = .leading
        return row
    }

    private func makeFocusSetDetailPane() -> NSView {
        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = false
        pane.widthAnchor.constraint(equalToConstant: focusSetDetailWidth).isActive = true
        focusSetDetailPane = pane
        return pane
    }

    private var focusSetDetailWidth: CGFloat {
        contentWidth - focusSetSidebarWidth - DesignSystem.Metrics.sectionGap
    }

    private var focusSetDetailTableWidth: CGFloat {
        focusSetDetailWidth - 2 * TableGroupView.padding
    }

    private func refreshFocusSetManager() {
        selectedFocusSetIdentifier = FocusSetSettingsResolver.selectedFocusSetIdentifier(
            preferredIdentifier: selectedFocusSetIdentifier,
            sets: configuration.sets)
        refreshFocusSetRows()
        rebuildFocusSetDetail()
        refreshFocusSetCountButtons()
    }

    private func refreshFocusSetRows() {
        guard let rowsStack = focusSetRowsStackView else { return }
        setHoveredFocusSetRow(nil)
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        while focusSetRows.count < configuration.sets.count {
            focusSetRows.append(makeFocusSetRow())
        }
        if focusSetRows.count > configuration.sets.count {
            focusSetRows.removeLast(focusSetRows.count - configuration.sets.count)
        }
        for (index, focusSet) in configuration.sets.enumerated() {
            let row = focusSetRows[index]
            row.setContent(focusSet.name, includedApplicationLabel(for: focusSet))
            row.setSelected(focusSet.id == selectedFocusSetIdentifier)
            rowsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            row.heightAnchor.constraint(equalToConstant: focusSetSidebarRowHeight).isActive = true
            if index < configuration.sets.count - 1 {
                let separator = sidebarSeparatorView()
                rowsStack.addArrangedSubview(separator)
                separator.leadingAnchor.constraint(equalTo: rowsStack.leadingAnchor, constant: TableGroupView.padding).isActive = true
                separator.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor, constant: -TableGroupView.padding).isActive = true
                separator.heightAnchor.constraint(equalToConstant: TableGroupView.borderWidth).isActive = true
            }
        }
        syncFocusSetSidebarHoverState()
        SettingsWindow.shared?.refreshSectionSearchContent("focusSets")
    }

    private func makeFocusSetRow() -> SidebarListRow {
        let row = SidebarListRow()
        row.onClick = { [weak self, weak row] _, _ in
            guard let self,
                  let row,
                  let index = self.focusSetRows.firstIndex(where: { $0 === row }) else { return }
            self.selectFocusSet(at: index)
            self.focusSetSidebarSection?.window?.makeFirstResponder(self.focusSetSidebarSection)
        }
        row.onMouseEntered = { [weak self, weak row] _, _ in
            self?.setHoveredFocusSetRow(row)
        }
        row.onMouseExited = { [weak self] _, _ in
            self?.setHoveredFocusSetRow(nil)
        }
        return row
    }

    private func selectFocusSet(at index: Int) {
        guard configuration.sets.indices.contains(index) else { return }
        selectedFocusSetIdentifier = configuration.sets[index].id
        focusSetRows.enumerated().forEach { rowIndex, row in
            row.setSelected(rowIndex == index)
        }
        focusSetRows[index].scrollToVisible(focusSetRows[index].bounds)
        rebuildFocusSetDetail()
        refreshFocusSetCountButtons()
    }

    private func moveFocusSetSelection(_ direction: SidebarListContainer.ArrowDirection) {
        guard !configuration.sets.isEmpty else { return }
        let currentIndex = configuration.sets.firstIndex { $0.id == selectedFocusSetIdentifier } ?? 0
        let nextIndex: Int
        switch direction {
        case .up:
            nextIndex = max(0, currentIndex - 1)
        case .down:
            nextIndex = min(configuration.sets.count - 1, currentIndex + 1)
        }
        guard nextIndex != currentIndex else { return }
        selectFocusSet(at: nextIndex)
    }

    private func rebuildFocusSetDetail() {
        guard let pane = focusSetDetailPane else { return }
        pane.subviews.forEach { $0.removeFromSuperview() }
        let table = makeFocusSetDetailTable()
        pane.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: pane.topAnchor, constant: TableGroupView.padding),
            table.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: TableGroupView.padding),
            table.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -TableGroupView.padding),
        ])
    }

    private func makeFocusSetDetailTable() -> TableGroupView {
        let table = TableGroupView(
            title: NSLocalizedString("Focus Sets", comment: ""),
            subTitle: Self.focusSetsDetailSubtitle,
            width: focusSetDetailTableWidth)
        guard let focusSet = selectedFocusSet else {
            let add = DesignSystemControlStyler.makeButton(
                NSLocalizedString("Add Focus Set", comment: ""),
                target: self,
                action: #selector(addFocusSet(_:)))
            _ = table.addRow(
                leftText: NSLocalizedString("No Focus Sets", comment: ""),
                rightViews: [add],
                subText: NSLocalizedString("Create a Focus Set to browse the applications you use together.", comment: ""))
            return table
        }
        let shortcut = makeDetailValueLabel(focusSet.shortcutKeyEquivalent ?? NSLocalizedString("Not assigned", comment: ""))
        let applications = makeDetailValueLabel(includedApplicationLabel(for: focusSet))
        _ = table.addRow(leftText: NSLocalizedString("Name", comment: ""),
                         rightViews: [makeDetailValueLabel(focusSet.name)])
        _ = table.addRow(leftText: NSLocalizedString("Shortcut", comment: ""),
                         rightViews: [shortcut])
        _ = table.addRow(leftText: NSLocalizedString("Included Applications", comment: ""),
                         rightViews: [applications])
        if let index = configuration.sets.firstIndex(where: { $0.id == focusSet.id }) {
            let move = NSLocalizedString("Move Up", comment: "") + " / " + NSLocalizedString("Move Down", comment: "")
            _ = table.addRow(leftText: move, rightViews: [makeReorderMenu(for: focusSet, at: index)])
        }
        let edit = DesignSystemControlStyler.makeButton(
            NSLocalizedString("Edit Focus Set…", comment: ""),
            target: self,
            action: #selector(editSelectedFocusSet(_:)))
        _ = table.addRow(leftText: nil, rightViews: [edit])
        return table
    }

    private func makeDetailValueLabel(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private var selectedFocusSet: FocusSet? {
        guard let selectedFocusSetIdentifier else { return nil }
        return configuration.sets.first { $0.id == selectedFocusSetIdentifier }
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

    private func includedApplicationLabel(for focusSet: FocusSet) -> String {
        let count = FocusSetSettingsResolver.includedApplicationCount(focusSet.rules)
        if count == 1 { return NSLocalizedString("1 included application", comment: "") }
        return String(format: NSLocalizedString("%d included applications", comment: ""), count)
    }

    private func liveApplications() -> [FocusSetApplication] {
        var identifiers = Set<String>()
        var applications = [FocusSetApplication]()
        for application in Applications.list {
            guard let bundleIdentifier = application.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !bundleIdentifier.isEmpty,
                  identifiers.insert(bundleIdentifier).inserted,
                  let name = application.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            applications.append(FocusSetApplication(bundleIdentifier: bundleIdentifier,
                                                    name: name,
                                                    icon: application.runningApplication.icon ?? AppDisplayInfo.genericIcon))
        }
        return applications
    }

    private func persist(_ sets: [FocusSet]) {
        let next = FocusSetsConfiguration(version: configuration.version,
                                          sets: sets)
        guard store.set(next) else {
            NSSound.beep()
            return
        }
        refresh()
        App.refreshOpenUiAfterFocusSetConfigurationChange()
    }

    @objc private func addFocusSet(_ sender: NSControl) {
        let focusSet = FocusSet(name: NSLocalizedString("New Focus Set", comment: ""), rules: [])
        showFocusSetEditor(focusSet)
    }

    @objc private func focusSetCountButtonClicked(_ sender: NSSegmentedControl) {
        let segment = sender.selectedSegment
        sender.selectedSegment = -1
        if segment == 0 {
            addFocusSet(sender)
        } else if segment == 1 {
            deleteSelectedFocusSet()
        }
    }

    @objc private func editSelectedFocusSet(_ sender: NSButton) {
        guard let focusSet = selectedFocusSet else { return }
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
        guard store.set(next) else {
            NSSound.beep()
            return
        }
        if let actionIdentifier,
           FocusSetShortcutBindingResolver.focusSetIdentifier(from: actionIdentifier) == nil {
            ControlsTab.unassignShortcutConflict(actionIdentifier)
        }
        selectedFocusSetIdentifier = focusSet.id
        refresh()
        App.refreshOpenUiAfterFocusSetConfigurationChange()
    }

    private func deleteSelectedFocusSet() {
        guard let identifier = selectedFocusSetIdentifier else { return }
        deleteFocusSet(with: identifier)
    }

    private func deleteFocusSet(with identifier: UUID) {
        guard let next = FocusSetSettingsResolver.configurationByDeletingFocusSet(identifier, from: configuration) else {
            NSSound.beep()
            refresh()
            return
        }
        guard store.set(next) else {
            NSSound.beep()
            return
        }
        let persisted = store.read()
        guard persisted == next else {
            NSSound.beep()
            refresh()
            return
        }
        refresh()
        App.refreshOpenUiAfterFocusSetConfigurationChange()
    }

    private func refreshFocusSetCountButtons() {
        focusSetCountButtons?.setEnabled(true, forSegment: 0)
        focusSetCountButtons?.setEnabled(selectedFocusSetIdentifier != nil, forSegment: 1)
    }

    private func installFocusSetSidebarHoverObserver(_ scrollView: NSScrollView) {
        if let focusSetRowsScrollObserver {
            NotificationCenter.default.removeObserver(focusSetRowsScrollObserver)
        }
        focusSetRowsScrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            self?.syncFocusSetSidebarHoverState()
        }
    }

    private func setHoveredFocusSetRow(_ row: SidebarListRow?) {
        focusSetRows.forEach { $0.setHovered($0 === row) }
    }

    private func syncFocusSetSidebarHoverState() {
        guard let scrollView = focusSetRowsScrollView,
              let window = scrollView.window else { return }
        let location = scrollView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard scrollView.bounds.contains(location),
              let documentView = scrollView.documentView else {
            setHoveredFocusSetRow(nil)
            return
        }
        let locationInDocument = documentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        setHoveredFocusSetRow(enclosingFocusSetRow(documentView.hitTest(locationInDocument)))
    }

    private func enclosingFocusSetRow(_ view: NSView?) -> SidebarListRow? {
        var current = view
        while let candidate = current {
            if let row = candidate as? SidebarListRow { return row }
            current = candidate.superview
        }
        return nil
    }

    private func clearFocusSetManagerReferences() {
        if let focusSetRowsScrollObserver {
            NotificationCenter.default.removeObserver(focusSetRowsScrollObserver)
            self.focusSetRowsScrollObserver = nil
        }
        focusSetRows.removeAll()
        focusSetRowsStackView = nil
        focusSetRowsScrollView = nil
        focusSetSidebarSection = nil
        focusSetDetailPane = nil
        focusSetCountButtons = nil
    }

    @objc private func openAppearanceSettings(_ sender: NSButton) {
        SettingsWindow.shared.navigate(to: .appearance)
    }

}

private struct FocusSetApplication {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage
}

private struct FocusSetApplicationEntry {
    let identity: FocusSetApplicationIdentity
    let name: String
    let icon: NSImage
    let isAvailable: Bool
    let isSelected: Bool
}

private final class FocusSetEditorSheet: SheetWindow {
    private let nameField = NSTextField()
    private let modifierRecorder = CustomRecorderControl(nil, true, "focusSetShortcut:pending")
    private let keyRecorder = CustomRecorderControl(nil, true, "focusSetShortcut:pending")
    private let searchField = NSSearchField()
    private let selectionCountLabel = NSTextField(labelWithString: "")
    private let rows = NSStackView()
    private var applicationOptions = [FocusSetApplicationOption]()
    private var applicationsByIdentity = [FocusSetApplicationIdentity: FocusSetApplication]()
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
                     applications: [FocusSetApplication],
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
        configureShortcutTrigger(focusSet)
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
        let trigger = ShortcutTriggerRow(holdControl: modifierRecorder, pressControl: keyRecorder)
        _ = table.addRow(leftText: ShortcutTriggerRow.triggerLabel, rightViews: [trigger.view])
        return table
    }

    private func configureShortcutTrigger(_ focusSet: FocusSet) {
        let actionIdentifier = NSUserInterfaceItemIdentifier(
            FocusSetShortcutBindingResolver.actionIdentifier(for: focusSet.id))
        let trigger = FocusSetShortcutBindingResolver.trigger(for: focusSet.shortcutKeyEquivalent)
        modifierRecorder.identifier = actionIdentifier
        modifierRecorder.allowsModifierFlagsOnlyShortcut = true
        modifierRecorder.restrictModifiers([])
        modifierRecorder.objectValue = trigger?.modifier
        modifierRecorder.setAccessibilityLabel(ShortcutTriggerRow.holdLabelText)
        modifierRecorder.transactionalCandidateHandler = { [weak self] shortcut, _ in
            self?.recordModifier(shortcut) ?? false
        }
        modifierRecorder.onAction = { [weak self] _ in
            guard let self, self.modifierRecorder.objectValue == nil else { return }
            self.clearShortcut()
        }
        keyRecorder.identifier = actionIdentifier
        keyRecorder.allowsModifierFlagsOnlyShortcut = false
        keyRecorder.restrictModifiers(CustomRecorderControl.allowedModifiers)
        keyRecorder.objectValue = trigger?.key
        keyRecorder.setAccessibilityLabel(ShortcutTriggerRow.andPressText)
        keyRecorder.transactionalCandidateHandler = { [weak self] shortcut, _ in
            self?.recordKey(shortcut) ?? false
        }
        keyRecorder.onAction = { [weak self] _ in
            guard let self, self.keyRecorder.objectValue == nil else { return }
            self.clearShortcut()
        }
        shortcutKeyEquivalent = trigger == nil ? nil : focusSet.shortcutKeyEquivalent
    }

    private func recordModifier(_ shortcut: Shortcut) -> Bool {
        guard FocusSetShortcutBindingResolver.isModifierShortcut(shortcut) else { return false }
        return recordTrigger(modifier: shortcut, key: keyRecorder.objectValue)
    }

    private func recordKey(_ shortcut: Shortcut) -> Bool {
        guard FocusSetShortcutBindingResolver.isKeyShortcut(shortcut) else { return false }
        return recordTrigger(modifier: modifierRecorder.objectValue, key: shortcut)
    }

    private func recordTrigger(modifier: Shortcut?, key: Shortcut?) -> Bool {
        guard let modifier,
              let key else {
            clearShortcut()
            return true
        }
        guard let shortcut = FocusSetShortcutBindingResolver.shortcut(modifier: modifier, key: key) else {
            return false
        }
        return acceptShortcut(shortcut)
    }

    private func clearShortcut() {
        shortcutKeyEquivalent = nil
        conflictingShortcutActionIdentifier = nil
    }

    private func acceptShortcut(_ shortcut: Shortcut) -> Bool {
        let acceptance = CustomRecorderControlTestable.isShortcutAcceptable(
            modifierRecorder.id,
            shortcut)
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
            guard modifierRecorder.confirmUnassigningShortcut(actionIdentifier) else { return false }
            shortcutKeyEquivalent = shortcut.keyEquivalent
            conflictingShortcutActionIdentifier = actionIdentifier
            return true
        case .reservedByMacos(let actionIdentifier):
            guard modifierRecorder.confirmUnassigningShortcutReservedByMacos(actionIdentifier) else { return false }
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

    private func configureApplications(_ applications: [FocusSetApplication]) {
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

    private func filteredEntries() -> [FocusSetApplicationEntry] {
        FocusSetSettingsResolver.filteredApplicationPickerRows(
            applications: applicationOptions,
            rules: currentRules,
            matching: searchQuery
        ).map { row in
            let application = applicationsByIdentity[row.identity]
            return FocusSetApplicationEntry(
                identity: row.identity,
                name: displayName(row),
                icon: application?.icon ?? AppDisplayInfo.genericIcon,
                isAvailable: row.isAvailable,
                isSelected: row.isSelected)
        }
    }

    private func makeRow(_ entry: FocusSetApplicationEntry) -> NSStackView {
        let icon = NSImageView(image: entry.icon)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let title = NSTextField(labelWithString: entry.name)
        title.font = NSFont.systemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingTail
        let labels = NSStackView(views: [title])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let subtitle = subtitle(for: entry)
        if !subtitle.isEmpty {
            let label = NSTextField(labelWithString: subtitle)
            label.font = NSFont.systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            labels.addArrangedSubview(label)
        }
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

    private func subtitle(for entry: FocusSetApplicationEntry) -> String {
        guard !entry.isAvailable else { return "" }
        return NSLocalizedString("Not currently open", comment: "")
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
