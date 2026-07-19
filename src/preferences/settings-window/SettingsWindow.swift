import Cocoa

private struct SettingsSectionDefinition {
    let id: String
    let title: String
    let symbol: Symbols
    let route: SettingsRoute
    /// Deferred view builder so `addSection` can wrap construction in
    /// `SettingsSearchIndex.indexed { ... }` and harvest inline-registered search strings +
    /// highlight targets as the section's factories build their widgets. The closure is invoked
    /// exactly once, in `addSection`.
    let builder: () -> NSView
    /// Optional hook for sections whose searchable content includes sidebar rows that are rebuilt
    /// *after* the initial build (ControlsTab's shortcut rows). When set, `addSection` skips
    /// `SidebarListRow`s in the build-time walk — they'd otherwise be captured as base targets that
    /// go stale on the next rebuild — and this closure re-registers the current rows into the
    /// section's *dynamic* search content (at build time, and again after each rebuild via
    /// `refreshSectionSearchContent`). nil for sections with no such rows.
    let registerDynamicSearchContent: (() -> Void)?
}

private enum SettingsSidebarItem {
    case group(SettingsSectionDefinition)
    case page(SettingsSectionDefinition)
    case result(SettingsSearchDescriptorMatch)
}

private final class SettingsSection {
    let id: String
    let title: String
    let icon: SettingsPageIconDescriptor
    let container: NSView
    let anchor: NSView
    let search: SettingsSectionSearchContent
    /// See `SettingsSectionDefinition.registerDynamicSearchContent`. Re-run inside a fresh indexed
    /// scope by `refreshSectionSearchContent` to refresh this section's dynamic search content.
    let registerDynamicSearchContent: (() -> Void)?
    let interSectionSpacingConstraint: NSLayoutConstraint
    let bottomSpacingConstraint: NSLayoutConstraint
    let titleTopConstraint: NSLayoutConstraint

    init(_ id: String,
         _ title: String,
         _ icon: SettingsPageIconDescriptor,
         _ container: NSView,
         _ anchor: NSView,
         _ search: SettingsSectionSearchContent,
         _ registerDynamicSearchContent: (() -> Void)?,
         _ interSectionSpacingConstraint: NSLayoutConstraint,
         _ bottomSpacingConstraint: NSLayoutConstraint,
         _ titleTopConstraint: NSLayoutConstraint) {
        self.id = id
        self.title = title
        self.icon = icon
        self.container = container
        self.anchor = anchor
        self.search = search
        self.registerDynamicSearchContent = registerDynamicSearchContent
        self.interSectionSpacingConstraint = interSectionSpacingConstraint
        self.bottomSpacingConstraint = bottomSpacingConstraint
        self.titleTopConstraint = titleTopConstraint
    }

    func setDynamicSearchContent(_ strings: [String], _ targets: [SettingsSearchHighlightTarget]) {
        search.setDynamic(strings: strings, targets: targets)
    }

    func matches(_ query: String) -> Bool {
        search.matches(query)
    }

    func highlightMatches(_ query: String) {
        search.highlightMatches(query)
    }

    func clearHighlights() {
        search.clearHighlights()
    }
}

private final class SettingsSidebarCellView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "SettingsSidebarCell")
    private let iconView = SettingsPageIconView()
    private let textStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var isGroup = false
    private var windowObservers = [NSObjectProtocol]()

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { refreshStyle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        guard let window else { refreshStyle(); return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in self?.refreshStyle() })
        }
        refreshStyle()
    }

    private func setupView() {
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        addSubview(textStack)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsWindow.sidebarItemContentInset),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -SettingsWindow.sidebarItemContentInset),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        refreshStyle()
    }

    func configure(_ section: SettingsSection) {
        configure(title: section.title, subtitle: nil, icon: section.icon, isGroup: false)
    }

    func configure(_ definition: SettingsSectionDefinition, icon: SettingsPageIconDescriptor) {
        configure(title: definition.title, subtitle: nil, icon: icon, isGroup: false)
    }

    func configureGroup(_ definition: SettingsSectionDefinition, icon: SettingsPageIconDescriptor) {
        configure(title: definition.title, subtitle: nil, icon: icon, isGroup: true)
    }

    func configure(_ match: SettingsSearchDescriptorMatch, icon: SettingsPageIconDescriptor) {
        configure(title: match.descriptor.title, subtitle: match.descriptor.subtitle, icon: icon, isGroup: false)
    }

    private func configure(title: String, subtitle: String?, icon: SettingsPageIconDescriptor, isGroup: Bool) {
        self.isGroup = isGroup
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.isHidden = (subtitle ?? "").isEmpty
        iconView.descriptor = icon
        iconView.isHidden = isGroup
        refreshStyle()
    }

    private func refreshStyle() {
        let selected = backgroundStyle == .emphasized
        titleLabel.font = NSFont.systemFont(ofSize: isGroup ? 13 : 13, weight: isGroup ? .medium : .regular)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.textColor = isGroup ? .secondaryLabelColor : .labelColor
        subtitleLabel.textColor = .secondaryLabelColor
        alphaValue = selected || (window?.isKeyWindow ?? true) ? 1 : 0.5
        textStack.isHidden = false
    }
}

private final class SettingsSidebarRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }
        set {}
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: DesignSystem.Metrics.sidebarSelectionRadius, yRadius: DesignSystem.Metrics.sidebarSelectionRadius)
        DesignSystem.color(.surfaceSelected, appearance: effectiveAppearance).setFill()
        path.fill()
    }
}

private final class SettingsHeaderView: NSView {
    static let height = CGFloat(50)
    private let iconView = SettingsPageIconView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func configure(title: String, icon: SettingsPageIconDescriptor) {
        titleLabel.stringValue = title
        iconView.descriptor = icon
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 17, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])
    }
}

private final class SettingsFlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class SidebarTableView: NSTableView {
    weak var tabPeer: NSView?

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    // Pin Tab navigation to a closed search ↔ sidebar loop. nextKeyView assignments alone
    // weren't enough — AppKit's auto-walker was still discovering inner sub-views of the
    // search field, the scroll view, and the split view. Overriding the *valid* variants
    // short-circuits the walker because that's the method AppKit calls during dispatch.
    override var nextValidKeyView: NSView? { tabPeer }
    override var previousValidKeyView: NSView? { tabPeer }
}

private final class SidebarSearchField: NSSearchField {
    weak var tabPeer: NSView?

    override var nextValidKeyView: NSView? { tabPeer }
    override var previousValidKeyView: NSView? { tabPeer }
}

