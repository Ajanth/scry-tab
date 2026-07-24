import Cocoa

private struct Draft {
    var title: String = ""
    var body: String = ""
}

class FeedbackWindow: NSWindow {
    static let titleMaxLength = 256
    static let bodyMaxLength = 64 * 1024
    static var shared: FeedbackWindow?
    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }

    var kind: FeedbackKind = .bug
    var issueTitle: TextArea!
    var body: TextArea!
    var sendButton: NSButton!
    private var cancelButton: NSButton!
    private var typeSelector: DesignSystemSegmentedControl!
    private var drafts: [FeedbackKind: Draft] = [:]

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        setupWindow()
        setFrameAutosaveNameSafely("FeedbackWindow")
        Self.shared = self
        reset()
    }

    func reset() {
        captureCurrentDraft()
        kind = .bug
        showComposer()
    }

    private func setupWindow() {
        title = NSLocalizedString("Send feedback", comment: "")
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    private func showComposer() {
        makeFields()
        let header = makeHeader()
        let typeSection = makeFieldSection(
            title: NSLocalizedString("Feedback type", comment: ""),
            control: makeTypeSelector())
        let summarySection = makeFieldSection(
            title: NSLocalizedString("Summary", comment: ""),
            control: issueTitle)
        let detailsSection = makeFieldSection(
            title: NSLocalizedString("Details", comment: ""),
            control: body)
        let privacyNote = makePrivacyNote()
        let divider = DesignSystemDividerView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let footer = makeFooter()
        let root = NSStackView(views: [header, typeSection, summarySection, detailsSection, privacyNote, divider, footer])
        root.translatesAutoresizingMaskIntoConstraints = false
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = DesignSystem.Metrics.sectionGap
        root.edgeInsets = NSEdgeInsets(
            top: GridView.padding,
            left: GridView.padding,
            bottom: GridView.padding,
            right: GridView.padding)
        [header, typeSection, summarySection, detailsSection, privacyNote, divider, footer].forEach {
            $0.widthAnchor.constraint(equalTo: issueTitle.widthAnchor).isActive = true
        }
        root.setCustomSpacing(DesignSystem.Metrics.headerFooterGap, after: privacyNote)
        root.setCustomSpacing(DesignSystem.Metrics.formOuterPadding, after: divider)
        let container = DesignSystemWindowContentView(content: root, topPadding: 10)
        contentView = container
        setContentSize(container.fittingSize)
        configureKeyboardNavigation()
        checkEmptyFields()
        makeFirstResponder(issueTitle)
    }

    private func makeFields() {
        issueTitle = TextArea(76, 1, titlePlaceholder(), checkEmptyFields, Self.titleMaxLength)
        body = TextArea(76, 10, bodyPlaceholder(), checkEmptyFields, Self.bodyMaxLength)
        issueTitle.setAccessibilityLabel(NSLocalizedString("Summary", comment: ""))
        body.setAccessibilityLabel(NSLocalizedString("Details", comment: ""))
        DesignSystemControlStyler.styleTextField(issueTitle)
        DesignSystemControlStyler.styleTextField(body)
        restoreCurrentDraft()
    }

    private func makeHeader() -> NSView {
        let appIcon = LightImageView()
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        let iconSize = NSSize(width: 48, height: 48)
        appIcon.updateContents(.cgImage(App.appIcon(for: iconSize)), iconSize)
        appIcon.fit(iconSize.width, iconSize.height)
        let title = BoldLabel(NSLocalizedString("Send feedback", comment: ""))
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let subtitle = NSTextField(labelWithString: NSLocalizedString("Help improve ScryTab", comment: ""))
        subtitle.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = DesignSystem.Metrics.headerFooterGap
        let header = NSStackView(views: [appIcon, labels])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.alignment = .centerY
        header.spacing = DesignSystem.Metrics.formOuterPadding
        return header
    }

    private func makeTypeSelector() -> DesignSystemSegmentedControl {
        let labels = [
            NSLocalizedString("Report a bug", comment: ""),
            NSLocalizedString("Suggest a change", comment: ""),
        ]
        let selector = DesignSystemSegmentedControl(labels: labels, trackingMode: .selectOne, target: self, action: #selector(changeKind))
        selector.selectedSegment = kind == .bug ? 0 : 1
        selector.setImage(NSImage.fromSymbol(.circledInfo, pointSize: 13), forSegment: 0)
        selector.setImage(NSImage.fromSymbol(.sparkles, pointSize: 13), forSegment: 1)
        selector.setAccessibilityLabel(NSLocalizedString("Feedback type", comment: ""))
        DesignSystemControlStyler.styleSegmentedControl(selector)
        typeSelector = selector
        return selector
    }

    private func makeFieldSection(title: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        let section = NSStackView(views: [label, control])
        section.translatesAutoresizingMaskIntoConstraints = false
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = DesignSystem.Metrics.headerFooterGap
        control.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private func makePrivacyNote() -> NSTextField {
        let publicIssue = NSLocalizedString("Your feedback will be submitted as a public GitHub issue.", comment: "")
        let review = NSLocalizedString("You'll review it on GitHub before publishing. Diagnostic data is not attached automatically.", comment: "")
        let note = NSTextField(wrappingLabelWithString: publicIssue + " " + review)
        note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        return note
    }

    private func makeFooter() -> NSView {
        let discussions = HyperlinkLabel(
            NSLocalizedString("View existing discussions", comment: "") + " →",
            FeedbackGitHubComposer.issuesURLString(repositoryURLString: App.feedbackRepository))
        cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        DesignSystemControlStyler.styleButton(cancelButton)
        sendButton = NSButton(title: NSLocalizedString("Continue on GitHub", comment: ""), target: self, action: #selector(continueOnGitHub))
        sendButton.keyEquivalent = "\r"
        DesignSystemControlStyler.styleButton(sendButton)
        if #available(macOS 10.14, *) {
            sendButton.bezelColor = .controlAccentColor
        }
        let actions = NSStackView(views: [cancelButton, sendButton])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.alignment = .centerY
        actions.spacing = TableGroupView.toolRowSpacing
        let footer = NSStackView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.addView(discussions, in: .leading)
        footer.addView(actions, in: .trailing)
        return footer
    }

    private func configureKeyboardNavigation() {
        typeSelector.nextKeyView = issueTitle
        issueTitle.nextKeyView = body
        body.nextKeyView = cancelButton
        cancelButton.nextKeyView = sendButton
        sendButton.nextKeyView = typeSelector
    }

    @objc private func changeKind() {
        let selectedKind: FeedbackKind = typeSelector.selectedSegment == 1 ? .enhancement : .bug
        guard selectedKind != kind else { return }
        captureCurrentDraft()
        kind = selectedKind
        issueTitle.placeholderString = titlePlaceholder()
        body.placeholderString = bodyPlaceholder()
        restoreCurrentDraft()
        checkEmptyFields()
        makeFirstResponder(issueTitle)
    }

    private func captureCurrentDraft() {
        guard let issueTitle, let body else { return }
        drafts[kind] = Draft(title: issueTitle.stringValue, body: body.stringValue)
    }

    private func restoreCurrentDraft() {
        let draft = drafts[kind] ?? Draft()
        issueTitle.stringValue = draft.title
        body.stringValue = draft.body
    }

    private func titlePlaceholder() -> String {
        switch kind {
        case .bug: return NSLocalizedString("Brief description of the bug", comment: "")
        case .enhancement: return NSLocalizedString("Brief description of the change", comment: "")
        }
    }

    private func bodyPlaceholder() -> String {
        switch kind {
        case .bug: return NSLocalizedString("What did you expect? What happened? Steps to reproduce…", comment: "")
        case .enhancement: return NSLocalizedString("I think the app could be improved with…", comment: "")
        }
    }

    private func checkEmptyFields() {
        guard let sendButton, let issueTitle, let body else { return }
        let whitespace = CharacterSet.whitespacesAndNewlines
        sendButton.isEnabled = !issueTitle.stringValue.trimmingCharacters(in: whitespace).isEmpty
            && !body.stringValue.trimmingCharacters(in: whitespace).isEmpty
        sendButton.toolTip = sendButton.isEnabled ? "" : NSLocalizedString("Please fill in the form", comment: "")
    }

    @objc func cancel(_ sender: Any?) {
        close()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "\r",
           let sendButton,
           sendButton.isEnabled {
            sendButton.performClick(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @objc private func continueOnGitHub() {
        guard let url = FeedbackGitHubComposer.issueComposerURL(
            kind: kind,
            title: issueTitle.stringValue,
            details: body.stringValue
        ) else { return }
        guard NSWorkspace.shared.open(url) else {
            showOpenFailureAlert()
            return
        }
        drafts[kind] = nil
        issueTitle.stringValue = ""
        body.stringValue = ""
        close()
    }

    private func showOpenFailureAlert() {
        guard isVisible else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Couldn't open GitHub", comment: "")
        alert.informativeText = NSLocalizedString("Your draft is preserved. Check that a browser is available and try again.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    override func close() {
        captureCurrentDraft()
        hideAppIfLastWindowIsClosed()
        super.close()
    }
}
