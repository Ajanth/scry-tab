import Cocoa

class AboutTab {
    private static weak var settingsUsageView: AboutUsageView?

    static func initTab() -> NSView {
        makeSettingsContentView(columnWidth: SettingsWindow.contentWidth)
    }

    static func makeContentView(_ fitToContent: Bool = true, _ showFeedbackButton: Bool = true, _ centerHero: Bool = false) -> NSView {
        let appIcon = LightImageView()
        let appIconSize = NSSize(width: 112, height: 112)
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.updateContents(.cgImage(App.appIcon(for: appIconSize)), appIconSize)
        appIcon.fit(appIconSize.width, appIconSize.height)
        let metadata = StackView([
            BoldLabel(App.name),
            secondaryLabel(NSLocalizedString("Version", comment: "") + " " + App.version),
            secondaryLabel(App.licence),
            HyperlinkLabel(NSLocalizedString("Website", comment: ""), Endpoints.website),
        ], .vertical)
        metadata.spacing = DesignSystem.Metrics.headerFooterGap
        metadata.setCustomSpacing(DesignSystem.Metrics.formOuterPadding, after: metadata.views[2])
        let hero = NSStackView(views: [appIcon, metadata])
        hero.translatesAutoresizingMaskIntoConstraints = false
        hero.spacing = DesignSystem.Metrics.sectionGap
        hero.alignment = .centerY
        let view = centerHero ? centered(hero) : hero
        if fitToContent { view.fit() }
        return view
    }

    static func makeSettingsContentView(columnWidth: CGFloat) -> NSView {
        let contentWidth = columnWidth - 2 * TableGroupView.padding
        let usageView = AboutUsageView(width: contentWidth)
        let table = TableGroupView(width: columnWidth)
        settingsUsageView = usageView
        table.addRow(leftViews: [makeContentView(false, false, false)], isAddSeparator: false)
        table.addRow(leftViews: [usageView])
        table.addRow(leftViews: [AcknowledgmentsTab.makeContentView(columnWidth: contentWidth)])
        return TableGroupSetView(originalViews: [table], padding: 0, bottomPadding: 0)
    }

    static func refreshSettingsUsageStats() {
        settingsUsageView?.refresh(animated: true)
    }

    private static func secondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func centered(_ content: NSView) -> NSView {
        let leading = NSView()
        let trailing = NSView()
        let row = NSStackView(views: [leading, content, trailing])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.spacing = 0
        leading.widthAnchor.constraint(equalTo: trailing.widthAnchor).isActive = true
        return row
    }
}

final class AboutUsageView: NSStackView {
    private let badges: [AboutUsageBadgeView]
    private var animationTimer: Timer?
    private var animationStartedAt = CFAbsoluteTime(0)
    private var targetCounts = [0, 0, 0]
    private static let animationDuration = CFTimeInterval(0.55)

    init(width: CGFloat) {
        badges = [
            AboutUsageBadgeView(period: NSLocalizedString("Past week", comment: "Usage period")),
            AboutUsageBadgeView(period: NSLocalizedString("Past month", comment: "Usage period")),
            AboutUsageBadgeView(period: NSLocalizedString("Past year", comment: "Usage period")),
        ]
        super.init(frame: .zero)
        setup(width: width)
    }

    required init(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        animationTimer?.invalidate()
    }