class SettingsWindow: NSWindow {
    static let contentWidth = CGFloat(760)
    static let width = contentWidth
    /// Horizontal margin inside each section between the section's container and the
    /// TableGroupView's rounded background, so the gray-bg blocks "float" inside the section
    /// rather than extend edge-to-edge. The window width includes 2× this on top of the regular
    /// `contentWidth`, so TGVs keep their natural width and gain a visible gutter on each side.
    static let sectionContentHorizontalMargin = CGFloat(15)
    private static let sidebarWidth = CGFloat(230)
    /// Outer left pad between the splitview divider and the TableGroupView background. Kept
    /// symmetric with `contentTrailingPadding` so the visible TGV "shoulders" match on both sides.
    private static let contentHorizontalPadding = CGFloat(12)
    /// Trailing pad between the TableGroupView and the window edge. The visible gap from the
    /// right-most control to the window edge is `contentTrailingPadding + TableGroupView.padding`
    /// (= 5 + 10 = 15pt), since `TableGroupView` adds ~10pt of internal padding on the right of
    /// each row's content.
    private static let contentTrailingPadding = CGFloat(12)
    private static let contentTopPadding = CGFloat(0)
    private static let topSectionTitlePadding = CGFloat(12)
    private static let contentBottomPadding = CGFloat(12)
    static let sectionTitleSpacing = CGFloat(4)
    private static let sectionInterSectionSpacing = DesignSystem.Metrics.sectionGap
    private static let sectionBottomSpacing = CGFloat(0)
    private static let sectionScrollTopPadding = CGFloat(20)
    private static let sectionSelectionTriggerRatioWhenScrollingDown = CGFloat(0.4)
    private static let sectionSelectionTriggerRatioWhenScrollingUp = CGFloat(0.6)
    private static let sectionSelectionDirectionDeltaThreshold = CGFloat(0.25)
    private static let minWindowHeight = CGFloat(520)
    private static let defaultWindowHeight = CGFloat(620)
    private static let sidebarTopInset = SettingsHeaderView.height
    private static let sidebarHorizontalPadding = CGFloat(12)
    /// Padding inside the row's cell view between the cell's leading edge and the icon.
    /// `NSTableView.style = .sourceList` already inserts the cell content into its rounded
    /// highlight pill, so we only add a small visual breathing-room here.
    static let sidebarItemContentInset = CGFloat(4)
    private static let controlHighlightLayerName = "settingsSearchControlHighlight"
    private static let segmentedControlHighlightLayerName = "settingsSearchSegmentHighlight"
    private static let controlHighlightInset = CGFloat(1)
    private static let controlHighlightMinCornerRadius = CGFloat(4)
    private static let controlHighlightMaxCornerRadius = CGFloat(9)
    static var shared: SettingsWindow!

    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }

    private let splitViewController = NSSplitViewController()
    private let sidebarContainer = NSView()
    private let contentContainer = NSView()
    private let contentHeaderView = SettingsHeaderView()
    private let searchField = SidebarSearchField(frame: .zero)
    private let sidebarScrollView = NSScrollView()
    private let sidebarTableView = SidebarTableView()
    private let rightScrollView = NSScrollView()
    private let sectionsDocumentView = SettingsFlippedView(frame: .zero)
    private let sectionsStack = NSStackView()
    private let navigationController = SettingsNavigationController()
    private lazy var definitions = sectionDefinitions()
    private var sections = [SettingsSection]()
    private var visibleSidebarItems = [SettingsSidebarItem]()
    private var selectedSectionId: String?
    private var sectionScrollPositions = [String: CGFloat]()
    private var sectionsStackBottomConstraint: NSLayoutConstraint!
    private var sheetHighlightTargets = [ObjectIdentifier: [SettingsSearchHighlightTarget]]()
    private var liveResizeOriginX: CGFloat?
    private var sectionSelectionTriggerRatio = SettingsWindow.sectionSelectionTriggerRatioWhenScrollingDown
    private var lastContentScrollY: CGFloat?
    private var isProgrammaticScrollInProgress = false

    convenience init(initialRoute: SettingsRoute = .appearance) {
        // Leading pad is the title-to-divider gap; trailing pad is the card-outer-edge-to-window
        // gap. They're intentionally asymmetric because `TableGroupView`'s ~10pt internal padding
        // already adds a visual gap on the right — so the visible content sits roughly the same
        // distance from the window edge as the title sits from the divider.
        // Window width = sidebar + content + outer paddings + section's horizontal margins on
        // both sides. The section margins give TableGroupViews (gray-bg blocks) a visible gutter
        // on each side; without that extra width, narrower content (e.g. a TGV using
        // `contentWidth`) would leave dead space relative to wider content (e.g. the Controls
        // tab's sidebar+editor layout, which already consumes the full `contentWidth`).
        let windowWidth = Self.sidebarWidth + Self.contentWidth + Self.contentHorizontalPadding + Self.contentTrailingPadding + 2 * Self.sectionContentHorizontalMargin
        self.init(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: Self.defaultWindowHeight),
                  styleMask: [.titled, .miniaturizable, .closable, .resizable, .fullSizeContentView],
                  backing: .buffered, defer: false)
        minSize = NSSize(width: windowWidth, height: Self.minWindowHeight)
        maxSize = NSSize(width: windowWidth, height: CGFloat.greatestFiniteMagnitude)
        setupWindow()
        navigationController.navigate(to: Self.normalizedRoute(initialRoute))
        setupView()
        // setFrameAutosaveNameSafely applies the persisted frame (dropping a corrupt one that would
        // otherwise abort the app) and returns whether a VALID saved frame existed — false on first
        // launch OR when the saved frame was corrupt, both of which should fall through to the default.
        let hasSavedFrame = setFrameAutosaveNameSafely("SettingsWindow")
        if !hasSavedFrame {
            // No saved frame → enforce the default size and center on the active screen. AppKit's
            // `init(contentRect:)` isn't load-bearing here because the unified toolbar can shift
            // the effective frame; setting `contentSize` explicitly is the safe path.
            setContentSize(NSSize(width: windowWidth, height: Self.defaultWindowHeight))
            center()
        }
        Self.shared = self
    }

    private func setupWindow() {
        delegate = self
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        backgroundColor = .windowBackgroundColor
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.showsBaselineSeparator = false
        self.toolbar = toolbar
        if #available(macOS 11.0, *) {
            toolbarStyle = .unified
            titlebarSeparatorStyle = .none
        }
    }

    private static func normalizedRoute(_ route: SettingsRoute) -> SettingsRoute {
        route.normalizedUnavailableFeature(gesturesEnabled: FeatureFlags.gestures).normalizedDeletedShortcut {
            Preferences.shortcutIndex(forIdentifier: $0) != nil
        }
    }

    private func setupView() {
        setupSplitView()
        setupSidebar()
        setupContentPane()
        visibleSidebarItems = definitions.map { .page($0) }
        sidebarTableView.reloadData()
        navigate(to: navigationController.selectedRoute)
        refreshControlsFromSettings()
    }

    private func setupSplitView() {
        let sidebarVC = NSViewController()
        sidebarVC.view = sidebarContainer
        let contentVC = NSViewController()
        contentVC.view = contentContainer
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = Self.sidebarWidth
        sidebarItem.maximumThickness = Self.sidebarWidth
        let contentItem = NSSplitViewItem(viewController: contentVC)
        splitViewController.splitViewItems = [sidebarItem, contentItem]
        splitViewController.splitView.dividerStyle = .thin
        contentViewController = splitViewController
    }

    private func setupSidebar() {
        setupSearchField(sidebarContainer)
        setupSidebarTable(sidebarContainer)
        // Match macOS System Settings: Tab cycles between the search field and the sidebar
        // table only. The nextValidKeyView overrides on these two subclasses keep AppKit's
        // chain walker from discovering inner sub-controls of the search field, scroll view,
        // or split view — without them we'd see 9 stops instead of 2.
        searchField.tabPeer = sidebarTableView
        sidebarTableView.tabPeer = searchField
    }

    private func setupContentPane() {
        setupContentHeader()
        rightScrollView.drawsBackground = false
        rightScrollView.hasVerticalScroller = true
        rightScrollView.hasHorizontalScroller = false
        rightScrollView.scrollerStyle = .overlay
        if #available(macOS 11.0, *) {
            rightScrollView.automaticallyAdjustsContentInsets = false
        }
        rightScrollView.contentInsets = NSEdgeInsetsZero
        rightScrollView.scrollerInsets = NSEdgeInsetsZero
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(rightScrollView)
        sectionsDocumentView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.documentView = sectionsDocumentView
        sectionsStack.orientation = .vertical
        sectionsStack.spacing = 0
        sectionsStack.alignment = .leading
        sectionsStack.translatesAutoresizingMaskIntoConstraints = false
        sectionsDocumentView.addSubview(sectionsStack)
        NSLayoutConstraint.activate([
            rightScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            rightScrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            rightScrollView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor),
            rightScrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            sectionsStack.topAnchor.constraint(equalTo: sectionsDocumentView.topAnchor, constant: Self.contentTopPadding),
            sectionsStack.leadingAnchor.constraint(equalTo: sectionsDocumentView.leadingAnchor, constant: Self.contentHorizontalPadding),
            sectionsStack.trailingAnchor.constraint(equalTo: sectionsDocumentView.trailingAnchor, constant: -Self.contentTrailingPadding),
            sectionsDocumentView.widthAnchor.constraint(equalTo: rightScrollView.contentView.widthAnchor),
        ])
        sectionsStackBottomConstraint = sectionsStack.bottomAnchor.constraint(equalTo: sectionsDocumentView.bottomAnchor, constant: -Self.contentBottomPadding)
        sectionsStackBottomConstraint.isActive = true
    }

    private func setupContentHeader() {
        contentContainer.addSubview(contentHeaderView)
        NSLayoutConstraint.activate([
            contentHeaderView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentHeaderView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentHeaderView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])
    }

    private func installContentScrollObserver() {
        rightScrollView.contentView.postsBoundsChangedNotifications = true
        lastContentScrollY = rightScrollView.contentView.bounds.minY
        NotificationCenter.default.addObserver(self, selector: #selector(contentViewBoundsDidChange), name: NSView.boundsDidChangeNotification, object: rightScrollView.contentView)
    }

    private func setupSearchField(_ parent: NSView) {
        searchField.delegate = self
        searchField.placeholderString = NSLocalizedString("Search", comment: "")
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.bezelStyle = .roundedBezel
        if #available(macOS 26.0, *) {
            searchField.controlSize = .extraLarge
        } else if #available(macOS 13.0, *) {
            searchField.controlSize = .large
        }
        searchField.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: parent.topAnchor, constant: Self.sidebarTopInset),
            searchField.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: Self.sidebarHorizontalPadding),
            searchField.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -Self.sidebarHorizontalPadding),
        ])
    }

    private func setupSidebarTable(_ parent: NSView) {
        sidebarScrollView.drawsBackground = false
        sidebarScrollView.hasVerticalScroller = true
        sidebarScrollView.hasHorizontalScroller = false
        sidebarScrollView.scrollerStyle = .overlay
        sidebarTableView.headerView = nil
        sidebarTableView.intercellSpacing = NSSize(width: 0, height: 2)
        sidebarTableView.rowHeight = 32
        sidebarTableView.selectionHighlightStyle = .regular
        sidebarTableView.backgroundColor = .clear
        sidebarTableView.focusRingType = .none
        sidebarTableView.usesAlternatingRowBackgroundColors = false
        sidebarTableView.delegate = self
        sidebarTableView.dataSource = self
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "SettingsSidebarColumn"))
        column.resizingMask = .autoresizingMask
        sidebarTableView.addTableColumn(column)
        sidebarScrollView.documentView = sidebarTableView
        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(sidebarScrollView)
        NSLayoutConstraint.activate([
            sidebarScrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            // The scroll view sits flush to the sidebar edges. The `.sourceList` selection style
            // adds its own ~10pt internal inset for the row highlight pill, so the pill ends up
            // aligned with the search field (which itself is inset by `sidebarHorizontalPadding`
            // = 10pt). Insetting the scroll view here would compound that and push the highlight
            // too far in.
            sidebarScrollView.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: Self.sidebarHorizontalPadding),
            sidebarScrollView.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -Self.sidebarHorizontalPadding),
            sidebarScrollView.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -12),
        ])
    }

    private func sectionDefinitions() -> [SettingsSectionDefinition] {
        [
            SettingsSectionDefinition(id: "appearance", title: NSLocalizedString("Appearance", comment: ""), symbol: .paintpalette, route: .appearance, builder: AppearanceTab.initTab, registerDynamicSearchContent: nil),
            SettingsSectionDefinition(id: "controls", title: NSLocalizedString("Controls", comment: ""), symbol: .command, route: .controls(nil), builder: ControlsTab.initTab, registerDynamicSearchContent: ControlsTab.registerSidebarRowsSearchContent),
            SettingsSectionDefinition(id: "focusSets", title: NSLocalizedString("Focus Sets", comment: ""), symbol: .circledStar, route: .focusSets, builder: FocusSetsTab.initTab, registerDynamicSearchContent: FocusSetsTab.registerSidebarRowsSearchContent),
            SettingsSectionDefinition(id: "general", title: NSLocalizedString("General", comment: ""), symbol: .gearshape, route: .general, builder: GeneralTab.initTab, registerDynamicSearchContent: nil),
            SettingsSectionDefinition(id: "exceptions", title: NSLocalizedString("Exceptions", comment: ""), symbol: .handRaised, route: .exceptions(nil), builder: ExceptionsTab.initTab, registerDynamicSearchContent: nil),
            SettingsSectionDefinition(id: "about", title: NSLocalizedString("About", comment: ""), symbol: .circledInfo, route: .about, builder: AboutTab.initTab, registerDynamicSearchContent: nil),
        ]
    }

    private func searchDescriptors() -> [SettingsSearchDescriptor] {
        staticPageSearchDescriptors() + shortcutSearchDescriptors() + exceptionSearchDescriptors()
    }

    private func searchSidebarItems(query: String) -> [SettingsSidebarItem] {
        let pageOrder = definitions.compactMap { $0.route.page }
        return SettingsSearchDescriptorMatcher.groupedMatches(query: query, descriptors: searchDescriptors(), pageOrder: pageOrder).flatMap { group in
            guard let definition = definition(for: group.page) else { return group.matches.map(SettingsSidebarItem.result) }
            return [SettingsSidebarItem.group(definition)] + group.matches.map(SettingsSidebarItem.result)
        }
    }

    private func staticPageSearchDescriptors() -> [SettingsSearchDescriptor] {
        var descriptors = [
            SettingsSearchDescriptor(id: "appearance", route: .appearance, sectionID: "appearance", title: NSLocalizedString("Appearance", comment: ""), keywords: [
                NSLocalizedString("Size", comment: ""),
                NSLocalizedString("Theme", comment: ""),
                NSLocalizedString("After keys are released", comment: ""),
                AppearanceTab.showMoreOptions,
                AppearanceTab.showFewerOptions,
                AppearanceTab.labelWindowOrder,
                AppearanceTab.labelShowOn,
            ] + AppearanceStylePreference.allCases.map(\.localizedString)
              + AppearanceSizePreference.allCases.map(\.localizedString)
              + AppearanceThemePreference.allCases.map(\.localizedString)
              + ShortcutStylePreference.allCases.map(\.localizedString)
              + WindowOrderPreference.allCases.map(\.localizedString)
              + ShowOnScreenPreference.allCases.map(\.localizedString)
              + CustomizeStyleSheet.searchableStrings),
            SettingsSearchDescriptor(id: "controls-active", route: .controls(.activeShortcuts), sectionID: "controls", title: NSLocalizedString("Shortcuts while ScryTab is active", comment: ""), keywords: [NSLocalizedString("Advanced", comment: "")] + ShortcutsWhenActiveSheet.searchableStrings),
            SettingsSearchDescriptor(id: "focus-sets", route: .focusSets, sectionID: "focusSets", title: NSLocalizedString("Focus Sets", comment: ""), keywords: FocusSetSettingsView.searchableStrings),
            SettingsSearchDescriptor(id: "general", route: .general, sectionID: "general", title: NSLocalizedString("General", comment: ""), keywords: [
                NSLocalizedString("Start at login", comment: ""),
                NSLocalizedString("Language", comment: ""),
                NSLocalizedString("Updates policy", comment: ""),
                NSLocalizedString("Check for updates now…", comment: ""),
                NSLocalizedString("Crash reports policy", comment: ""),
                NSLocalizedString("Export settings…", comment: ""),
                NSLocalizedString("Import settings…", comment: ""),
                NSLocalizedString("Reset settings and restart…", comment: ""),
            ] + LanguagePreference.allCases.map(\.localizedString)
              + UpdatePolicyPreference.allCases.map(\.localizedString)
              + CrashPolicyPreference.allCases.map(\.localizedString)),
            SettingsSearchDescriptor(id: "exceptions", route: .exceptions(nil), sectionID: "exceptions", title: NSLocalizedString("Exceptions", comment: ""), keywords: [
                NSLocalizedString("Hide", comment: ""),
                NSLocalizedString("Ignore shortcuts", comment: ""),
                NSLocalizedString("Add a running app", comment: ""),
                NSLocalizedString("Add an app from disk", comment: ""),
            ]),
            SettingsSearchDescriptor(id: "about", route: .about, sectionID: "about", title: NSLocalizedString("About", comment: ""), keywords: [
                App.name,
                App.version,
                App.licence,
                NSLocalizedString("Website", comment: ""),
                NSLocalizedString("Usage", comment: ""),
            ] + AcknowledgmentsTab.searchableStrings),
        ]
        if FeatureFlags.gestures {
            descriptors.append(SettingsSearchDescriptor(id: "controls-gesture", route: .controls(.gesture), sectionID: "controls", title: NSLocalizedString("Gesture", comment: ""), keywords: [
                NSLocalizedString("Gestures", comment: ""),
                NSLocalizedString("Trackpad", comment: ""),
                NSLocalizedString("Filtering", comment: ""),
                NSLocalizedString("Appearance", comment: ""),
                NSLocalizedString("Ordering", comment: ""),
            ]))
        }
        return descriptors
    }

    private func shortcutSearchDescriptors() -> [SettingsSearchDescriptor] {
        (0..<Preferences.shortcutCount).map { index in
            let id = Preferences.shortcutIdentifier(at: index)
            return SettingsSearchDescriptor(id: "shortcut-\(id)",
                                            route: .controls(.shortcut(id: id, pane: nil)),
                                            sectionID: "controls",
                                            title: NSLocalizedString("Shortcut", comment: "") + " " + String(index + 1),
                                            keywords: [NSLocalizedString("Shortcuts", comment: "")] + FilteringPane.searchableStrings + AppearancePane.searchableStrings + OrderingPane.searchableStrings,
                                            valueProvider: { [index] in
                                                [
                                                    Preferences.shortcut(Preferences.indexToName("holdShortcut", index))?.keyEquivalent ?? "",
                                                    Preferences.shortcut(Preferences.indexToName("nextWindowShortcut", index))?.keyEquivalent ?? "",
                                                ]
                                            })
        }
    }

    private func exceptionSearchDescriptors() -> [SettingsSearchDescriptor] {
        Preferences.exceptions.map {
            let bundleId = $0.bundleIdentifier
            let displayInfo = AppDisplayInfo.resolve(bundleId: bundleId)
            let subtitle = displayInfo.name == bundleId ? nil : bundleId
            return SettingsSearchDescriptor(id: "exception-\(bundleId)",
                                     route: .exceptions(.bundleIdentifier(bundleId)),
                                     sectionID: "exceptions",
                                     title: displayInfo.name,
                                     subtitle: subtitle,
                                     keywords: [NSLocalizedString("Bundle ID", comment: ""), NSLocalizedString("Hide", comment: ""), NSLocalizedString("Ignore shortcuts", comment: "")])
        }
    }

    private func sidebarImage(_ definition: SettingsSectionDefinition) -> SettingsPageIconDescriptor {
        guard let page = definition.route.page else { return SettingsPageIconDescriptor(systemSymbolName: "circle", baseColor: .secondaryLabelColor) }
        return SettingsPageIconDescriptor.descriptor(for: page)
    }

    private func definition(for page: SettingsTopLevelPage) -> SettingsSectionDefinition? {
        definitions.first { $0.id == page.rawValue }
    }

    private func section(for definition: SettingsSectionDefinition) -> SettingsSection {
        if let section = sections.first(where: { $0.id == definition.id }) {
            return section
        }
        addSection(definition)
        let section = sections.last!
        section.container.isHidden = selectedSectionId != definition.id
        refreshSectionSearchContent(definition.id)
        return section
    }

    private func addSection(_ definition: SettingsSectionDefinition) {
        // Wrap the tab's view construction in an `indexed { ... }` scope so that every factory
        // call inside (`LabelAndControl.makeDropdown`, `TableGroupView.makeText`,
        // etc.) pushes its searchable strings and highlight targets into a per-section `Builder`.
        // The harvested results become the section's `searchableStrings` / `highlightTargets`
        // directly — no second-pass walk over the view tree. The section title is also produced
        // here so its label registration is captured by the same indexed scope.
        let sectionTitleBox: (title: LightLabel, view: NSView)
        let (built, builder) = SettingsSearchIndex.indexed { () -> (title: LightLabel, view: NSView) in
            let sectionTitle = TableGroupView.makeText(definition.title, bold: true)
            sectionTitle.font = NSFont.systemFont(ofSize: 15, weight: .medium)
            sectionTitle.lineBreakMode = .byWordWrapping
            sectionTitle.maximumNumberOfLines = 0
            let view = definition.builder()
            return (sectionTitle, view)
        }
        sectionTitleBox = built
        let sectionTitle = sectionTitleBox.title
        let sectionView = sectionTitleBox.view
        let container = NSView()
        let spacer = NSView()
        container.addSubview(sectionView)
        container.addSubview(spacer)
        sectionView.translatesAutoresizingMaskIntoConstraints = false
        spacer.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        let titleTopConstraint = sectionView.topAnchor.constraint(equalTo: container.topAnchor)
        let interSectionSpacingConstraint = spacer.topAnchor.constraint(equalTo: sectionView.bottomAnchor, constant: Self.sectionInterSectionSpacing)
        let spacerHeightConstraint = spacer.heightAnchor.constraint(equalToConstant: Self.sectionBottomSpacing)
        NSLayoutConstraint.activate([
            titleTopConstraint,
            sectionView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Self.sectionContentHorizontalMargin),
            sectionView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -Self.sectionContentHorizontalMargin),
            interSectionSpacingConstraint,
            spacer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            spacer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            spacer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            spacerHeightConstraint,
        ])
        sectionsStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: sectionsStack.widthAnchor).isActive = true
        // Inline-registered strings/targets are the source of truth; `collectSearchContent` still
        // runs as a safety net to catch direct widget creation in tabs (NSTextField, NSButton
        // etc. created outside the LabelAndControl/TableGroupView factories) that hasn't been
        // migrated to inline registration yet. The walk's results get unioned in via `Set` below.
        // Sections that manage rebuilt-after-build sidebar rows (`registerDynamicSearchContent`)
        // skip those rows here and publish them as dynamic content instead — see that hook.
        let skipSidebarRows = definition.registerDynamicSearchContent != nil
        var (searchableStrings, highlightTargets) = collectSearchContent(sectionTitle, sectionView, skipSidebarRows: skipSidebarRows)
        searchableStrings.append(contentsOf: builder.strings)
        highlightTargets.append(contentsOf: builder.targets)
        let search = SettingsSectionSearchContent(strings: Array(Set(searchableStrings)), targets: highlightTargets)
        let section = SettingsSection(definition.id,
                                      definition.title,
                                      sidebarImage(definition),
                                      container,
                                      sectionView,
                                      search,
                                      definition.registerDynamicSearchContent,
                                      interSectionSpacingConstraint,
                                      spacerHeightConstraint,
                                      titleTopConstraint)
        sections.append(section)
    }

    /// Re-publish a section's dynamic search content (its sidebar rows) into the index. A section's
    /// rows are rebuilt *outside* the build-time `indexed { }` scope (e.g. ControlsTab's
    /// `refreshShortcutRows` from the +/- buttons, a recorder edit, or an input-source change), so
    /// the rows' own `registerSearchContent` no-ops there. This re-opens a
    /// scope, re-registers the *current* rows, and swaps them into the section wholesale — no stale
    /// targets for removed rows, and freshly-added rows become searchable. Re-applies the active
    /// query so rebuilt rows light up immediately. Called once per section at the end of
    /// `setupView`, then by the owning tab after every rebuild.
    func refreshSectionSearchContent(_ id: String) {
        guard let section = sections.first(where: { $0.id == id }),
              let register = section.registerDynamicSearchContent else { return }
        let (_, builder) = SettingsSearchIndex.indexed { register() }
        section.setDynamicSearchContent(builder.strings, builder.targets)
        if !SettingsSearch.isQueryEmpty(searchField.stringValue) {
            applySearch(searchField.stringValue)
        }
    }

    private func updateVisibleSectionsSpacing() {
        let visibleSections = sections.filter { !$0.container.isHidden }
        visibleSections.enumerated().forEach { index, section in
            let isFirst = index == 0
            let isLast = index == visibleSections.count - 1
            section.titleTopConstraint.constant = isFirst ? Self.topSectionTitlePadding : 0
            section.interSectionSpacingConstraint.constant = isLast ? 0 : Self.sectionInterSectionSpacing
            section.bottomSpacingConstraint.constant = isLast ? 0 : Self.sectionBottomSpacing
        }
    }

    private func collectSearchContent(_ sectionTitle: LightLabel, _ root: NSView, skipSidebarRows: Bool) -> ([String], [SettingsSearchHighlightTarget]) {
        var textValues = [String]()
        var highlightTargets = [SettingsSearchHighlightTarget]()
        textValues.append(sectionTitle.stringValue)
        if let target = SettingsSearchHighlight.highlightTarget(sectionTitle) {
            highlightTargets.append(target)
        }
        collectSearchContent(root, &textValues, &highlightTargets, skipSidebarRows: skipSidebarRows)
        return (Array(Set(textValues)), highlightTargets)
    }

    private func collectSearchContent(_ root: NSView,
                                      _ textValues: inout [String],
                                      _ highlightTargets: inout [SettingsSearchHighlightTarget],
                                      skipSidebarRows: Bool) {
        // Sections that rebuild their sidebar rows after construction publish those rows as dynamic
        // search content (see `refreshSectionSearchContent`). Skipping `SidebarListRow`s here keeps
        // targets for since-removed rows out of the section's fixed base — that staleness was the
        // "typing 'sho' no longer highlights Shortcut N" bug.
        if skipSidebarRows, root is SidebarListRow { return }
        if let textField = root as? NSTextField {
            let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
                if let target = SettingsSearchHighlight.highlightTarget(textField) {
                    highlightTargets.append(target)
                }
            }
        } else if let popUpButton = root as? NSPopUpButton {
            let value = popUpButton.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
            }
            popUpButton.itemTitles.forEach {
                let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    textValues.append(value)
                }
            }
            if let target = SettingsWindow.highlightTarget(popUpButton) {
                highlightTargets.append(target)
            }
        } else if let chipSelect = root as? DesignSystemChipSelectControl {
            (0..<chipSelect.chipCount).forEach {
                if let value = chipSelect.chipTitle(at: $0)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                    textValues.append(value)
                }
            }
            if let target = SettingsWindow.highlightTarget(chipSelect) {
                highlightTargets.append(target)
            }
        } else if let button = root as? NSButton {
            let value = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
            }
            if let target = SettingsWindow.highlightTarget(button) {
                highlightTargets.append(target)
            }
        } else if let segmentedControl = root as? NSSegmentedControl {
            (0..<segmentedControl.segmentCount).forEach {
                let value = (segmentedControl.label(forSegment: $0) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    textValues.append(value)
                }
            }
            if let target = SettingsWindow.highlightTarget(segmentedControl) {
                highlightTargets.append(target)
            }
        } else if let infoButton = root as? ClickHoverImageView {
            SettingsWindow.searchStrings(infoButton).forEach {
                textValues.append($0)
            }
            if let target = SettingsWindow.highlightTarget(infoButton) {
                highlightTargets.append(target)
            }
        } else if let textView = root as? NSTextView {
            let value = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                textValues.append(value)
            }
        }
        root.subviews.forEach { collectSearchContent($0, &textValues, &highlightTargets, skipSidebarRows: skipSidebarRows) }
    }

    static func highlightTarget(_ popUpButton: NSPopUpButton) -> SettingsSearchHighlightTarget? {
        controlHighlightTarget(popUpButton) {
            SettingsWindow.searchStrings(popUpButton)
        }
    }

    static func highlightTarget(_ button: NSButton) -> SettingsSearchHighlightTarget? {
        // Buttons that open one of the known sheets are search targets. Pre-build path: consult
        // the sheet class's static `searchableStrings`. Post-build path: also walk the live view
        // tree so any string the static list doesn't cover (or is added later inside the sheet)
        // still matches. Either path makes the button itself the visual highlight target — we
        // don't try to dive into the sheet's controls for in-sheet highlighting from out here.
        let staticStrings: [String]?
        if let action = button.action {
            staticStrings = SettingsSearchIndex.sheetSearchableStrings(forButtonAction: action)
        } else {
            staticStrings = nil
        }
        let hasSheet = SettingsWindow.sheet(forSearchButton: button) != nil
        guard staticStrings != nil || hasSheet else { return nil }
        return controlHighlightTarget(button) {
            var values = [String]()
            SettingsWindow.appendTrimmed(button.title, &values)
            if let staticStrings { values.append(contentsOf: staticStrings) }
            if let sheet = SettingsWindow.sheet(forSearchButton: button) {
                values.append(contentsOf: SettingsWindow.sheetSearchStrings(sheet))
            }
            return Array(Set(values))
        }
    }

    static func highlightTarget(_ segmentedControl: NSSegmentedControl) -> SettingsSearchHighlightTarget? {
        let segmentLabels = (0..<segmentedControl.segmentCount).map {
            SettingsWindow.trimmedText(segmentedControl.label(forSegment: $0) ?? "")
        }
        if segmentLabels.allSatisfy(\.isEmpty) { return nil }
        // Tabs with distinct content register their per-segment strings so a query can highlight
        // the segment that contains a match, even when that page is currently hidden or unbuilt.
        let controlIdentifier = ObjectIdentifier(segmentedControl)
        let perSegmentStrings = ControlsTab.tabSegmentSearchableStrings[controlIdentifier]
            ?? FocusSetsTab.tabSegmentSearchableStrings[controlIdentifier]
        var matchingSegmentIndexes = [Int]()
        return SettingsSearchHighlightTarget({ query in
            matchingSegmentIndexes = SettingsSearch.matchingSegmentIndexes(
                query: query,
                segmentLabels: segmentLabels,
                perSegmentStrings: perSegmentStrings)
            if matchingSegmentIndexes.isEmpty { return [] }
            return [0..<1]
        }, { _ in
            SettingsWindow.applySegmentedControlHighlight(to: segmentedControl, segmentIndexes: matchingSegmentIndexes)
        }, {
            SettingsWindow.clearSegmentedControlHighlight(from: segmentedControl)
        })
    }

    static func highlightTarget(_ chipSelect: DesignSystemChipSelectControl) -> SettingsSearchHighlightTarget? {
        controlHighlightTarget(chipSelect) {
            (0..<chipSelect.chipCount).map {
                SettingsWindow.trimmedText(chipSelect.chipTitle(at: $0) ?? "")
            }.filter { !$0.isEmpty }
        }
    }

    /// True iff any user-visible text in the view subtree matches `query`. Walks the same set of
    /// view types as `collectSearchContent` (text fields, popups, segmented controls, buttons,
    /// info popovers, text views) so the match semantics are consistent.
    private static func subtreeContainsMatch(_ view: NSView, query: String) -> Bool {
        if let tf = view as? NSTextField {
            let s = SettingsWindow.trimmedText(tf.stringValue)
            if !s.isEmpty, SettingsSearch.match(query, in: s) != nil { return true }
        } else if let pop = view as? NSPopUpButton {
            let title = SettingsWindow.trimmedText(pop.title)
            if !title.isEmpty, SettingsSearch.match(query, in: title) != nil { return true }
            for item in pop.itemTitles {
                let s = SettingsWindow.trimmedText(item)
                if !s.isEmpty, SettingsSearch.match(query, in: s) != nil { return true }
            }
        } else if let seg = view as? NSSegmentedControl {
            for i in 0..<seg.segmentCount {
                let s = SettingsWindow.trimmedText(seg.label(forSegment: i) ?? "")
                if !s.isEmpty, SettingsSearch.match(query, in: s) != nil { return true }
            }
        } else if let btn = view as? NSButton {
            let s = SettingsWindow.trimmedText(btn.title)
            if !s.isEmpty, SettingsSearch.match(query, in: s) != nil { return true }
        } else if let infoButton = view as? ClickHoverImageView {
            for s in SettingsWindow.searchStrings(infoButton) {
                if SettingsSearch.match(query, in: s) != nil { return true }
            }
        } else if let textView = view as? NSTextView {
            let s = SettingsWindow.trimmedText(textView.string)
            if !s.isEmpty, SettingsSearch.match(query, in: s) != nil { return true }
        }
        return view.subviews.contains { subtreeContainsMatch($0, query: query) }
    }

    static func highlightTarget(_ infoButton: ClickHoverImageView) -> SettingsSearchHighlightTarget? {
        controlHighlightTarget(infoButton) {
            SettingsWindow.searchStrings(infoButton)
        }
    }

    static func controlHighlightTarget(_ control: NSView, _ searchableStrings: @escaping () -> [String]) -> SettingsSearchHighlightTarget? {
        if searchableStrings().isEmpty { return nil }
        return SettingsSearchHighlightTarget({ query in
            searchableStrings().contains {
                SettingsSearch.match(query, in: $0) != nil
            }
        }, {
            SettingsWindow.applyControlHighlight(to: control)
        }, {
            SettingsWindow.clearControlHighlight(from: control)
        })
    }

    private static func clearControlHighlight(from view: NSView) {
        view.layer?.sublayers?.filter { $0.name == controlHighlightLayerName }.forEach { $0.removeFromSuperlayer() }
    }

    private static func clearSegmentedControlHighlight(from view: NSView) {
        view.layer?.sublayers?.filter { $0.name == segmentedControlHighlightLayerName }.forEach { $0.removeFromSuperlayer() }
    }

    private static func applySegmentedControlHighlight(to control: NSSegmentedControl, segmentIndexes: [Int]) {
        clearSegmentedControlHighlight(from: control)
        control.layoutSubtreeIfNeeded()
        guard !segmentIndexes.isEmpty else { return }
        control.wantsLayer = true
        let segmentRects = segmentedControlSegmentRects(control)
        segmentIndexes.forEach {
            guard segmentRects.indices.contains($0) else { return }
            // Inset only vertically. A horizontal inset visibly shrinks the highlight rect — for
            // adjacent segments it stops the yellow from reaching the segment boundary, leaving a
            // gray sliver between the highlight and the neighbour. Touching at the boundary looks
            // correct because the rounded corners curve inward at top/bottom anyway.
            let rect = segmentRects[$0].insetBy(dx: 0, dy: 1)
            guard rect.width > 0, rect.height > 0 else { return }
            let layer = noAnimation { CAShapeLayer() }
            layer.name = segmentedControlHighlightLayerName
            layer.fillColor = Appearance.searchMatchHighlightColor.cgColor
            let cornerRadius = min(max(rect.height * 0.3, 4), 7)
            layer.path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            control.layer?.insertSublayer(layer, at: 0)
        }
    }

    private static func segmentedControlSegmentRects(_ control: NSSegmentedControl) -> [CGRect] {
        let segmentCount = control.segmentCount
        if segmentCount <= 0 { return [] }
        let widths = (0..<segmentCount).map { max(control.width(forSegment: $0), 0) }
        let explicitWidthTotal = widths.reduce(0) {
            $0 + ($1 > 0 ? $1 : 0)
        }
        let autoSegmentCount = widths.filter { $0 == 0 }.count
        let autoSegmentWidth = autoSegmentCount > 0 ? max(control.bounds.width - explicitWidthTotal, 0) / CGFloat(autoSegmentCount) : 0
        var currentX = control.bounds.minX
        return widths.enumerated().map { index, width in
            let resolvedWidth = width > 0 ? width : autoSegmentWidth
            let isLastSegment = index == segmentCount - 1
            let segmentWidth = isLastSegment ? max(control.bounds.maxX - currentX, 0) : resolvedWidth
            defer { currentX += segmentWidth }
            return CGRect(x: currentX, y: control.bounds.minY, width: segmentWidth, height: control.bounds.height)
        }
    }

    private static func applyControlHighlight(to view: NSView) {
        clearControlHighlight(from: view)
        view.layoutSubtreeIfNeeded()
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }
        view.wantsLayer = true
        let layer = noAnimation { CAShapeLayer() }
        layer.name = controlHighlightLayerName
        layer.fillColor = Appearance.searchMatchHighlightColor.cgColor
        let rect = view.bounds.insetBy(dx: -controlHighlightInset, dy: -controlHighlightInset)
        let cornerRadius = min(max(rect.height * 0.35, controlHighlightMinCornerRadius), controlHighlightMaxCornerRadius)
        layer.path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        view.layer?.insertSublayer(layer, at: 0)
    }

    private static func appendTrimmed(_ text: String, _ values: inout [String]) {
        let value = trimmedText(text)
        if !value.isEmpty {
            values.append(value)
        }
    }

    private static func trimmedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func searchStrings(_ popUpButton: NSPopUpButton) -> [String] {
        var values = [String]()
        appendTrimmed(popUpButton.title, &values)
        popUpButton.itemTitles.forEach {
            appendTrimmed($0, &values)
        }
        return Array(Set(values))
    }

    private static func searchStrings(_ segmentedControl: NSSegmentedControl) -> [String] {
        var values = [String]()
        (0..<segmentedControl.segmentCount).forEach {
            appendTrimmed(segmentedControl.label(forSegment: $0) ?? "", &values)
        }
        return Array(Set(values))
    }

    private static func searchStrings(_ infoButton: ClickHoverImageView) -> [String] {
        var values = [String]()
        infoButton.searchableStrings.forEach {
            appendTrimmed($0, &values)
        }
        return Array(Set(values))
    }

    private static func sheet(forSearchButton button: NSButton) -> SheetWindow? {
        guard let action = button.action else { return nil }
        if action == #selector(AppearanceTab.showCustomizeStyleSheet) { return AppearanceTab.customizeStyleSheet }
        if action == #selector(ControlsTab.showShortcutsSettings) { return ControlsTab.shortcutsWhenActiveSheet }
        return nil
    }

    private static func sheetSearchStrings(_ sheet: SheetWindow) -> [String] {
        guard let contentView = sheet.contentView else { return [] }
        var values = [String]()
        collectSearchStrings(contentView, &values)
        return Array(Set(values))
    }

    private static func collectSearchStrings(_ root: NSView, _ values: inout [String]) {
        if let textField = root as? NSTextField {
            appendTrimmed(textField.stringValue, &values)
        } else if let popUpButton = root as? NSPopUpButton {
            appendTrimmed(popUpButton.title, &values)
            popUpButton.itemTitles.forEach {
                appendTrimmed($0, &values)
            }
        } else if let button = root as? NSButton {
            appendTrimmed(button.title, &values)
        } else if let segmentedControl = root as? NSSegmentedControl {
            (0..<segmentedControl.segmentCount).forEach {
                appendTrimmed(segmentedControl.label(forSegment: $0) ?? "", &values)
            }
        } else if let infoButton = root as? ClickHoverImageView {
            searchStrings(infoButton).forEach {
                appendTrimmed($0, &values)
            }
        } else if let textView = root as? NSTextView {
            appendTrimmed(textView.string, &values)
        }
        root.subviews.forEach {
            collectSearchStrings($0, &values)
        }
    }

    private func refreshControlsFromSettings() {
        GeneralTab.refreshControlsFromPreferences()
    }

    func beginSheetWithSearchHighlight(_ sheet: SheetWindow) {
        beginSheet(sheet) { [weak self] _ in
            self?.clearSheetHighlights(sheet)
        }
        applySearchToSheet(sheet, searchField.stringValue)
    }

    private func applySearchToVisibleSheets(_ query: String) {
        sheets.compactMap { $0 as? SheetWindow }.forEach {
            applySearchToSheet($0, query)
        }
    }

    private func applySearchToSheet(_ sheet: SheetWindow, _ query: String) {
        let targets = highlightTargets(for: sheet)
        if SettingsSearch.isQueryEmpty(query) {
            targets.forEach { $0.clear() }
            return
        }
        targets.forEach { $0.updateHighlight(query) }
    }

    private func highlightTargets(for sheet: SheetWindow) -> [SettingsSearchHighlightTarget] {
        let key = ObjectIdentifier(sheet)
        if let targets = sheetHighlightTargets[key] {
            return targets
        }
        guard let contentView = sheet.contentView else { return [] }
        var targets = [SettingsSearchHighlightTarget]()
        collectSheetHighlightTargets(contentView, &targets)
        sheetHighlightTargets[key] = targets
        return targets
    }

    private func collectSheetHighlightTargets(_ root: NSView, _ targets: inout [SettingsSearchHighlightTarget]) {
        if let textField = root as? NSTextField {
            if let target = SettingsSearchHighlight.highlightTarget(textField) {
                targets.append(target)
            }
        } else if let popUpButton = root as? NSPopUpButton {
            if let target = SettingsWindow.highlightTarget(popUpButton) {
                targets.append(target)
            }
        } else if let segmentedControl = root as? NSSegmentedControl {
            if let target = SettingsWindow.highlightTarget(segmentedControl) {
                targets.append(target)
            }
        } else if let infoButton = root as? ClickHoverImageView {
            if let target = SettingsWindow.highlightTarget(infoButton) {
                targets.append(target)
            }
        }
        root.subviews.forEach {
            collectSheetHighlightTargets($0, &targets)
        }
    }

    private func clearSheetHighlights(_ sheet: SheetWindow) {
        let key = ObjectIdentifier(sheet)
        guard let targets = sheetHighlightTargets[key] else { return }
        targets.forEach { $0.clear() }
    }

    @objc private func contentViewBoundsDidChange(_ notification: Notification) {
        let currentY = rightScrollView.contentView.bounds.minY
        if isProgrammaticScrollInProgress {
            lastContentScrollY = currentY
            return
        }
        updateSectionSelectionTriggerRatio(currentY)
        guard let section = sectionAtCurrentScrollPosition(sectionSelectionTriggerRatio) else { return }
        guard selectedSectionId != section.id else { return }
        selectSection(section, scroll: false)
    }

    private func updateSectionSelectionTriggerRatio(_ currentY: CGFloat) {
        defer { lastContentScrollY = currentY }
        guard let lastContentScrollY else { return }
        let deltaY = currentY - lastContentScrollY
        if deltaY > Self.sectionSelectionDirectionDeltaThreshold {
            sectionSelectionTriggerRatio = Self.sectionSelectionTriggerRatioWhenScrollingDown
            return
        }
        if deltaY < -Self.sectionSelectionDirectionDeltaThreshold {
            sectionSelectionTriggerRatio = Self.sectionSelectionTriggerRatioWhenScrollingUp
        }
    }

    private func sectionAtCurrentScrollPosition(_ triggerRatio: CGFloat) -> SettingsSection? {
        let visibleSections = sections.filter { !$0.container.isHidden }
        guard !visibleSections.isEmpty else { return nil }
        let visibleBounds = rightScrollView.contentView.bounds
        let sectionTopY = visibleBounds.minY + visibleBounds.height * triggerRatio
        return visibleSections.last {
            $0.anchor.convert($0.anchor.bounds, to: sectionsDocumentView).minY <= sectionTopY
        } ?? visibleSections[0]
    }

    func navigateToSection(_ sectionId: String) {
        guard let definition = definitions.first(where: { $0.id == sectionId }) else { return }
        navigate(to: definition.route)
    }

    func syncVisibleRoute(_ route: SettingsRoute) {
        let route = Self.normalizedRoute(route)
        guard let page = route.page, page.rawValue == selectedSectionId else { return }
        navigationController.navigate(to: route)
    }

    func navigate(to route: SettingsRoute) {
        let route = Self.normalizedRoute(route)
        guard let page = route.page, let definition = definition(for: page) else { return }
        storeCurrentScrollPosition()
        navigationController.navigate(to: route)
        _ = section(for: definition)
        if page == .about { AboutTab.refreshSettingsUsageStats() }
        if page == .focusSets { FocusSetsTab.refresh() }
        sections.forEach { $0.container.isHidden = $0.id != definition.id }
        selectedSectionId = definition.id
        contentHeaderView.configure(title: definition.title, icon: sidebarImage(definition))
        updateVisibleSectionsSpacing()
        sectionsDocumentView.layoutSubtreeIfNeeded()
        restoreScrollPosition(for: definition.id)
        selectSidebarRow(for: definition)
        applyDestination(route)
        highlightCurrentPageForActiveSearch()
    }

    private func storeCurrentScrollPosition() {
        guard let selectedSectionId else { return }
        sectionScrollPositions[selectedSectionId] = rightScrollView.contentView.bounds.minY
    }

    private func restoreScrollPosition(for sectionId: String) {
        let targetY = sectionScrollPositions[sectionId] ?? 0
        rightScrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        rightScrollView.reflectScrolledClipView(rightScrollView.contentView)
        lastContentScrollY = targetY
    }

    private func selectSidebarRow(for definition: SettingsSectionDefinition) {
        guard SettingsSearch.isQueryEmpty(searchField.stringValue) else { return }
        guard let row = visibleSidebarItems.firstIndex(where: {
            if case .page(let itemDefinition) = $0 { return itemDefinition.id == definition.id }
            return false
        }), sidebarTableView.selectedRow != row else { return }
        sidebarTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    private func applyDestination(_ route: SettingsRoute) {
        if case .controls(let destination?) = route {
            ControlsTab.selectDestination(destination)
        } else if case .exceptions(let destination?) = route {
            ExceptionsTab.selectDestination(destination)
        }
    }

    private func highlightCurrentPageForActiveSearch() {
        guard !SettingsSearch.isQueryEmpty(searchField.stringValue) else { return }
        sections.first { $0.id == selectedSectionId }?.highlightMatches(searchField.stringValue)
    }

    private func selectSection(_ section: SettingsSection, scroll: Bool, selectInSidebar: Bool = true) {
        selectedSectionId = section.id
        let visibleSections = sections.filter { !$0.container.isHidden }
        if selectInSidebar, let row = visibleSections.firstIndex(where: { $0.id == section.id }), sidebarTableView.selectedRow != row {
            sidebarTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        guard scroll else { return }
        scrollToSection(section)
    }

    private func scrollToSection(_ section: SettingsSection) {
        guard isVisible else { return }
        sectionsDocumentView.layoutSubtreeIfNeeded()
        let anchorFrame = section.anchor.convert(section.anchor.bounds, to: sectionsDocumentView)
        let targetY = max(anchorFrame.minY - Self.sectionScrollTopPadding, 0)
        isProgrammaticScrollInProgress = true
        defer { isProgrammaticScrollInProgress = false }
        rightScrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        rightScrollView.reflectScrolledClipView(rightScrollView.contentView)
        lastContentScrollY = targetY
    }

    private func applySearch(_ query: String) {
        Popover.shared.updateSearchContext(query) { query, text in
            SettingsSearch.match(query, in: text)?.ranges ?? []
        }
        sections.forEach { $0.clearHighlights() }
        applySearchToVisibleSheets(query)
        if SettingsSearch.isQueryEmpty(query) {
            navigationController.restorePreviousNonSearchRoute()
            visibleSidebarItems = definitions.map { .page($0) }
            sidebarTableView.reloadData()
            navigate(to: navigationController.selectedRoute)
            return
        }
        navigationController.updateSearch(query: query)
        visibleSidebarItems = searchSidebarItems(query: query)
        sidebarTableView.reloadData()
        highlightCurrentPageForActiveSearch()
        guard !visibleSidebarItems.isEmpty else {
            sidebarTableView.deselectAll(nil)
            return
        }
        deselectInvalidSidebarSelection()
    }

    private func deselectInvalidSidebarSelection() {
        let row = sidebarTableView.selectedRow
        guard row >= 0 else { return }
        guard row < visibleSidebarItems.count else {
            sidebarTableView.deselectAll(nil)
            return
        }
        if case .group = visibleSidebarItems[row] {
            sidebarTableView.deselectAll(nil)
        }
    }

    override func close() {
        hideAppIfLastWindowIsClosed()
        super.close()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "f" {
            makeFirstResponder(searchField)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        guard !SettingsSearch.isQueryEmpty(searchField.stringValue) else {
            super.cancelOperation(sender)
            return
        }
        searchField.stringValue = ""
        applySearch("")
    }
}

extension SettingsWindow: NSWindowDelegate {
    func windowWillStartLiveResize(_ notification: Notification) {
        liveResizeOriginX = frame.origin.x
    }

    func windowDidResize(_ notification: Notification) {
        guard inLiveResize, let liveResizeOriginX else { return }
        guard abs(frame.origin.x - liveResizeOriginX) > 0 else { return }
        setFrameOrigin(NSPoint(x: liveResizeOriginX, y: frame.origin.y))
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        liveResizeOriginX = nil
    }

    func windowWillClose(_ notification: Notification) {
        // Defer to the next runloop tick: tearing down view trees, removing observers,
        // and dropping the last strong ref to `self` while AppKit is still inside its own
        // close machinery causes objc_release crashes on re-entry.
        DispatchQueue.main.async {
            AppearanceTab.cleanup()
            ControlsTab.cleanup()
            FocusSetsTab.cleanup()
            GeneralTab.cleanup()
            ExceptionsTab.cleanup()
            SettingsWindow.shared = nil
        }
    }
}

extension SettingsWindow: NSSearchFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        applySearch(searchField.stringValue)
    }
}

