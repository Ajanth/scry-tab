import Cocoa

private final class FocusSetPickerTileView: TileView {
    var itemIndex: Int?
    var itemIdentifier: FocusSetPickerItemIdentifier?
    var onHover: ((FocusSetPickerTileView?) -> Void)?
    var onPress: (() -> Bool)?

    override var canBecomeKeyView: Bool {
        FocusSetPickerPresentationPolicy.rowsParticipateInKeyViewLoop
    }

    override var acceptsFirstResponder: Bool {
        FocusSetPickerPresentationPolicy.rowsParticipateInKeyViewLoop
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(self)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(nil)
    }

    func installClickRecognizer() {
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(performClick(_:))))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil))
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?() ?? false
    }

    @objc private func performClick(_ sender: NSClickGestureRecognizer) {
        guard sender.state == .ended else { return }
        _ = onPress?()
    }
}

private final class FocusSetPickerDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class FocusSetPickerView: NSView {
    typealias CandidateCountSummary = (Int) -> String
    private static let rowIcon = NSImage(named: NSImage.applicationIconName) ?? NSImage(size: .zero)

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
    private let searchPlaceholder: String?
    private let searchAccessibilityLabel: String?
    private let rowsScrollView = ScrollView()
    private let rowsDocumentView = FocusSetPickerDocumentView()
    private let underLayer = TileUnderLayer()
    private var resolverStorage: FocusSetPickerResolver
    private var selectedIdentifierStorage: FocusSetPickerItemIdentifier?
    private var queryStorage: String
    private var visibleItems = [FocusSetPickerItem]()
    private var rowViews = [FocusSetPickerTileView]()
    private weak var hoveredRow: FocusSetPickerTileView?
    private var titleRowWidth = CGFloat(0)
    private var titleRowHeight = CGFloat(0)

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
        self.searchPlaceholder = searchPlaceholder
        self.searchAccessibilityLabel = searchAccessibilityLabel
        super.init(frame: .zero)
        configure()
        reloadRows(notifySelectionChange: false)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        focusSearchField()
    }

    override func cancelOperation(_ sender: Any?) {
        handleEscape()
    }

    override func layout() {
        super.layout()
        layoutContent()
    }

    func activateSearchField() {
        requireMainThread()
        let searchField = TilesView.searchField
        TilesView.beginFocusSetPickerSearchSession(
            queryStorage,
            placeholder: searchPlaceholder,
            accessibilityLabel: searchAccessibilityLabel)
        searchField.delegate = self
        if searchField.superview !== self {
            addSubview(searchField)
        }
        needsLayout = true
    }

    func detachSearchField() {
        requireMainThread()
        TilesView.endFocusSetPickerSearchSession()
    }

    func preferredPanelSize() -> NSSize {
        let width = titleRowWidth + Appearance.windowPadding * 2
        let rowContentHeight = rowsContentHeight()
        let desiredHeight = rowContentHeight
            + searchBarHeight()
            + 10
            + Appearance.windowPadding * 2
        let maxHeight = NSScreen.preferred.frame.height * Appearance.maxHeightOnScreen
        return NSSize(width: width.rounded(), height: min(desiredHeight, maxHeight).rounded())
    }

    func refreshAppearance() {
        requireMainThread()
        refreshTitleMetrics()
        updateRows()
        needsLayout = true
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
            updateSelection(identifier: nil)
            return nil
        }
        return selectRow(at: nextIndex)
    }

    @discardableResult
    func confirmSelection() -> FocusSetPickerItem? {
        requireMainThread()
        guard let item = resolverStorage.confirmedItem(
            selectedIdentifier: selectedIdentifierStorage,
            matching: queryStorage) else { return nil }
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
        let searchField = TilesView.searchField
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
        TilesView.hasMarkedText()
    }

    private func configure() {
        requireMainThread()
        wantsLayer = true
        refreshTitleMetrics()
        rowsScrollView.documentView = rowsDocumentView
        rowsDocumentView.wantsLayer = true
        rowsDocumentView.setAccessibilityElement(true)
        rowsDocumentView.setAccessibilityRole(.list)
        rowsDocumentView.layer?.insertSublayer(underLayer, at: 0)
        addSubview(rowsScrollView)
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
                row.frame = .zero
                continue
            }
            configureRow(row, item: visibleItems[index], index: index)
            row.isHidden = false
        }
        let visibleRows = Array(rowViews.prefix(visibleItems.count))
        rowsDocumentView.setAccessibilityChildren(visibleRows)
        setHoveredRow(visibleRows.first { $0.itemIdentifier == hoveredIdentifier })
        needsLayout = true
    }

    private func rebuildRowPoolIfNeeded() {
        guard rowViews.count != resolverStorage.itemCount else { return }
        setHoveredRow(nil)
        rowViews.forEach { $0.removeFromSuperview() }
        rowViews.removeAll(keepingCapacity: true)
        for _ in 0..<resolverStorage.itemCount {
            let row = makeRow()
            rowsDocumentView.addSubview(row)
            rowViews.append(row)
        }
    }

    private func makeRow() -> FocusSetPickerTileView {
        let row = FocusSetPickerTileView()
        row.installClickRecognizer()
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.row)
        row.onHover = { [weak self, weak row] hovered in
            guard let self, let row else { return }
            if hovered == nil, self.hoveredRow !== row { return }
            self.setHoveredRow(hovered)
        }
        row.onPress = { [weak self, weak row] in
            guard let row, let index = row.itemIndex else { return false }
            return self?.selectAndConfirmRow(at: index) != nil
        }
        return row
    }

    private func configureRow(_ row: FocusSetPickerTileView,
                              item: FocusSetPickerItem,
                              index: Int) {
        let title = displayName(for: item.name)
        let summary = candidateCountSummary(max(item.candidateCount, 0))
        row.itemIndex = index
        row.itemIdentifier = item.identifier
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

    private func setHoveredRow(_ row: FocusSetPickerTileView?) {
        guard hoveredRow !== row else { return }
        hoveredRow = row
        updateHighlightLayers()
    }

    private func selectedVisibleIndex() -> Int? {
        guard let selectedIdentifierStorage else { return nil }
        return visibleItems.firstIndex { $0.identifier == selectedIdentifierStorage }
    }

    @discardableResult
    private func selectRow(at index: Int) -> FocusSetPickerItemIdentifier? {
        guard visibleItems.indices.contains(index) else {
            updateSelection(identifier: nil)
            return nil
        }
        let identifier = visibleItems[index].identifier
        updateSelection(identifier: identifier)
        layoutSubtreeIfNeeded()
        rowViews[index].scrollToVisible(rowViews[index].bounds)
        return identifier
    }

    @discardableResult
    private func selectAndConfirmRow(at index: Int) -> FocusSetPickerItem? {
        guard selectRow(at: index) != nil else { return nil }
        return confirmSelection()
    }

    private func updateSelection(identifier: FocusSetPickerItemIdentifier?) {
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
            $1.setAccessibilitySelected($0 == selectedIndex)
        }
        let selectedChildren = selectedIndex.map { [rowViews[$0] as Any] }
        rowsDocumentView.setAccessibilitySelectedChildren(selectedChildren)
        updateHighlightLayers()
    }

    private func updateHighlightLayers() {
        let selectedRow = selectedVisibleIndex().flatMap { index in
            rowViews.indices.contains(index) && !rowViews[index].isHidden ? rowViews[index] : nil
        }
        let hovered = hoveredRow !== selectedRow ? hoveredRow : nil
        underLayer.updateHighlight(focusedView: selectedRow, hoveredView: hovered)
    }

    private func layoutContent() {
        let padding = Appearance.windowPadding
        let searchHeight = searchBarHeight()
        let searchReservedHeight = searchHeight + 10
        let scrollHeight = max(0, bounds.height - padding * 2 - searchReservedHeight)
        let searchWidth = min(max(0, bounds.width - padding * 2), 320)
        let searchField = TilesView.searchField
        searchField.frame = NSRect(
            x: ((bounds.width - searchWidth) * 0.5).rounded(),
            y: bounds.height - padding - searchHeight,
            width: searchWidth,
            height: searchHeight)
        rowsScrollView.frame = NSRect(
            x: padding,
            y: padding,
            width: max(0, bounds.width - padding * 2),
            height: scrollHeight)
        let documentHeight = max(rowsContentHeight(), scrollHeight)
        rowsDocumentView.frame.size = NSSize(width: rowsScrollView.contentView.bounds.width, height: documentHeight)
        let rowHeight = titleRowHeight
        let rowWidth = max(0, rowsDocumentView.frame.width - Appearance.interCellPadding * 2)
        for (index, row) in rowViews.prefix(visibleItems.count).enumerated() {
            let y = Appearance.interCellPadding + CGFloat(index) * (rowHeight + Appearance.interCellPadding)
            row.frame = NSRect(x: Appearance.interCellPadding, y: y, width: rowWidth, height: rowHeight)
            let item = visibleItems[index]
            let title = displayName(for: item.name)
            let summary = candidateCountSummary(max(item.candidateCount, 0))
            row.updateFocusSetPickerCell(
                title: "\(title) — \(summary)",
                icon: Self.rowIcon,
                frameSize: row.frame.size,
                rowWidth: rowWidth)
        }
        underLayer.frame = rowsDocumentView.bounds
        updateHighlightLayers()
    }

    private func rowsContentHeight() -> CGFloat {
        let count = max(1, visibleItems.count)
        return Appearance.interCellPadding
            + CGFloat(count) * (titleRowHeight + Appearance.interCellPadding)
    }

    private func refreshTitleMetrics() {
        let title = TileTitleView(font: Appearance.font)
        let labelHeight = title.cell?.cellSize.height ?? Appearance.fontHeight
        titleRowHeight = max(Appearance.iconSize, labelHeight) + Appearance.edgeInsetsSize * 2
        let readableWidth = TileView.widthOfComfortableReadability() ?? 0
        titleRowWidth = TilesPanel.titleMaxRowWidth(readableWidth: readableWidth)
    }

    private func searchBarHeight() -> CGFloat {
        let searchField = TilesView.searchField
        let fitting = searchField.fittingSize.height
        return fitting > 0 ? ceil(fitting) : ceil(searchField.cell?.cellSize.height ?? 30)
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
        let searchField = TilesView.searchField
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
        guard control === TilesView.searchField else { return false }
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
}
