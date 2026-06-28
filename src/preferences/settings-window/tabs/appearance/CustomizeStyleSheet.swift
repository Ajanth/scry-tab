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
        layer?.borderColor = isFocused ? NSColor.systemAccentColor.cgColor : NSColor.lightGray.cgColor
        layer?.borderWidth = 3
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



class CustomizeStyleSheet: SheetWindow {
    // Local labels (rows owned by this sheet). The Show/Hide rows below are sourced from
    // `ShowHideIllustratedView`'s static constants so each NSLocalizedString call lives in
    // exactly one place across the codebase.
    private static let labelShowTitles = NSLocalizedString("Show titles", comment: "")
    private static let labelTitleTruncation = NSLocalizedString("Title truncation", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        labelShowTitles,
        labelTitleTruncation,
        ShowHideIllustratedView.hideStatusIconsLabel,
        ShowHideIllustratedView.hideStatusIconsSubtitle,
        ShowHideIllustratedView.hideSpaceNumberLabelsLabel,
        IllustratedImageThemeView.placeholderLabelText,
    ] + ShowTitlesPreference.allCases.map { $0.localizedString }
      + TitleTruncationPreference.allCases.map { $0.localizedString }

    static let illustratedImageWidth = width

    let style = Preferences.appearanceStyle
    var illustratedImageView: IllustratedImageThemeView!
    var showHideIllustratedView: ShowHideIllustratedView!

    override func makeContentView() -> NSView {
        // The per-shortcut Customize sheet was trimmed to just style-tied global toggles. The
        // settings that used to live here either (a) moved to per-shortcut storage and now live
        // in `ControlsTab` (`showAppsOrWindows`, `showTabsAsWindows`) or (b) were dropped
        // entirely. The "Show & Hide" / "Advanced" tab control is gone too —
        // the remaining rows fit comfortably in one flat list.
        illustratedImageView = IllustratedImageThemeView(style, CustomizeStyleSheet.illustratedImageWidth)
        showHideIllustratedView = ShowHideIllustratedView(style, illustratedImageView)
        let showHideView = showHideIllustratedView.makeView()
        let advancedTable = TableGroupView(width: CustomizeStyleSheet.width)
        let showTitles = TableGroupView.Row(leftTitle: Self.labelShowTitles,
            rightViews: [LabelAndControl.makeDropdown(
                "showTitles", ShowTitlesPreference.allCases, extraAction: { [weak self] _ in
                    self?.showTitlesIllustratedImage()
                })])
        advancedTable.addRow(showTitles, onMouseEntered: { [weak self] _, _ in
            self?.showTitlesIllustratedImage()
        })
        let titleTruncation = TableGroupView.Row(leftTitle: Self.labelTitleTruncation,
            rightViews: LabelAndControl.makeRadioButtons("titleTruncation", TitleTruncationPreference.allCases))
        advancedTable.addRow(titleTruncation)
        advancedTable.onMouseExited = { [weak self] event, view in
            guard let self else { return }
            IllustratedImageThemeView.resetImage(self.illustratedImageView, event, view)
        }
        let advancedView = TableGroupSetView(originalViews: [advancedTable], padding: 0)
        return TableGroupSetView(originalViews: [illustratedImageView, showHideView, advancedView], padding: 0)
    }

    private func showTitlesIllustratedImage() {
        illustratedImageView.highlight(true, Preferences.showTitles.image.name)
    }
}