extension SettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleSidebarItems.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch visibleSidebarItems[row] {
        case .group:
            return 26
        case .result(let match):
            return (match.descriptor.subtitle ?? "").isEmpty ? 32 : 44
        case .page:
            return 32
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        SettingsSidebarRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: SettingsSidebarCellView.identifier, owner: self) as? SettingsSidebarCellView ?? {
            let view = SettingsSidebarCellView()
            view.identifier = SettingsSidebarCellView.identifier
            return view
        }()
        switch visibleSidebarItems[row] {
        case .group(let definition):
            cell.configureGroup(definition, icon: sidebarImage(definition))
        case .page(let definition):
            cell.configure(definition, icon: sidebarImage(definition))
        case .result(let match):
            let page = match.descriptor.route.page ?? .appearance
            let definition = definition(for: page) ?? definitions[0]
            cell.configure(match, icon: sidebarImage(definition))
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row >= 0, row < visibleSidebarItems.count else { return false }
        if case .group = visibleSidebarItems[row] { return false }
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebarTableView.selectedRow
        guard row >= 0, row < visibleSidebarItems.count else { return }
        switch visibleSidebarItems[row] {
        case .group:
            return
        case .page(let definition):
            if selectedSectionId == definition.id { return }
            navigate(to: definition.route)
        case .result(let match):
            navigate(to: match.descriptor.route)
        }
    }
}
