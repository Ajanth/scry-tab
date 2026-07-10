import Cocoa

func sidebarSeparatorView() -> NSView {
    return DesignSystemDividerView()
}

enum SidebarEditorContainerChrome {
    case framed
    case plain
}

enum SidebarEditorContainerLayout {
    case divided
    case spaced
}

/// Builds the horizontal sidebar/editor chassis shared by ExceptionsTab and ControlsTab. The
/// layout can use either the standard divider or the shared section gap. Callers are responsible
/// for pinning a fixed width on `sidebar` and `editor`. By default the sidebar follows the editor
/// height; `fixedSidebarHeight` keeps navigation stable while the editor changes height.
func makeSidebarEditorContainer(sidebar: NSView,
                                editor: NSView,
                                minHeight: CGFloat? = nil,
                                fixedSidebarHeight: CGFloat? = nil,
                                chrome: SidebarEditorContainerChrome = .framed,
                                layout: SidebarEditorContainerLayout = .divided) -> NSView {
    let content = makeSidebarEditorStack(sidebar: sidebar, editor: editor, layout: layout)
    content.orientation = .horizontal
    content.alignment = .top
    content.translatesAutoresizingMaskIntoConstraints = false
    if let fixedSidebarHeight {
        sidebar.heightAnchor.constraint(equalToConstant: fixedSidebarHeight).isActive = true
    } else {
        sidebar.heightAnchor.constraint(equalTo: editor.heightAnchor).isActive = true
    }
    let container: NSView
    switch chrome {
    case .framed: container = SidebarListContainer()
    case .plain:
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container = view
    }
    container.widthAnchor.constraint(equalToConstant: SettingsWindow.contentWidth).isActive = true
    if let minHeight {
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
    }
    container.addSubview(content)
    NSLayoutConstraint.activate([
        content.topAnchor.constraint(equalTo: container.topAnchor),
        content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    return container
}

private func makeSidebarEditorStack(sidebar: NSView, editor: NSView, layout: SidebarEditorContainerLayout) -> NSStackView {
    switch layout {
    case .divided:
        let separator = sidebarSeparatorView()
        separator.widthAnchor.constraint(equalToConstant: DesignSystem.Metrics.splitDividerThickness).isActive = true
        let stack = NSStackView(views: [sidebar, separator, editor])
        stack.spacing = 0
        return stack
    case .spaced:
        let stack = NSStackView(views: [sidebar, editor])
        stack.spacing = DesignSystem.Metrics.sectionGap
        return stack
    }
}

class SidebarListContainer: NSView {
    enum ArrowDirection { case up, down }

    /// Optional keyboard navigation hook. When set, the container accepts first responder
    /// status and forwards up/down arrow key events to this callback.
    var onArrowKey: ((ArrowDirection) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = DesignSystem.Metrics.sectionRadius
        layer?.borderWidth = TableGroupView.borderWidth
        layer?.masksToBounds = true
        refreshColors()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var acceptsFirstResponder: Bool { onArrowKey != nil }

    override func keyDown(with event: NSEvent) {
        guard let onArrowKey else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 126: onArrowKey(.up)
        case 125: onArrowKey(.down)
        default: super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        refreshColors()
    }

    private func refreshColors() {
        layer?.backgroundColor = DesignSystem.semanticCGColor(.surfacePlateau, in: self)
        layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: self)
    }
}

class SidebarListRow: ClickHoverStackView {
    static let highlightVerticalInset = CGFloat(4)
    static let highlightHorizontalInset = DesignSystem.Metrics.headerFooterGap

    private let backgroundView = NSView()
    private let iconView = NSImageView()
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private let titleLabel = DynamicColorTextField(labelWithString: "")
    private let titleRow = NSStackView()
    private let summaryLabel = DynamicColorTextField(labelWithString: "")
    private let chevronLabel = DynamicColorTextField(labelWithString: "›")
    private let textColumn = NSStackView()
    private var isSelectedRow = false
    private var isHoveredRow = false
    private var windowObservers = [NSObjectProtocol]()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        backgroundView.identifier = NSUserInterfaceItemIdentifier("sidebarRowBackground")
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = DesignSystem.Metrics.sidebarSelectionRadius
        backgroundView.layer?.masksToBounds = true
        addSubview(backgroundView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.isHidden = true
        textColumn.orientation = .vertical
        textColumn.alignment = .leading
        textColumn.spacing = 0
        textColumn.translatesAutoresizingMaskIntoConstraints = false
        let spacer = NSView()
        titleLabel.alignment = .left
        titleLabel.lineBreakMode = .byTruncatingHead
        titleLabel.cell?.usesSingleLineMode = true
        summaryLabel.alignment = .left
        summaryLabel.font = NSFont.systemFont(ofSize: 11)
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.cell?.usesSingleLineMode = true
        chevronLabel.font = NSFont.systemFont(ofSize: 22)
        chevronLabel.setContentHuggingPriority(.required, for: .horizontal)
        chevronLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        summaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.colorProvider = { [weak self] in self?.textColor(for: .title) ?? .labelColor }
        summaryLabel.colorProvider = { [weak self] in self?.textColor(for: .summary) ?? .secondaryLabelColor }
        chevronLabel.colorProvider = { [weak self] in self?.textColor(for: .chevron) ?? .secondaryLabelColor }
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 6
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.addArrangedSubview(titleLabel)
        textColumn.addArrangedSubview(titleRow)
        textColumn.addArrangedSubview(summaryLabel)
        addArrangedSubview(iconView)
        addArrangedSubview(textColumn)
        addArrangedSubview(spacer)
        addArrangedSubview(chevronLabel)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor, constant: Self.highlightVerticalInset),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.highlightHorizontalInset),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.highlightHorizontalInset),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.highlightVerticalInset),
        ])
        iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TableGroupView.padding).isActive = true
        textColumn.leadingAnchor.constraint(greaterThanOrEqualTo: iconView.trailingAnchor, constant: 8).isActive = true
        textColumn.trailingAnchor.constraint(lessThanOrEqualTo: chevronLabel.leadingAnchor, constant: -8).isActive = true
        chevronLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TableGroupView.padding).isActive = true
        updateStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    // The whole row is clickable. Without these overrides, clicks land on the inner labels
    // (NSTextField labels default to mouseDownCanMoveWindow = true), which lets
    // SettingsWindow.isMovableByWindowBackground drag the window from the row. Children are
    // display-only labels with no own click handling, so claiming the hit at the row is safe.
    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) != nil ? self : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                self?.updateStyle()
            })
        }
        updateStyle()
    }

    /// Last bundle ID for which the row has been fully resolved (icon + display name).
    /// Consumers can compare against this to avoid redundant placeholder/refetch flashes.
    private(set) var resolvedToken: String?

    func setContent(_ title: String, _ summary: String) {
        titleLabel.stringValue = title
        summaryLabel.stringValue = summary
        toolTip = summary.isEmpty ? title : "\(title)\n\(summary)"
    }

    /// Register the row's current title + summary text into the active `SettingsSearchIndex.Builder`
    /// (if any), along with highlight targets for both labels. Call this *after* `setContent` so the
    /// indexed strings match what the user sees. A no-op outside an `indexed { ... }` scope.
    ///
    /// Sidebar rows are rebuilt *after* the section's build-time `indexed` scope (ControlsTab's
    /// `refreshShortcutRows`), so they can't register themselves at creation — there's no active
    /// builder. Instead the owning tab re-publishes all its rows through
    /// `SettingsWindow.refreshSectionSearchContent`, which re-opens an `indexed { ... }` scope and
    /// calls this on each current row (at build time and after every rebuild). The build-time walk
    /// deliberately skips `SidebarListRow`s so those rows live solely in the section's replaceable
    /// dynamic content — no stale targets for since-removed rows. Targets read the labels'
    /// `stringValue` live, so in-place content edits don't need re-registration.
    func registerSearchContent() {
        SettingsSearchIndex.registerString(titleLabel.stringValue)
        SettingsSearchIndex.registerString(summaryLabel.stringValue)
        SettingsSearchIndex.registerTarget(SettingsSearchHighlight.highlightTarget(titleLabel))
        SettingsSearchIndex.registerTarget(SettingsSearchHighlight.highlightTarget(summaryLabel))
    }

    /// Updates only the summary line, leaving title/icon untouched. Use when the underlying
    /// data changed in a way that only affects the summary (e.g. dropdown selection changed
    /// but app identity is the same).
    func setSummary(_ summary: String) {
        summaryLabel.stringValue = summary
        let title = titleLabel.stringValue
        toolTip = summary.isEmpty ? title : "\(title)\n\(summary)"
    }

    func markResolved(token: String) {
        resolvedToken = token
    }

    func setIcon(_ image: NSImage?, size: CGFloat = 32) {
        if let image {
            iconView.image = image
            iconView.isHidden = false
            iconWidthConstraint?.isActive = false
            iconHeightConstraint?.isActive = false
            let w = iconView.widthAnchor.constraint(equalToConstant: size)
            let h = iconView.heightAnchor.constraint(equalToConstant: size)
            w.isActive = true
            h.isActive = true
            iconWidthConstraint = w
            iconHeightConstraint = h
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }
    }

    func setSelected(_ selected: Bool) {
        isSelectedRow = selected
        updateStyle()
    }

    func setHovered(_ hovered: Bool) {
        isHoveredRow = hovered
        updateStyle()
    }

    private var isWindowKey: Bool { window?.isKeyWindow ?? false }

    private enum LabelRole { case title, summary, chevron }

    /// We have to branch on `isWindowKey` ourselves because `layer.backgroundColor` takes a
    /// `CGColor`, which freezes the semantic NSColor at the moment of assignment — it doesn't
    /// auto-resolve to its inactive variant later. The window key-state observer in
    /// `viewDidMoveToWindow` calls `updateStyle()` whenever the window gains or loses key,
    /// re-running this branch with the now-current state. Same pattern AppKit uses for table
    /// cells in source-list style.
    private func textColor(for role: LabelRole) -> NSColor {
        if isSelectedRow {
            return .labelColor
        }
        switch role {
            case .title: return .labelColor
            case .summary, .chevron: return .secondaryLabelColor
        }
    }

    private func updateStyle() {
        let backgroundColor: NSColor
        if isSelectedRow {
            backgroundColor = DesignSystem.color(.surfaceSelected, appearance: effectiveAppearance)
        } else if isHoveredRow {
            backgroundColor = DesignSystem.color(.surfaceHover, appearance: effectiveAppearance)
        } else {
            backgroundColor = .clear
        }
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        backgroundView.layer?.backgroundColor = DesignSystem.resolvedCGColor(backgroundColor, in: self)
        titleLabel.needsDisplay = true
        summaryLabel.needsDisplay = true
        chevronLabel.needsDisplay = true
    }
}
