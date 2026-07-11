import Cocoa

struct ShowHideRowInfo {
    var rowId: String!
    var uncheckedImage: String!
    var checkedImage: String!
    var supportedStyles: [AppearanceStylePreference]!
    var subTitle: String?
    var leftViews = [NSView]()
    var rightViews = [NSView]()
}

class IllustratedImageThemeView: ClickHoverImageView {
    override var acceptsFirstResponder: Bool { false }
    static let padding = CGFloat(4)
    /// Shown when the current Appearance style doesn't support a Show/Hide option (the illustration
    /// is for another style). Exposed so `CustomizeStyleSheet.searchableStrings` can reference it
    /// without re-`NSLocalizedString`-ing the same English text.
    static let placeholderLabelText = NSLocalizedString("Applies in other Appearances", comment: "")
    private let style: AppearanceStylePreference
    private let imageView: NSImageView
    private var isFocused = false
    private var placeholderLabel: NSTextField!

    init(_ style: AppearanceStylePreference, _ width: CGFloat) {
        self.style = style
        imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = TableGroupView.cornerRadius
        super.init(infoCircle: imageView)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        let imageWidth = width - IllustratedImageThemeView.padding
        let imageHeight = imageWidth / 1.6
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: imageWidth),
            imageView.heightAnchor.constraint(equalToConstant: imageHeight),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: IllustratedImageThemeView.padding),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -IllustratedImageThemeView.padding),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: IllustratedImageThemeView.padding),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -IllustratedImageThemeView.padding),
        ])
        let placeholder = NSTextField(labelWithString: IllustratedImageThemeView.placeholderLabelText)
        placeholder.font = NSFont.systemFont(ofSize: NSFont.systemFontSize + 3)
        placeholder.textColor = .secondaryLabelColor
        placeholder.alignment = .center
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isHidden = true
        addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            placeholder.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: IllustratedImageThemeView.padding + 8),
            placeholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -(IllustratedImageThemeView.padding + 8)),
        ])
        placeholderLabel = placeholder
        highlight(false)
        onClick = { [weak self] _, _ in self?.highlight(false) }
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func setBorder() {
        layer?.cornerRadius = TableGroupView.cornerRadius + 3
        let color = DesignSystem.color(isFocused ? .borderSelected : .borderSubtle, appearance: effectiveAppearance)
        layer?.borderColor = DesignSystem.resolvedCGColor(color, in: self)
        layer?.borderWidth = isFocused ? 2 : 1
    }

    private func setFocused(_ focused: Bool) {
        isFocused = focused
    }

    func highlight(_ highlighted: Bool, _ imageName: String = "") {
        if highlighted && imageName.isEmpty {
            return
        }
        setFocused(highlighted)
        setBorder()
        placeholderLabel.isHidden = true
        infoCircle.isHidden = false
        imageView.image = AppearanceLivePreviewArtwork.illustratedPreviewImage(previewState(highlighted ? imageName : nil))
    }

    func showPlaceholder() {
        setFocused(true)
        setBorder()
        infoCircle.isHidden = true
        placeholderLabel.isHidden = false
    }

    private func previewState(_ imageName: String?) -> AppearanceLivePreviewArtwork.IllustratedPreviewState {
        var state = style == .appIcons
            ? AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                   titleMode: .focusedAppName,
                                                                   showsStatusIcons: false,
                                                                   showsSpaceNumbers: false,
                                                                   highlight: .none)
            : AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                   titleMode: .appNameAndWindowTitle,
                                                                   showsStatusIcons: true,
                                                                   showsSpaceNumbers: true,
                                                                   highlight: .none)
        guard let imageName else { return state }
        if imageName == ShowTitlesPreference.appName.image.name {
            state = AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                         titleMode: .appName,
                                                                         showsStatusIcons: state.showsStatusIcons,
                                                                         showsSpaceNumbers: state.showsSpaceNumbers,
                                                                         highlight: .none)
        }
        if imageName == ShowTitlesPreference.windowTitle.image.name {
            state = AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                         titleMode: .windowTitle,
                                                                         showsStatusIcons: state.showsStatusIcons,
                                                                         showsSpaceNumbers: state.showsSpaceNumbers,
                                                                         highlight: .none)
        }
        if imageName == ShowTitlesPreference.appNameAndWindowTitle.image.name {
            state = AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                         titleMode: .appNameAndWindowTitle,
                                                                         showsStatusIcons: state.showsStatusIcons,
                                                                         showsSpaceNumbers: state.showsSpaceNumbers,
                                                                         highlight: .none)
        }
        if imageName == "show_status_icons" {
            state = AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                         titleMode: state.titleMode,
                                                                         showsStatusIcons: true,
                                                                         showsSpaceNumbers: state.showsSpaceNumbers,
                                                                         highlight: .statusIcons)
        }
        if imageName == "hide_status_icons" {
            state = AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                         titleMode: state.titleMode,
                                                                         showsStatusIcons: false,
                                                                         showsSpaceNumbers: state.showsSpaceNumbers,
                                                                         highlight: .none)
        }
        if imageName == "show_space_number_labels" {
            state = AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                         titleMode: state.titleMode,
                                                                         showsStatusIcons: state.showsStatusIcons,
                                                                         showsSpaceNumbers: true,
                                                                         highlight: .spaceNumbers)
        }
        if imageName == "hide_space_number_labels" {
            state = AppearanceLivePreviewArtwork.IllustratedPreviewState(style: style,
                                                                         titleMode: state.titleMode,
                                                                         showsStatusIcons: state.showsStatusIcons,
                                                                         showsSpaceNumbers: false,
                                                                         highlight: .none)
        }
        return state
    }

    static func resetImage(_ illustratedImageView: IllustratedImageThemeView, _ event: NSEvent, _ view: NSView) {
        let locationInView = view.convert(event.locationInWindow, from: nil)
        if !view.bounds.contains(locationInView) {
            illustratedImageView.highlight(false)
        }
    }
}

