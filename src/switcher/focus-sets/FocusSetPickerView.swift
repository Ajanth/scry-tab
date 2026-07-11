import Cocoa

private final class FocusSetPickerRow: SidebarListRow {
    var onAccessibilityPress: (() -> Bool)?
    var itemIndex: Int?
    var itemIdentifier: FocusSetPickerItemIdentifier?

    override func accessibilityPerformPress() -> Bool {
        onAccessibilityPress?() ?? false
    }
}

private final class FocusSetPickerDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class FocusSetPickerView: NSView {
    typealias CandidateCountSummary = (Int) -> String

    var onSelectionChange: ((FocusSetPickerItemIdentifier?) -> Void)?
    var onQueryChange: ((String) -> Void)?
    var onConfirm: ((FocusSetPickerItem) -> Void)?
    var onDismiss: (() -> Void)?

    var resolver: FocusSetPickerResolver {
        get { resolverStorage }
        set {
            requireMainThread()
            resolverStorage = newValue
            reloadRows()
        }
    }

    var selectedIdentifier: FocusSetPickerItemIdentifier? {
        get { selectedIdentifierStorage }
        set { restoreSelection(newValue) }
    }

    var query: String {
        get { queryStorage }
        set { setQuery(newValue) }
    }

    var visibleItemCount: Int { visibleItems.count }

    private let builtInNames: FocusSetPickerBuiltInNames
    private let candidateCountSummary: CandidateCountSummary
    private let searchField = NSSearchField()
    private let contentStack = NSStackView()
    private let listContainer = SidebarListContainer()
    private let rowsScrollView = NSScrollView()
    private let rowsDocumentView = FocusSetPickerDocumentView()
    private let rowsStack = NSStackView()
    private var resolverStorage: FocusSetPickerResolver
    private var selectedIdentifierStorage: FocusSetPickerItemIdentifier?
    private var queryStorage: String
    private var visibleItems = [FocusSetPickerItem]()
    private var rowViews = [FocusSetPickerRow]()
    private var separatorViews = [NSView]()
    private weak var hoveredRow: FocusSetPickerRow?
    private var textObserver: NSObjectProtocol?