    func refresh(animated: Bool) {
        let now = Date()
        targetCounts = [
            UsageStats.count("triggers", since: now.addingTimeInterval(-7 * 24 * 3600)),
            UsageStats.count("triggers", since: now.addingTimeInterval(-30 * 24 * 3600)),
            UsageStats.count("triggers", since: now.addingTimeInterval(-365 * 24 * 3600)),
        ]
        animationTimer?.invalidate()
        guard animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            display(targetCounts)
            return
        }
        display([0, 0, 0])
        animationStartedAt = CFAbsoluteTimeGetCurrent()
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] timer in self?.advanceAnimation(timer) }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func setup(width: CGFloat) {
        orientation = .vertical
        alignment = .leading
        spacing = DesignSystem.Metrics.rowHorizontalPadding
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        let title = NSTextField(labelWithString: NSLocalizedString("Usage", comment: ""))
        title.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        let badgeRow = NSStackView(views: badges)
        badgeRow.translatesAutoresizingMaskIntoConstraints = false
        badgeRow.spacing = DesignSystem.Metrics.rowHorizontalPadding
        badgeRow.distribution = .fillEqually
        addArrangedSubview(title)
        addArrangedSubview(badgeRow)
        badgeRow.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        badgeRow.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        display([0, 0, 0])
    }

    private func advanceAnimation(_ timer: Timer) {
        let elapsed = CFAbsoluteTimeGetCurrent() - animationStartedAt
        let progress = min(1, elapsed / Self.animationDuration)
        let eased = 1 - pow(1 - progress, 3)
        display(targetCounts.map { Int((Double($0) * eased).rounded()) })
        guard progress >= 1 else { return }
        timer.invalidate()
        animationTimer = nil
    }

    private func display(_ counts: [Int]) {
        zip(badges, counts).forEach { $0.update(count: $1) }
    }
}

final class AboutUsageBadgeView: DesignSystemFlatSurfaceView {
    private let countLabel = NSTextField(labelWithString: "0")
    private let period: String
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    init(period: String) {
        self.period = period
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func update(count: Int) {
        countLabel.stringValue = Self.formatter.string(from: NSNumber(value: count)) ?? String(count)
        setAccessibilityLabel(String(format: NSLocalizedString("%@ switches, %@", comment: "Usage badge accessibility label"), countLabel.stringValue, period))
    }

    private func setup() {
        let periodLabel = NSTextField(labelWithString: period)
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        countLabel.textColor = .labelColor
        countLabel.alignment = .center
        periodLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        periodLabel.textColor = .secondaryLabelColor
        periodLabel.alignment = .center
        periodLabel.lineBreakMode = .byWordWrapping
        periodLabel.maximumNumberOfLines = 2
        let stack = NSStackView(views: [countLabel, periodLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = DesignSystem.Metrics.headerFooterGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: DesignSystem.Metrics.rowVerticalPadding),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignSystem.Metrics.rowHorizontalPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignSystem.Metrics.rowHorizontalPadding),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -DesignSystem.Metrics.rowVerticalPadding),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }
}

class AboutWindow: NSPanel {
    private static let contentPadding = DesignSystem.Metrics.formOuterPadding
    static var shared: AboutWindow?
    private var usageView: AboutUsageView!

    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }

    convenience init() {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 330), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        setupWindow()
        setupView()
        setFrameAutosaveNameSafely("AboutWindow3")
        Self.shared = self
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        usageView.refresh(animated: true)
        super.makeKeyAndOrderFront(sender)
    }

    private func setupWindow() {
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        title = String(format: NSLocalizedString("About %@", comment: ""), App.name)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    private func setupView() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        let documentView = FlippedView(frame: .zero)
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        let columnWidth = frame.width - 2 * Self.contentPadding
        let contentWidth = columnWidth - 2 * TableGroupView.padding
        let table = TableGroupView(width: columnWidth)
        usageView = AboutUsageView(width: contentWidth)
        table.addRow(leftViews: [AboutTab.makeContentView(false, false, false)], isAddSeparator: false)
        table.addRow(leftViews: [usageView])
        documentView.addSubview(table)
        contentView = DesignSystemWindowContentView(content: scrollView, topPadding: 10)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Self.contentPadding),
            table.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: Self.contentPadding),
            table.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -Self.contentPadding),
            table.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -Self.contentPadding),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    override func close() {
        hideAppIfLastWindowIsClosed()
        super.close()
    }
}
