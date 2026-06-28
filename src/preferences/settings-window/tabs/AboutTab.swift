import Cocoa

class AboutTab {
    private static weak var settingsUsageTextView: NSTextView?

    static func initTab() -> NSView {
        makeSettingsContentView(columnWidth: SettingsWindow.contentWidth)
    }

    static func makeContentView(_ fitToContent: Bool = true, _ showFeedbackButton: Bool = true, _ centerHero: Bool = false) -> NSView {
        let appIcon = LightImageView()
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        let appIconSize = NSSize(width: 128, height: 128)
        appIcon.updateContents(.cgImage(App.appIcon(for: appIconSize)), appIconSize)
        appIcon.fit(128, 128)
        var textViews: [NSView] = [
            BoldLabel(App.name),
            makeVersionRow(),
            NSTextField(wrappingLabelWithString: App.licence),
            HyperlinkLabel(NSLocalizedString("Website", comment: ""), Endpoints.website),
            HyperlinkLabel(NSLocalizedString("Source code", comment: ""), App.repository),
        ]
        if showFeedbackButton {
            let feedback = HyperlinkLabel(NSLocalizedString("Feedback", comment: "")) { App.showFeedbackPanel() }
            textViews.append(feedback)
        }
        let appText = StackView(textViews, .vertical)
        appText.spacing = GridView.interPadding / 2
        let rowToSeparate = 3
        appText.views[rowToSeparate].topAnchor.constraint(equalTo: appText.views[rowToSeparate - 1].bottomAnchor, constant: GridView.interPadding).isActive = true
        let appInfo = NSStackView(views: [appIcon, appText])
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appInfo.spacing = GridView.interPadding
        appInfo.alignment = .centerY
        let rows = [[appInfo]]
        let grid = GridView(rows, 0)
        if centerHero {
            grid.cell(atColumnIndex: 0, rowIndex: 0).xPlacement = .center
        }
        if fitToContent {
            grid.fit()
        }
        return grid
    }