class ShowHideIllustratedView {
    // Row labels exposed so `CustomizeStyleSheet.searchableStrings` can reference them without
    // duplicating `NSLocalizedString` calls. Each is the single source of truth for that row's
    // localized text; `setupItems` below uses these constants when building the rows.
    static let hideStatusIconsLabel = NSLocalizedString("Hide status icons", comment: "")
    static let hideStatusIconsSubtitle = NSLocalizedString("ScryTab will show if the window is currently minimized or fullscreen with a status icon.", comment: "")
    static let hideSpaceNumberLabelsLabel = NSLocalizedString("Hide Space number labels", comment: "")

    private let style: AppearanceStylePreference
    private var showHideRows = [ShowHideRowInfo]()
    var illustratedImageView: IllustratedImageThemeView!
    var table: TableGroupView!

    init(_ style: AppearanceStylePreference, _ illustratedImageView: IllustratedImageThemeView) {
        self.style = style
        self.illustratedImageView = illustratedImageView
        setupItems()
    }

    func makeView(width: CGFloat, title: String? = nil) -> TableGroupView {
        table = TableGroupView(title: title, width: width)
        for row in showHideRows {
            table.addRow(leftViews: row.leftViews, rightViews: row.rightViews, onClick: { [weak self] _, _ in
                self?.clickCheckbox(rowId: row.rowId)
                self?.updateImageView(rowId: row.rowId)
            }, onMouseEntered: { [weak self] _, _ in
                self?.updateImageView(rowId: row.rowId)
            })
        }
        table.onMouseExited = { [weak self] event, view in
            guard let self else { return }
            IllustratedImageThemeView.resetImage(self.illustratedImageView, event, view)
        }
        return table
    }

    private func setupItems() {
        var hideStatusIcons = ShowHideRowInfo()
        hideStatusIcons.rowId = "hideStatusIcons"
        hideStatusIcons.uncheckedImage = "show_status_icons"
        hideStatusIcons.checkedImage = "hide_status_icons"
        hideStatusIcons.supportedStyles = [.appIcons, .titles]
        hideStatusIcons.leftViews = [TableGroupView.makeText(ShowHideIllustratedView.hideStatusIconsLabel)]
        hideStatusIcons.subTitle = ShowHideIllustratedView.hideStatusIconsSubtitle
        hideStatusIcons.rightViews.append(LabelAndControl.makeInfoButton(searchableTooltipTexts: [hideStatusIcons.subTitle!], onMouseEntered: { event, view in
            Popover.shared.show(event: event, positioningView: view, message: hideStatusIcons.subTitle!)
        }, onMouseExited: { event, view in
            Popover.shared.hide()
        }))
        hideStatusIcons.rightViews.append(LabelAndControl.makeSwitch(hideStatusIcons.rowId, extraAction: { sender in
            self.onCheckboxClicked(sender: sender, rowId: hideStatusIcons.rowId)
        }))
        showHideRows.append(hideStatusIcons)
        var hideSpaceNumberLabels = ShowHideRowInfo()
        hideSpaceNumberLabels.rowId = "hideSpaceNumberLabels"
        hideSpaceNumberLabels.uncheckedImage = "show_space_number_labels"
        hideSpaceNumberLabels.checkedImage = "hide_space_number_labels"
        hideSpaceNumberLabels.supportedStyles = [.appIcons, .titles]
        hideSpaceNumberLabels.leftViews = [TableGroupView.makeText(ShowHideIllustratedView.hideSpaceNumberLabelsLabel)]
        hideSpaceNumberLabels.rightViews.append(LabelAndControl.makeSwitch(hideSpaceNumberLabels.rowId, extraAction: { sender in
            self.onCheckboxClicked(sender: sender, rowId: hideSpaceNumberLabels.rowId)
        }))
        showHideRows.append(hideSpaceNumberLabels)
    }

