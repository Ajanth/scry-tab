import Cocoa
import Foundation

enum FeedbackKind: Hashable {
    case bug
    case enhancement

    var apiValue: String {
        switch self {
        case .bug: return "bug"
        case .enhancement: return "enhancement"
        }
    }
}

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
    private var isSubmitting = false
    private var submissionGeneration: UInt = 0
    private var submissionTask: URLSessionDataTask?

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
        let diagnostic = NSLocalizedString("A debug profile (versions, settings, hardware) is attached to help diagnose the issue.", comment: "")
        let note = NSTextField(wrappingLabelWithString: publicIssue + " " + diagnostic)
        note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        return note
    }

    private func makeFooter() -> NSView {
        let discussions = HyperlinkLabel(
            NSLocalizedString("View existing discussions", comment: "") + " →",
            App.repository + "/issues")
        cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        DesignSystemControlStyler.styleButton(cancelButton)
        sendButton = NSButton(title: NSLocalizedString("Create GitHub issue", comment: ""), target: self, action: #selector(sendCallback))
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
        guard !isSubmitting, let sendButton, let issueTitle, let body else { return }
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

    @objc private func sendCallback() {
        guard !isSubmitting else { return }
        let generation = beginSubmitting()
        let submittedKind = kind
        let request = prepareRequest(kind: submittedKind, title: issueTitle.stringValue, body: body.stringValue)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let succeeded = status == 201 && error == nil
            if !succeeded, (error as? URLError)?.code != .cancelled {
                Logger.error { "feedback POST failed. status:\(status) response:\(response) error:\(error) data:\(data.flatMap { String(data: $0, encoding: .utf8) })" }
            }
            DispatchQueue.main.async {
                guard let self, self.submissionGeneration == generation else { return }
                self.submissionTask = nil
                self.endSubmitting()
                guard succeeded else {
                    self.showSubmitFailureAlert()
                    return
                }
                self.drafts[submittedKind] = nil
                if self.kind == submittedKind {
                    self.issueTitle.stringValue = ""
                    self.body.stringValue = ""
                }
                self.close()
            }
        }
        submissionTask = task
        task.resume()
    }

    private func beginSubmitting() -> UInt {
        submissionGeneration &+= 1
        isSubmitting = true
        typeSelector.isEnabled = false
        issueTitle.isEnabled = false
        body.isEnabled = false
        sendButton.isEnabled = false
        sendButton.title = NSLocalizedString("Sending…", comment: "")
        return submissionGeneration
    }

    private func endSubmitting() {
        isSubmitting = false
        typeSelector.isEnabled = true
        issueTitle.isEnabled = true
        body.isEnabled = true
        sendButton.title = NSLocalizedString("Create GitHub issue", comment: "")
        checkEmptyFields()
    }

    private func showSubmitFailureAlert() {
        guard isVisible else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Couldn't submit feedback", comment: "")
        alert.informativeText = NSLocalizedString("The server didn't accept the submission. Check your internet connection and try again — your draft is preserved.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    private func prepareRequest(kind: FeedbackKind, title: String, body: String) -> URLRequest {
        var request = URLRequest(url: URL(string: Endpoints.feedbackUrl)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try! JSONSerialization.data(withJSONObject: [
            "title": title,
            "body": body,
            "kind": kind.apiValue,
            "debugProfile": DebugProfile.make(),
        ])
        return request
    }

    override func close() {
        cancelSubmission()
        captureCurrentDraft()
        hideAppIfLastWindowIsClosed()
        super.close()
    }

    private func cancelSubmission() {
        guard isSubmitting else { return }
        submissionGeneration &+= 1
        submissionTask?.cancel()
        submissionTask = nil
        endSubmitting()
    }
}