    private static func makeVersionRow() -> NSView {
        let versionLabel = NSTextField(labelWithString: NSLocalizedString("Version", comment: "") + " " + App.version)
        let copyButton = SurfaceButton(title: NSLocalizedString("Copy version", comment: ""), role: .flat) { _ in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(App.version, forType: .string)
        }
        let row = NSStackView(views: [versionLabel, copyButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = DesignMetric.rowContentGap
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    static func makeSettingsContentView(columnWidth: CGFloat) -> NSView {
        SettingsFocusRegistry.shared.unregisterPrefix("about-")
        let form = SettingsFormView()
        let aboutView = makeContentView(false, true, false)
        form.addArrangedSubview(aboutView)
        aboutView.leadingAnchor.constraint(equalTo: form.leadingAnchor, constant: form.edgeInsets.left).isActive = true
        aboutView.trailingAnchor.constraint(equalTo: form.trailingAnchor, constant: -form.edgeInsets.right).isActive = true
        SettingsFocusRegistry.shared.register("about-hero", aboutView)
        let usageTextView = makeUsageTextView(columnWidth)
        settingsUsageTextView = usageTextView
        let usageSection = SettingsSectionView(title: NSLocalizedString("Usage", comment: ""))
        let usageRow = SettingsRowView(title: NSLocalizedString("Activity", comment: ""), content: [usageTextView])
        usageRow.registerFocusAnchor("about-usage")
        usageSection.addRow(usageRow)
        form.addSection(usageSection)
        let acknowledgmentsView = AcknowledgmentsTab.makeContentView(columnWidth: columnWidth, shouldFit: false, verticallyStacked: true)
        let ackSection = SettingsSectionView(title: NSLocalizedString("Acknowledgments", comment: ""))
        let ackRow = SettingsRowView(title: "", content: [acknowledgmentsView], showsSeparator: false)
        ackRow.registerFocusAnchor("about-acknowledgments")
        ackSection.addRow(ackRow)
        form.addSection(ackSection)
        refreshSettingsUsageStats()
        return form
    }

    static func refreshSettingsUsageStats() {
        guard let settingsUsageTextView else { return }
        updateUsageStats(settingsUsageTextView)
    }

    private static func makeUsageTextView(_ columnWidth: CGFloat) -> NSTextView {
        let textView = NSTextView()
        textView.textContainer!.widthTracksTextView = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.drawsBackground = false
        textView.isSelectable = true
        textView.isEditable = false
        textView.enabledTextCheckingTypes = 0
        textView.frame.size.width = columnWidth
        return textView
    }

    private static func updateUsageStats(_ textView: NSTextView) {
        let now = Date()
        let weekCount = UsageStats.count("triggers", since: now.addingTimeInterval(-7 * 24 * 3600))
        let monthCount = UsageStats.count("triggers", since: now.addingTimeInterval(-30 * 24 * 3600))
        let yearCount = UsageStats.count("triggers", since: now.addingTimeInterval(-365 * 24 * 3600))
        let markdown = "## \(NSLocalizedString("Usage", comment: ""))\n\nYou have used ScryTab:\n\u{2022} **\(weekCount)** times in the past week\n\u{2022} **\(monthCount)** times in the past month\n\u{2022} **\(yearCount)** times in the past year"
        textView.textStorage!.setAttributedString(Markdown.toAttributedString(markdown))
        textView.layoutManager!.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager!.usedRect(for: textView.textContainer!)
        textView.invalidateIntrinsicContentSize()
        textView.fit(usedRect.width, usedRect.height)
    }
}

class AboutWindow: NSPanel {
    private static let contentPadding = CGFloat(24)
    static var shared: AboutWindow?
    private var usageTextView: NSTextView!

    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }

    convenience init() {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 450), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        setupWindow()
        setupView()
        setFrameAutosaveNameSafely("AboutWindow2")
        Self.shared = self
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        updateUsageStats()
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
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 30
        stack.translatesAutoresizingMaskIntoConstraints = false
        let aboutView = AboutTab.makeContentView(false, false, true)
        let columnWidth = frame.width - 2 * Self.contentPadding
        usageTextView = Self.makeUsageTextView(columnWidth)
        let acknowledgmentsView = AcknowledgmentsTab.makeContentView(columnWidth: columnWidth, shouldFit: false, verticallyStacked: true)
        acknowledgmentsView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(aboutView)
        stack.addArrangedSubview(usageTextView)
        stack.addArrangedSubview(acknowledgmentsView)
        stack.setCustomSpacing(15, after: usageTextView)
        documentView.addSubview(stack)
        contentView = scrollView
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Self.contentPadding),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: Self.contentPadding),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -Self.contentPadding),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -Self.contentPadding),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            aboutView.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            aboutView.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            usageTextView.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            usageTextView.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            acknowledgmentsView.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            acknowledgmentsView.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])
    }

    private static func makeUsageTextView(_ columnWidth: CGFloat) -> NSTextView {
        let textView = NSTextView()
        textView.textContainer!.widthTracksTextView = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.drawsBackground = false
        textView.isSelectable = true
        textView.isEditable = false
        textView.enabledTextCheckingTypes = 0
        textView.frame.size.width = columnWidth
        return textView
    }

    private func updateUsageStats() {
        let now = Date()
        let weekCount = UsageStats.count("triggers", since: now.addingTimeInterval(-7 * 24 * 3600))
        let monthCount = UsageStats.count("triggers", since: now.addingTimeInterval(-30 * 24 * 3600))
        let yearCount = UsageStats.count("triggers", since: now.addingTimeInterval(-365 * 24 * 3600))
        let markdown = "## \(NSLocalizedString("Usage", comment: ""))\n\nYou have used ScryTab:\n\u{2022} **\(weekCount)** times in the past week\n\u{2022} **\(monthCount)** times in the past month\n\u{2022} **\(yearCount)** times in the past year"
        usageTextView.textStorage!.setAttributedString(Markdown.toAttributedString(markdown))
        usageTextView.layoutManager!.ensureLayout(for: usageTextView.textContainer!)
        let usedRect = usageTextView.layoutManager!.usedRect(for: usageTextView.textContainer!)
        usageTextView.invalidateIntrinsicContentSize()
        usageTextView.fit(usedRect.width, usedRect.height)
    }

    override func close() {
        hideAppIfLastWindowIsClosed()
        super.close()
    }
}
