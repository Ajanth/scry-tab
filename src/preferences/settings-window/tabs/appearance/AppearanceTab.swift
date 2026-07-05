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
    var style: AppearanceStylePreference!
    var theme: String!
    var imageName: String!
    var isFocused: Bool = false
    private var placeholderLabel: NSTextField!

    /// Loads an illustration from the bundle without going through `NSImage(named:)`'s global
    /// named cache (which never releases). Pairs with `cacheMode = .never` so the per-image scaled
    /// bitmap cache is also disabled. Lets ARC reclaim the bitmap when no view holds the image.
    static func loadIllustration(_ name: String) -> NSImage? {
        guard let path = Bundle.main.path(forResource: "\(name)@2x", ofType: "heic") else { return nil }
        let image = NSImage(contentsOfFile: path)
        image?.cacheMode = .never
        return image
    }

    init(_ style: AppearanceStylePreference, _ width: CGFloat) {
        // TODO: The appearance theme functionality has not been implemented yet.
        // We will implement it later; for now, use the light theme.
        let theme = "light"
        let imageName = IllustratedImageThemeView.getConcatenatedImageName(style, theme)
        let imageView = NSImageView(image: IllustratedImageThemeView.loadIllustration(imageName)!)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer!.masksToBounds = true
        imageView.layer!.cornerRadius = TableGroupView.cornerRadius
        super.init(infoCircle: imageView)
        self.style = style
        self.theme = theme
        self.imageName = imageName
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
        onClick = { (event, view) in
            self.highlight(false)
        }
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
        if highlighted {
            updateImage(imageName)
        } else {
            (infoCircle as! NSImageView).image = IllustratedImageThemeView.loadIllustration(self.imageName)
        }
    }

    func showPlaceholder() {
        setFocused(true)
        setBorder()
        infoCircle.isHidden = true
        placeholderLabel.isHidden = false
    }

    private func updateImage(_ imageName: String) {
        (infoCircle as! NSImageView).image = IllustratedImageThemeView.loadIllustration(getStyleThemeImageName(imageName))
    }

    static func getConcatenatedImageName(_ style: AppearanceStylePreference,
                                         _ theme: String,
                                         _ imageName: String = "") -> String {
        if imageName.isEmpty {
            // app_icons_light/titles_dark
            return style.image.name + "_" + theme
        }
        // app_icons_hide_colored_circles_light/titles_show_status_icons_light
        return style.image.name + "_" + imageName + "_" + theme
    }

    func getStyleThemeImageName(_ imageName: String = "") -> String {
        return IllustratedImageThemeView.getConcatenatedImageName(style, theme, imageName)
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

    func makeView() -> TableGroupSetView {
        table = TableGroupView(width: CustomizeStyleSheet.width)
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
        return TableGroupSetView(originalViews: [table], padding: 0)
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
        let actualView: NSView = extraView == nil ? label : StackView([label, extraView!], .vertical)
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
    static var animationsButton: NSButton!
    static var customizeStyleSheet: CustomizeStyleSheet!
    static var animationsSheet: AnimationsSheet!

    static func initTab() -> NSView {
        customizeStyleButton = DesignSystemControlStyler.makeButton(getCustomizeStyleButtonTitle(), target: self, action: #selector(showCustomizeStyleSheet))
        // The customize sheet is constructed lazily on first show. Animation controls were moved
        // inline for routed Settings, so search can target them without opening a sheet.
        return makeView()
    }

    static func cleanup() {
        // Don't call .close() — NSWindow's default `isReleasedWhenClosed = true` interacts
        // badly with our manual nil-out and causes double-release. ARC reclaims the sheet
        // when the static ref is nilled.
        customizeStyleButton = nil
        animationsButton = nil
        customizeStyleSheet = nil
        animationsSheet = nil
    }

    private static func makeView() -> NSStackView {
        let appearanceView = makeAppearanceView()
        let multipleScreensView = makeMultipleScreensView()
        let motionView = AnimationsSheet.makeContentView(width: SettingsWindow.contentWidth)
        // `padding: 0` — `TableGroupSetView` adds 20pt of horizontal inset by default before its
        // inner content stack. The enclosing section (from `SettingsWindow.addSection`) already
        // provides the section's left margin via `contentHorizontalPadding`, so adding another
        // 20pt here pushes the TGV content to `container.leading + 20`, while the section title
        // sits at `container.leading + TableGroupView.padding(10)` — a 10pt visible misalignment
        // between the title and the row content below it.
        let view = TableGroupSetView(originalViews: [appearanceView, multipleScreensView, motionView], titleTableGroupSpacing: 15, padding: 0, bottomPadding: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: view.fittingSize.width).isActive = true
        return view
    }

    private static func makeAppearanceView() -> NSView {
        let table = TableGroupView(subTitle: NSLocalizedString("Switch between 2 different styles. You can customize them.", comment: ""),
            width: SettingsWindow.contentWidth)
        let styleButtons = LabelAndControl.makeImageRadioButtons(
            "appearanceStyle", AppearanceStylePreference.allCases, buttonSpacing: 10)
        configureGlobalStyleActions(styleButtons)
        configureStyleButtons(styleButtons)
        table.addRow(secondaryViews: [styleButtons], secondaryViewsAlignment: .centerX, secondaryViewsTopGap: 6)
        let sizeControl = makeGlobalSegmentedControl("appearanceSize", overrideBaseName: "appearanceSizeOverride",
            cases: AppearanceSizePreference.allCases, segmentWidth: 105)
        table.addRow(leftText: AppearanceTab.labelSize,
            rightViews: [sizeControl])
        table.addRow(leftText: AppearanceTab.labelTheme,
            rightViews: [makeGlobalSegmentedControl("appearanceTheme", overrideBaseName: "appearanceThemeOverride",
                cases: AppearanceThemePreference.allCases, segmentWidth: 105)])
        addAfterKeysReleasedRow(table)
        table.addRow(rightViews: customizeStyleButton)
        return table
    }

    private static func configureGlobalStyleActions(_ styleButtons: NSStackView) {
        let buttonViews = styleButtons.arrangedSubviews.compactMap { $0 as? ImageTextButtonView }
        buttonViews.enumerated().forEach { index, buttonView in
            buttonView.onClick = { [weak buttonView] _ in
                guard let buttonView else { return }
                let previousValue = UserDefaults.standard.string(forKey: "appearanceStyle")
                let siblings = (buttonView.superview as? NSStackView)?.arrangedSubviews.compactMap {
                    $0 as? ImageTextButtonView
                } ?? []
                siblings.forEach { $0.state = $0 === buttonView ? .on : .off }
                LabelAndControl.controlWasChanged(buttonView.button, String(index))
                let newValue = String(index)
                let decision = resolveGlobalChange(previousValue: previousValue, newValue: newValue,
                    overrideBaseName: "appearanceStyleOverride")
                guard decision != .skip else { return }
                toggleCustomizeStyleButton()
                confirmOverrideResetIfNeeded(decision, overrideBaseName: "appearanceStyleOverride")
            }
        }
    }

    private static func configureStyleButtons(_ styleButtons: NSStackView) {
        styleButtons.spacing = 12
        styleButtons.alignment = .top
        styleButtons.setContentCompressionResistancePriority(.required, for: .horizontal)
        styleButtons.arrangedSubviews.compactMap {
            $0 as? ImageTextButtonView
        }.forEach {
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
    }

    private static func addAfterKeysReleasedRow(_ table: TableGroupView) {
        let control = makeGlobalSegmentedControl("shortcutStyle", overrideBaseName: "shortcutStyleOverride",
            cases: ShortcutStylePreference.allCases, segmentWidth: 105)
        table.addRow(leftText: AppearanceTab.labelShortcutStyle,
            rightViews: [control])
    }

    private static func makeGlobalSegmentedControl(_ rawName: String,
                                                   overrideBaseName: String,
                                                   cases: [MacroPreference],
                                                   segmentWidth: CGFloat) -> NSSegmentedControl {
        let control = LabelAndControl.makeSegmentedControl(rawName, cases, segmentWidth: segmentWidth)
        control.onAction = { control in
            let previousValue = UserDefaults.standard.string(forKey: rawName)
            let newValue = LabelAndControl.getControlValue(control, nil)
            LabelAndControl.controlWasChanged(control, nil)
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
            hasExplicitOverrides: Preferences.hasAnyOverride(overrideBaseName))
    }

    private static func confirmOverrideResetIfNeeded(_ decision: GlobalAppearanceChangeDecision,
                                                     overrideBaseName: String) {
        guard decision == .confirmOverrideReset else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Apply this change to all shortcuts?", comment: "")
        alert.informativeText = NSLocalizedString("Some shortcuts override this setting. Apply the new global value to every shortcut by removing those overrides, or keep the overrides.", comment: "")
        let globalOnlyButton = alert.addButton(withTitle: NSLocalizedString("Change Global Only", comment: ""))
        globalOnlyButton.setAccessibilityFocused(true)
        globalOnlyButton.keyEquivalent = "\u{1b}"
        let applyAllButton = alert.addButton(withTitle: NSLocalizedString("Apply to All Shortcuts", comment: ""))
        if #available(macOS 11.0, *) { applyAllButton.hasDestructiveAction = true }
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        Preferences.removeAllOverrides(overrideBaseName)
    }

    private static func makeMultipleScreensView() -> NSView {
        let table = TableGroupView(title: NSLocalizedString("Multiple screens", comment: ""), width: SettingsWindow.contentWidth)
        _ = table.addRow(leftText: NSLocalizedString("Show on", comment: ""),
            rightViews: LabelAndControl.makeDropdown("showOnScreen", ShowOnScreenPreference.allCases))
        return table
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

    @objc static func showAnimationsSheet() {
        if animationsSheet == nil { animationsSheet = AnimationsSheet() }
        SettingsWindow.shared.beginSheetWithSearchHighlight(animationsSheet)
    }

}