    /// Handles the event when a checkbox is clicked.
    /// Updates the image view based on the state of the checkbox.
    ///
    /// - Parameters:
    ///   - sender: The checkbox button that was clicked.
    ///   - rowId: The identifier for the row associated with the checkbox.
    private func onCheckboxClicked(sender: NSControl, rowId: String) {
        if let sender = sender as? NSButton {
            let isChecked = sender.state == .on
            updateImageView(rowId: rowId, isChecked: isChecked)
        }
    }

    private func updateImageView(rowId: String, isChecked: Bool) {
        guard let row = showHideRows.first(where: { $0.rowId.elementsEqual(rowId) }) else { return }
        if !row.supportedStyles.contains(style) {
            illustratedImageView.showPlaceholder()
            return
        }
        let imageName = isChecked ? row.checkedImage : row.uncheckedImage
        illustratedImageView.highlight(true, imageName!)
    }

    private func updateImageView(rowId: String) {
        guard let row = showHideRows.first(where: { $0.rowId.elementsEqual(rowId) }) else { return }
        if !row.supportedStyles.contains(style) {
            illustratedImageView.showPlaceholder()
            return
        }
        row.rightViews.forEach { view in
            if let checkbox = view as? NSButton {
                let isChecked = checkbox.state == .on
                let imageName = isChecked ? row.checkedImage : row.uncheckedImage
                illustratedImageView.highlight(true, imageName!)
            }
        }
    }

    private func clickCheckbox(rowId: String) {
        let row = showHideRows.first {
            $0.rowId.elementsEqual(rowId)
        }
        row?.rightViews.forEach { view in
            if let checkbox = view as? NSButton {
                // Toggle the checkbox state
                checkbox.state = (checkbox.state == .on) ? .off : .on
            }
        }
    }
}

private final class AppearanceStylePreviewPane: NSView {
    static let width = CGFloat(320)
    static let splitSpacing = TableGroupView.spacing
    private let livePreviewView = AppearanceLivePreviewView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        refreshAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func updateStyle(_ style: AppearanceStylePreference) {
        livePreviewView.updateStyle(style)
    }