    init(resolver: FocusSetPickerResolver,
         selectedIdentifier: FocusSetPickerItemIdentifier? = nil,
         query: String? = nil,
         builtInNames: FocusSetPickerBuiltInNames,
         searchPlaceholder: String? = nil,
         searchAccessibilityLabel: String? = nil,
         candidateCountSummary: @escaping CandidateCountSummary) {
        resolverStorage = resolver
        selectedIdentifierStorage = selectedIdentifier
        queryStorage = query ?? ""
        self.builtInNames = builtInNames
        self.candidateCountSummary = candidateCountSummary
        super.init(frame: .zero)
        configure(searchPlaceholder: searchPlaceholder, searchAccessibilityLabel: searchAccessibilityLabel)
        reloadRows(notifySelectionChange: false)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let textObserver {
            NotificationCenter.default.removeObserver(textObserver)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        guard let window else { return super.becomeFirstResponder() }
        return window.makeFirstResponder(searchField)
    }

    override func cancelOperation(_ sender: Any?) {
        handleEscape()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DesignSystemControlStyler.refreshSearchField(searchField)
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        DesignSystemControlStyler.refreshSearchField(searchField)
    }

    func update(resolver: FocusSetPickerResolver,
                selectedIdentifier: FocusSetPickerItemIdentifier?,
                query: String? = nil) {
        requireMainThread()
        resolverStorage = resolver
        selectedIdentifierStorage = selectedIdentifier
        if let query, queryStorage != query, !hasMarkedText() {
            queryStorage = query
            setSearchFieldStringValueIfNeeded(query)
        }
        reloadRows(notifySelectionChange: false)
    }

    func restoreSelection(_ identifier: FocusSetPickerItemIdentifier?) {
        requireMainThread()
        selectedIdentifierStorage = identifier
        reloadRows(notifySelectionChange: false)
    }

    func setQuery(_ query: String) {
        requireMainThread()
        guard queryStorage != query else { return }
        queryStorage = query
        setSearchFieldStringValueIfNeeded(query)
        reloadRows()
        onQueryChange?(query)
    }

    func clearQuery() {
        setQuery("")
    }

    @discardableResult
    func selectPrevious() -> FocusSetPickerItemIdentifier? {
        moveSelection(.previous)
    }

    @discardableResult
    func selectNext() -> FocusSetPickerItemIdentifier? {
        moveSelection(.next)
    }

    @discardableResult
    func moveSelection(_ direction: FocusSetPickerNavigationDirection) -> FocusSetPickerItemIdentifier? {
        requireMainThread()
        let currentIndex = selectedVisibleIndex()
        guard let nextIndex = FocusSetPickerResolver.cycledSelectionIndex(
            currentIndex,
            direction: direction,
            itemCount: visibleItems.count) else {
            updateSelection(identifier: nil, index: nil)
            return nil
        }
        return selectRow(at: nextIndex)
    }

    @discardableResult
    func confirmSelection() -> FocusSetPickerItem? {
        requireMainThread()
        guard let item = resolverStorage.confirmedItem(
            selectedIdentifier: selectedIdentifierStorage,
            matching: queryStorage) else {
            return nil
        }
        onConfirm?(item)
        return item
    }

    func dismiss() {
        requireMainThread()
        onDismiss?()
    }

    func handleCancel() {
        handleEscape()
    }

    @discardableResult
    func focusSearchField() -> Bool {
        requireMainThread()
        guard let window else { return false }
        if let editor = searchField.currentEditor(), window.firstResponder === editor {
            return true
        }
        guard window.makeFirstResponder(searchField) else { return false }
        guard let editor = searchField.currentEditor() else { return true }
        editor.selectedRange = NSRange(location: searchField.stringValue.utf16.count, length: 0)
        return true
    }

    func hasMarkedText() -> Bool {
        (searchField.currentEditor() as? NSTextView)?.hasMarkedText() == true
    }

    private func configure(searchPlaceholder: String?, searchAccessibilityLabel: String?) {
        requireMainThread()
        translatesAutoresizingMaskIntoConstraints = false
        configureSearchField(searchPlaceholder: searchPlaceholder, searchAccessibilityLabel: searchAccessibilityLabel)
        configureRows()
        configureContent()
        textObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: searchField,
            queue: .main) { [weak self] _ in
                self?.searchTextDidChange()
            }
    }

    private func configureSearchField(searchPlaceholder: String?, searchAccessibilityLabel: String?) {
        searchField.stringValue = queryStorage
        searchField.placeholderString = searchPlaceholder
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.delegate = self
        if let searchAccessibilityLabel = searchAccessibilityLabel ?? searchPlaceholder {
            searchField.setAccessibilityLabel(searchAccessibilityLabel)
        }
        DesignSystemControlStyler.styleSearchField(searchField)
    }

    private func configureRows() {
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 0
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        rowsScrollView.translatesAutoresizingMaskIntoConstraints = false
        rowsScrollView.drawsBackground = false
        rowsScrollView.hasVerticalScroller = true
        rowsScrollView.verticalScrollElasticity = .none
        rowsScrollView.hasHorizontalScroller = false
        rowsScrollView.scrollerStyle = .overlay
        rowsScrollView.usesPredominantAxisScrolling = true
        rowsScrollView.documentView = rowsDocumentView

        rowsDocumentView.translatesAutoresizingMaskIntoConstraints = false
        rowsDocumentView.setAccessibilityElement(true)
        rowsDocumentView.setAccessibilityRole(.list)
        rowsDocumentView.addSubview(rowsStack)
        listContainer.onArrowKey = { [weak self] direction in
            switch direction {
            case .up: _ = self?.selectPrevious()
            case .down: _ = self?.selectNext()
            }
        }
        listContainer.addSubview(rowsScrollView)
        NSLayoutConstraint.activate([
            rowsDocumentView.widthAnchor.constraint(equalTo: rowsScrollView.contentView.widthAnchor),
            rowsDocumentView.heightAnchor.constraint(greaterThanOrEqualTo: rowsScrollView.contentView.heightAnchor),
            rowsStack.topAnchor.constraint(equalTo: rowsDocumentView.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: rowsDocumentView.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: rowsDocumentView.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: rowsDocumentView.bottomAnchor),
            rowsScrollView.topAnchor.constraint(equalTo: listContainer.topAnchor),
            rowsScrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor),
            rowsScrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor),
            rowsScrollView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor),
        ])
    }

    private func configureContent() {
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = DesignSystem.Metrics.headerFooterGap
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(searchField)
        contentStack.addArrangedSubview(listContainer)
        addSubview(contentStack)
        NSLayoutConstraint.activate([
            searchField.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            listContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func searchTextDidChange() {
        requireMainThread()
        setQuery(searchField.stringValue)
    }

    private func reloadRows(notifySelectionChange: Bool = true) {
        let previousIdentifier = selectedIdentifierStorage
        let previousIndex = selectedVisibleIndex()
        visibleItems = resolverStorage.visibleItems(matching: queryStorage)
        let restoredIndex = selectedIdentifierStorage.flatMap { identifier in
            visibleItems.firstIndex { $0.identifier == identifier }
        }
        let nextIndex = FocusSetPickerResolver.clampedSelectionIndex(
            restoredIndex ?? previousIndex,
            itemCount: visibleItems.count)
        selectedIdentifierStorage = nextIndex.map { visibleItems[$0].identifier }
        updateRows()
        updateSelectionAppearance()
        if previousIdentifier != selectedIdentifierStorage {
            postAccessibilitySelectionChange()
            if notifySelectionChange {
                onSelectionChange?(selectedIdentifierStorage)
            }
        }
    }

    private func updateRows() {
        rebuildRowPoolIfNeeded()
        let hoveredIdentifier = hoveredRow?.itemIdentifier
        setHoveredRow(nil)
        for (index, row) in rowViews.enumerated() {
            guard visibleItems.indices.contains(index) else {
                row.itemIndex = nil
                row.itemIdentifier = nil
                row.isHidden = true
                continue
            }
            configureRow(row, item: visibleItems[index], index: index)
            row.isHidden = false
        }
        for (index, separator) in separatorViews.enumerated() {
            separator.isHidden = index >= visibleItems.count - 1
        }
        let visibleRows = Array(rowViews.prefix(visibleItems.count))
        rowsDocumentView.setAccessibilityChildren(visibleRows)
        setHoveredRow(visibleRows.first { $0.itemIdentifier == hoveredIdentifier })
        invalidateIntrinsicContentSize()
    }

    private func rebuildRowPoolIfNeeded() {
        guard rowViews.count != resolverStorage.itemCount else { return }
        setHoveredRow(nil)
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowViews.removeAll(keepingCapacity: true)
        separatorViews.removeAll(keepingCapacity: true)
        for index in 0..<resolverStorage.itemCount {
            let row = makeRow()
            rowsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignSystem.Metrics.standardControlMinHeight).isActive = true
            rowViews.append(row)
            if index < resolverStorage.itemCount - 1 {
                let separator = sidebarSeparatorView()
                rowsStack.addArrangedSubview(separator)
                separator.leadingAnchor.constraint(equalTo: rowsStack.leadingAnchor, constant: TableGroupView.padding).isActive = true
                separator.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor, constant: -TableGroupView.padding).isActive = true
                separator.heightAnchor.constraint(equalToConstant: TableGroupView.borderWidth).isActive = true
                separatorViews.append(separator)
            }
        }
    }

    private func makeRow() -> FocusSetPickerRow {
        let row = FocusSetPickerRow()
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.row)
        row.onClick = { [weak self, weak row] _, _ in
            guard let row, let index = row.itemIndex else { return }
            self?.selectAndConfirmRow(at: index)
        }
        row.onMouseEntered = { [weak self, weak row] _, _ in
            self?.setHoveredRow(row)
        }
        row.onMouseExited = { [weak self, weak row] _, _ in
            guard self?.hoveredRow === row else { return }
            self?.setHoveredRow(nil)
        }
        row.onAccessibilityPress = { [weak self, weak row] in
            guard let row, let index = row.itemIndex else { return false }
            return self?.selectAndConfirmRow(at: index) != nil
        }
        return row
    }

    private func configureRow(_ row: FocusSetPickerRow,
                              item: FocusSetPickerItem,
                              index: Int) {
        let title = displayName(for: item.name)
        let summary = candidateCountSummary(max(item.candidateCount, 0))
        row.itemIndex = index
        row.itemIdentifier = item.identifier
        row.setContent(title, summary)
        row.setAccessibilityLabel(title)
        row.setAccessibilityValue(summary)
        row.setAccessibilityHelp(summary)
    }

    private func displayName(for name: FocusSetPickerItemName) -> String {
        switch name {
        case .allWindows: return builtInNames.allWindows
        case let .savedFocusSet(name): return name
        case .unassignedWindows: return builtInNames.unassignedWindows
        }
    }

    private func setHoveredRow(_ row: FocusSetPickerRow?) {
        guard hoveredRow !== row else { return }
        hoveredRow?.setHovered(false)
        hoveredRow = row
        row?.setHovered(true)
    }

    private func selectedVisibleIndex() -> Int? {
        guard let selectedIdentifierStorage else { return nil }
        return visibleItems.firstIndex { $0.identifier == selectedIdentifierStorage }
    }

    @discardableResult
    private func selectRow(at index: Int) -> FocusSetPickerItemIdentifier? {
        guard visibleItems.indices.contains(index) else {
            updateSelection(identifier: nil, index: nil)
            return nil
        }
        let identifier = visibleItems[index].identifier
        updateSelection(identifier: identifier, index: index)
        rowViews[index].scrollToVisible(rowViews[index].bounds)
        return identifier
    }

    @discardableResult
    private func selectAndConfirmRow(at index: Int) -> FocusSetPickerItem? {
        guard selectRow(at: index) != nil else { return nil }
        return confirmSelection()
    }

    private func updateSelection(identifier: FocusSetPickerItemIdentifier?, index: Int?) {
        let previousIdentifier = selectedIdentifierStorage
        selectedIdentifierStorage = identifier
        updateSelectionAppearance()
        guard previousIdentifier != identifier else { return }
        postAccessibilitySelectionChange()
        onSelectionChange?(identifier)
    }

    private func updateSelectionAppearance() {
        let selectedIndex = selectedVisibleIndex()
        rowViews.enumerated().forEach {
            let selected = $0 == selectedIndex
            $1.setSelected(selected)
            $1.setAccessibilitySelected(selected)
        }
        let selectedChildren = selectedIndex.map { [rowViews[$0] as Any] }
        rowsDocumentView.setAccessibilitySelectedChildren(selectedChildren)
    }

    private func handleEscape() {
        requireMainThread()
        if queryStorage.isEmpty {
            dismiss()
        } else {
            clearQuery()
        }
    }

    private func setSearchFieldStringValueIfNeeded(_ query: String) {
        guard searchField.stringValue != query else { return }
        let selectedRange = searchField.currentEditor()?.selectedRange
        searchField.stringValue = query
        guard let editor = searchField.currentEditor(), let selectedRange else { return }
        let location = min(selectedRange.location, query.utf16.count)
        let length = min(selectedRange.length, query.utf16.count - location)
        editor.selectedRange = NSRange(location: location, length: length)
    }

    private func postAccessibilitySelectionChange() {
        guard window != nil else { return }
        NSAccessibility.post(element: rowsDocumentView, notification: .selectedChildrenChanged)
    }

    private func requireMainThread() {
        precondition(Thread.isMainThread, "FocusSetPickerView must be used on the main thread.")
    }
}

extension FocusSetPickerView: NSSearchFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchField else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline):
            confirmSelection()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            handleEscape()
            return true
        case #selector(NSResponder.moveUp(_:)):
            selectPrevious()
            return true
        case #selector(NSResponder.moveDown(_:)):
            selectNext()
            return true
        default:
            return false
        }
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField, field === searchField else { return }
        DesignSystemControlStyler.refreshSearchField(searchField)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField, field === searchField else { return }
        DesignSystemControlStyler.refreshSearchField(searchField)
    }
}