    func refreshAppearance() {
        livePreviewView.updateAppearance(
            style: AppearanceTab.selectedAppearanceStyle(),
            size: AppearanceTab.selectedAppearanceSize(),
            theme: AppearanceTab.selectedAppearanceTheme())
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(livePreviewView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            livePreviewView.topAnchor.constraint(equalTo: topAnchor),
            livePreviewView.bottomAnchor.constraint(equalTo: bottomAnchor),
            livePreviewView.leadingAnchor.constraint(equalTo: leadingAnchor),
            livePreviewView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}

class Popover: NSPopover {
    static let shared = Popover()
    private var hidingInitiated = true
    private var searchQuery = ""
    private var searchMatchRanges: ((String, String) -> [Range<Int>])?
    private var currentMessage = ""
    private weak var currentMessageLabel: NSTextField?

    override init() {
        super.init()
        delegate = self
        contentViewController = NSViewController()
        behavior = .semitransient
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func hide() {
        performClose(nil)
    }

    func updateSearchContext(_ query: String, _ searchMatchRanges: @escaping (String, String) -> [Range<Int>]) {
        searchQuery = query
        self.searchMatchRanges = searchMatchRanges
        applySearchHighlightToCurrentMessage()
    }

    func show(event: NSEvent, positioningView: NSView, message: String, extraView: NSView? = nil) {
        if !hidingInitiated { return }
        hidingInitiated = false
        let view = NSView()
        let label = NSTextField(labelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.isEditable = false
        label.isSelectable = true
        label.font = NSFont.systemFont(ofSize: 12)
        let actualView: NSView
        if let extraView {
            actualView = StackView([label, extraView], .vertical, spacing: DesignSystem.Metrics.headerFooterGap)
        } else {
            actualView = label
        }
        view.addSubview(actualView)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            actualView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            actualView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            actualView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            actualView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
        ])
        currentMessage = message
        currentMessageLabel = label
        applySearchHighlightToCurrentMessage()
        contentViewController?.view = view
        // Convert the mouse location to the positioning view's coordinate system
        let locationInWindow = event.locationInWindow
        let locationInPositioningView = positioningView.convert(locationInWindow, from: nil)
        let rect = CGRect(origin: locationInPositioningView, size: .zero)
        show(relativeTo: rect, of: positioningView, preferredEdge: .minX)
    }

    private func applySearchHighlightToCurrentMessage() {
        guard let label = currentMessageLabel else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: label.font ?? NSFont.systemFont(ofSize: 12),
            .foregroundColor: label.textColor ?? NSColor.labelColor
        ]
        let attributed = NSMutableAttributedString(string: currentMessage, attributes: attributes)
        guard let searchMatchRanges, !currentMessage.isEmpty else {
            label.attributedStringValue = attributed
            return
        }
        let ranges = searchMatchRanges(searchQuery, currentMessage)
        guard !ranges.isEmpty else {
            label.attributedStringValue = attributed
            return
        }
        ranges.compactMap {
            characterRangeToNSRange($0, in: currentMessage)
        }.forEach {
            attributed.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.5), range: $0)
            attributed.addAttribute(.foregroundColor, value: NSColor(calibratedWhite: 0.12, alpha: 1), range: $0)
        }
        label.attributedStringValue = attributed
    }

    private func characterRangeToNSRange(_ range: Range<Int>, in text: String) -> NSRange? {
        if range.lowerBound < 0 || range.upperBound > text.count || range.isEmpty { return nil }
        let start = text.index(text.startIndex, offsetBy: range.lowerBound)
        let end = text.index(text.startIndex, offsetBy: range.upperBound)
        return NSRange(start..<end, in: text)
    }
}

extension Popover: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        hidingInitiated = true
        currentMessage = ""
        currentMessageLabel = nil
    }
}

class AppearanceTab: NSObject {
    // Localized labels for the per-setting rows. Exposed so `ShortcutEditor.AppearancePane`
    // (the per-shortcut override pane) can reference the same string for each conceptual
    // setting instead of re-`NSLocalizedString`-ing them.
    static let labelSize = NSLocalizedString("Size", comment: "")
    static let labelTheme = NSLocalizedString("Theme", comment: "")
    static let labelShortcutStyle = NSLocalizedString("After keys are released", comment: "")

    static var customizeStyleButton: NSButton!
    static var customizeStyleSheet: CustomizeStyleSheet!
    private static let appearanceControlsWidth = SettingsWindow.contentWidth - AppearanceStylePreviewPane.width - AppearanceStylePreviewPane.splitSpacing
    private static let styleSegmentWidth = CGFloat(132)

    static func initTab() -> NSView {
        customizeStyleButton = DesignSystemControlStyler.makeButton(getCustomizeStyleButtonTitle(), target: self, action: #selector(showCustomizeStyleSheet))
        // The customize sheet is constructed lazily on first show.
        return makeView()
    }

    static func cleanup() {
        // Don't call .close() — NSWindow's default `isReleasedWhenClosed = true` interacts
        // badly with our manual nil-out and causes double-release. ARC reclaims the sheet
        // when the static ref is nilled.
        customizeStyleButton = nil
        customizeStyleSheet = nil
    }

    private static func makeView() -> NSView {
        let previewPane = AppearanceStylePreviewPane()
        let appearanceView = makeAppearanceControlsView(previewPane)
        let multipleScreensView = makeMultipleScreensView()
        // `padding: 0` — `TableGroupSetView` adds 20pt of horizontal inset by default before its
        // inner content stack. The enclosing section (from `SettingsWindow.addSection`) already
        // provides the section's left margin via `contentHorizontalPadding`, so adding another
        // 20pt here pushes the TGV content to `container.leading + 20`, while the section title
        // sits at `container.leading + TableGroupView.padding(10)` — a 10pt visible misalignment
        // between the title and the row content below it.
        let leftColumn = TableGroupSetView(originalViews: [appearanceView, multipleScreensView], titleTableGroupSpacing: 15, padding: 0, bottomPadding: 0)
        leftColumn.translatesAutoresizingMaskIntoConstraints = false
        // Plain container (not a stack view) because the preview pane's top must align with
        // `appearanceView`'s row panel rather than with `leftColumn`'s own top, which sits above
        // that panel's subtitle. A stack view's `.top` alignment can only match sibling frames,
        // not a specific descendant, and would fight a manual constraint to that descendant.
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(leftColumn)
        view.addSubview(previewPane)
        let previewTopAnchor = appearanceView.tableStackViews.first?.topAnchor ?? appearanceView.topAnchor
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: SettingsWindow.contentWidth),
            leftColumn.widthAnchor.constraint(equalToConstant: appearanceControlsWidth),
            leftColumn.topAnchor.constraint(equalTo: view.topAnchor),
            leftColumn.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            leftColumn.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previewPane.leadingAnchor.constraint(equalTo: leftColumn.trailingAnchor, constant: AppearanceStylePreviewPane.splitSpacing),
            previewPane.topAnchor.constraint(equalTo: previewTopAnchor),
            previewPane.bottomAnchor.constraint(equalTo: leftColumn.bottomAnchor),
        ])
        return view
    }

    private static func makeAppearanceControlsView(_ previewPane: AppearanceStylePreviewPane) -> TableGroupView {
        let table = TableGroupView(width: appearanceControlsWidth)
        let styleControl = makeStyleSegmentedControl(previewPane)
        table.addRow(leftText: NSLocalizedString("Style", comment: ""), rightViews: [styleControl])
        table.addRow(leftText: AppearanceTab.labelSize, rightViews: [
            makeGlobalDropdown("appearanceSize", overrideBaseName: "appearanceSizeOverride",
                cases: AppearanceSizePreference.allCases, extraAction: previewPane.refreshAppearance)
        ])
        table.addRow(leftText: AppearanceTab.labelTheme,
            rightViews: [makeGlobalDropdown("appearanceTheme", overrideBaseName: "appearanceThemeOverride",
                cases: AppearanceThemePreference.allCases, extraAction: previewPane.refreshAppearance)])
        addAfterKeysReleasedRow(table)
        table.addRow(rightViews: customizeStyleButton)
        return table
    }

    private static func makeStyleSegmentedControl(_ previewPane: AppearanceStylePreviewPane) -> NSSegmentedControl {
        let control = LabelAndControl.makeSegmentedControl("appearanceStyle", AppearanceStylePreference.allCases,
            segmentWidth: styleSegmentWidth)
        control.onAction = { control in
            let previousValue = UserDefaults.standard.string(forKey: "appearanceStyle")
            let newValue = LabelAndControl.getControlValue(control, nil)
            LabelAndControl.controlWasChanged(control, nil)
            updatePreview(previewPane, newValue)
            let decision = resolveGlobalChange(previousValue: previousValue, newValue: newValue,
                overrideBaseName: "appearanceStyleOverride")
            guard decision != .skip else { return }
            toggleCustomizeStyleButton()
            confirmOverrideResetIfNeeded(decision, overrideBaseName: "appearanceStyleOverride")
        }
        return control
    }

    private static func updatePreview(_ previewPane: AppearanceStylePreviewPane, _ newValue: String?) {
        guard let raw = newValue, let index = Int(raw), AppearanceStylePreference.allCases.indices.contains(index) else { return }
        previewPane.updateStyle(AppearanceStylePreference.allCases[index])
    }

    private static func addAfterKeysReleasedRow(_ table: TableGroupView) {
        let control = makeGlobalDropdown("shortcutStyle", overrideBaseName: "shortcutStyleOverride",
            cases: ShortcutStylePreference.allCases)
        table.addRow(leftText: AppearanceTab.labelShortcutStyle,
            rightViews: [control])
    }

    private static func makeGlobalDropdown(_ rawName: String,
                                           overrideBaseName: String,
                                           cases: [MacroPreference],
                                           extraAction: (() -> Void)? = nil) -> NSPopUpButton {
        let control = LabelAndControl.makeDropdown(rawName, cases)
        control.onAction = { control in
            let previousValue = UserDefaults.standard.string(forKey: rawName)
            let newValue = LabelAndControl.getControlValue(control, nil)
            LabelAndControl.controlWasChanged(control, nil)
            extraAction?()
            let decision = resolveGlobalChange(previousValue: previousValue, newValue: newValue,
                overrideBaseName: overrideBaseName)
            confirmOverrideResetIfNeeded(decision, overrideBaseName: overrideBaseName)
        }
        return control
    }

    private static func resolveGlobalChange(previousValue: String?,
                                            newValue: String?,
                                            overrideBaseName: String) -> GlobalAppearanceChangeDecision {
        GlobalAppearanceChangeResolver.decide(
            previousValue: previousValue,
            newValue: newValue,
            hasExplicitOverrides: Preferences.hasAnyOverride(overrideBaseName),
            rememberedOverrideChoice: Preferences.appearanceOverrideResetChoice)
    }

    private static func confirmOverrideResetIfNeeded(_ decision: GlobalAppearanceChangeDecision,
                                                     overrideBaseName: String) {
        switch decision {
            case .skip, .applyWithoutConfirmation:
                return
            case let .applyRememberedOverrideChoice(removesOverrides):
                if removesOverrides { Preferences.removeAllOverrides(overrideBaseName) }
            case .confirmOverrideReset:
                promptOverrideReset(overrideBaseName)
        }
    }

    private static func promptOverrideReset(_ overrideBaseName: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Apply this change to all shortcuts?", comment: "")
        alert.informativeText = NSLocalizedString("Some shortcuts override this setting. Apply the new global value to every shortcut by removing those overrides, or keep the overrides.", comment: "")
        let globalOnlyButton = alert.addButton(withTitle: NSLocalizedString("Change Global Only", comment: ""))
        globalOnlyButton.setAccessibilityFocused(true)
        globalOnlyButton.keyEquivalent = "\u{1b}"
        let applyAllButton = alert.addButton(withTitle: NSLocalizedString("Apply to All Shortcuts", comment: ""))
        if #available(macOS 11.0, *) { applyAllButton.hasDestructiveAction = true }
        alert.showsSuppressionButton = true
        let removesOverrides = alert.runModal() == .alertSecondButtonReturn
        if alert.suppressionButton?.state == .on {
            Preferences.rememberAppearanceOverrideResetChoice(removesOverrides: removesOverrides)
        }
        guard removesOverrides else { return }
        Preferences.removeAllOverrides(overrideBaseName)
    }

    private static func makeMultipleScreensView() -> NSView {
        let table = TableGroupView(title: NSLocalizedString("Multiple screens", comment: ""), width: appearanceControlsWidth)
        _ = table.addRow(leftText: NSLocalizedString("Show on", comment: ""),
            rightViews: LabelAndControl.makeDropdown("showOnScreen", ShowOnScreenPreference.allCases))
        return table
    }

    fileprivate static func selectedAppearanceStyle() -> AppearanceStylePreference {
        let index = CachedUserDefaults.intFromMacroPref("appearanceStyle", AppearanceStylePreference.allCases)
        guard AppearanceStylePreference.allCases.indices.contains(index) else { return .appIcons }
        return AppearanceStylePreference.allCases[index]
    }

    fileprivate static func selectedAppearanceSize() -> AppearanceSizePreference {
        let index = CachedUserDefaults.intFromMacroPref("appearanceSize", AppearanceSizePreference.allCases)
        guard AppearanceSizePreference.allCases.indices.contains(index) else { return .medium }
        return AppearanceSizePreference.allCases[index]
    }

    fileprivate static func selectedAppearanceTheme() -> AppearanceThemePreference {
        let index = CachedUserDefaults.intFromMacroPref("appearanceTheme", AppearanceThemePreference.allCases)
        guard AppearanceThemePreference.allCases.indices.contains(index) else { return .system }
        return AppearanceThemePreference.allCases[index]
    }

    private static func getCustomizeStyleButtonTitle() -> String {
        return NSLocalizedString("Customize more…", comment: "")
    }

    @objc static func toggleCustomizeStyleButton() {
        // Recreate the sheet so the next open rebuilds with current style preference baked in.
        // (This is the "appearance style changed → reset the customize sheet" path.)
        customizeStyleSheet = CustomizeStyleSheet()
    }

    @objc static func showCustomizeStyleSheet() {
        if customizeStyleSheet == nil { customizeStyleSheet = CustomizeStyleSheet() }
        SettingsWindow.shared.beginSheetWithSearchHighlight(customizeStyleSheet)
    }

}
