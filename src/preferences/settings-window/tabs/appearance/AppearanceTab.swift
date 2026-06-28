import Cocoa

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
    static let labelApparitionDelay = NSLocalizedString("Apparition delay of Switcher", comment: "")
    static let labelFadeOut = NSLocalizedString("Fade out animation of Switcher", comment: "")
    /// Pre-build search strings for the inline Motion section (moved out of `AnimationsSheet`).
    static let motionSearchableStrings: [String] = [labelApparitionDelay, labelFadeOut]

    static var customizeStyleButton: NSButton!
    static var customizeStyleSheet: CustomizeStyleSheet!

    /// One icon button per overridable preference, parked at the trailing edge of each row (same
    /// position as the "unlink" icon in the per-shortcut Appearance section in `ControlsTab`).
    /// Hidden when no shortcut overrides the global. Tooltip on hover lists the overriding
    /// shortcut numbers; click navigates to the first one's Appearance pane in `ControlsTab`.
    private static var overrideInfoIcons = [String: NSButton]()

    static func initTab() -> NSView {
        customizeStyleButton = NSButton(title: getCustomizeStyleButtonTitle(), target: self, action: #selector(showCustomizeStyleSheet))
        // The customize sheet is constructed lazily on first show. Motion controls were moved
        // inline for routed Settings, so search can target them without opening a sheet.
        let form = SettingsFormView()
        form.addSection(applicationInterfaceSection())
        form.addSection(switcherStyleSection())
        form.addSection(layoutAndBehaviorSection())
        form.addSection(motionSection())
        refreshAllOverrideInfoLabels()
        return form
    }

    static func cleanup() {
        // Don't call .close() — NSWindow's default `isReleasedWhenClosed = true` interacts
        // badly with our manual nil-out and causes double-release. ARC reclaims the sheet
        // when the static ref is nilled.
        customizeStyleButton = nil
        customizeStyleSheet = nil
        overrideInfoIcons.removeAll()
        SettingsFocusRegistry.shared.unregisterPrefix("appearance-")
    }

    private static func applicationInterfaceSection() -> SettingsSectionView {
        let section = SettingsSectionView(title: NSLocalizedString("Application interface", comment: ""))
        if #available(macOS 10.14, *) {
            let dropdown = PopupButtonLikeSystemSettings()
            let cases = ApplicationInterfaceAppearancePreference.allCases
            dropdown.addItems(withTitles: cases.map { $0.localizedString })
            dropdown.selectItem(at: cases.firstIndex(of: Preferences.applicationInterfaceAppearance) ?? 0)
            SettingsSearchIndex.registerStrings(cases.map { $0.localizedString })
            SettingsSearchIndex.registerTarget(SettingsWindow.highlightTarget(dropdown))
            let row = SettingsRowView(title: NSLocalizedString("Appearance", comment: ""), subtitle: NSLocalizedString("Choose the Appearance of Settings and secondary windows. The switcher follows its own theme.", comment: ""), content: [LabelAndControl.setupControl(dropdown, "applicationInterfaceAppearance")])
            row.registerFocusAnchor("appearance-applicationInterface", focalControl: dropdown)
            section.addRow(row)
        }
        return section
    }

    private static func switcherStyleSection() -> SettingsSectionView {
        let section = SettingsSectionView(title: NSLocalizedString("Switcher style", comment: ""), footer: NSLocalizedString("Switch between 2 different styles. You can customize them.", comment: ""))
        let styleButtons = LabelAndControl.makeImageRadioButtons("appearanceStyle", AppearanceStylePreference.allCases, extraAction: { _ in
            toggleCustomizeStyleButton()
            ControlsTab.syncOverrideControlsToGlobal()
            refreshAllOverrideInfoLabels()
        }, buttonSpacing: 10)
        let styleOverrideIcon = makeOverrideIcon("appearanceStyleOverride")
        let styleRow = NSStackView(views: [styleButtons, styleOverrideIcon])
        styleRow.orientation = .horizontal
        styleRow.alignment = .centerY
        let styleRowView = SettingsRowView(title: NSLocalizedString("Style", comment: ""), content: [styleRow])
        styleRowView.registerFocusAnchor("appearance-style")
        section.addRow(styleRowView)
        let customizeRow = SettingsRowView(title: NSLocalizedString("Customize", comment: ""), content: [customizeStyleButton])
        customizeRow.registerFocusAnchor("appearance-customize", focalControl: customizeStyleButton)
        section.addRow(customizeRow)
        return section
    }

    private static func layoutAndBehaviorSection() -> SettingsSectionView {
        let section = SettingsSectionView(title: NSLocalizedString("Layout and behavior", comment: ""))
        let sizeControl = LabelAndControl.makeSegmentedControl("appearanceSize", AppearanceSizePreference.allCases, segmentWidth: 105, extraAction: { _ in
            ControlsTab.syncOverrideControlsToGlobal()
            refreshAllOverrideInfoLabels()
        })
        let sizeRow = SettingsRowView(title: labelSize, content: [sizeControl, makeOverrideIcon("appearanceSizeOverride")])
        sizeRow.registerFocusAnchor("appearance-size", focalControl: sizeControl)
        section.addRow(sizeRow)
        let themeControl = LabelAndControl.makeSegmentedControl("appearanceTheme", AppearanceThemePreference.allCases, segmentWidth: 105, extraAction: { _ in
            ControlsTab.syncOverrideControlsToGlobal()
            refreshAllOverrideInfoLabels()
        })
        let themeRow = SettingsRowView(title: labelTheme, content: [themeControl, makeOverrideIcon("appearanceThemeOverride")])
        themeRow.registerFocusAnchor("appearance-theme", focalControl: themeControl)
        section.addRow(themeRow)
        let shortcutStyleControl = LabelAndControl.makeSegmentedControl("shortcutStyle", ShortcutStylePreference.allCases, segmentWidth: 105, extraAction: { _ in
            ControlsTab.syncOverrideControlsToGlobal()
            refreshAllOverrideInfoLabels()
        })
        let shortcutStyleRow = SettingsRowView(title: labelShortcutStyle, content: [shortcutStyleControl, makeOverrideIcon("shortcutStyleOverride")])
        shortcutStyleRow.registerFocusAnchor("appearance-shortcutStyle", focalControl: shortcutStyleControl)
        section.addRow(shortcutStyleRow)
        let showOnDropdown = LabelAndControl.makeDropdown("showOnScreen", ShowOnScreenPreference.allCases)
        let showOnRow = SettingsRowView(title: NSLocalizedString("Show on", comment: ""), content: [showOnDropdown])
        showOnRow.registerFocusAnchor("appearance-showOn", focalControl: showOnDropdown)
        section.addRow(showOnRow)
        return section
    }

    private static func motionSection() -> SettingsSectionView {
        let section = SettingsSectionView(title: NSLocalizedString("Motion", comment: ""))
        let apparitionRow = makeApparitionDelayRow()
        apparitionRow.registerFocusAnchor("appearance-apparitionDelay")
        section.addRow(apparitionRow)
        let fadeSwitch = LabelAndControl.makeSwitch("fadeOutAnimation")
        let fadeRow = SettingsRowView(title: labelFadeOut, content: [fadeSwitch])
        fadeRow.registerFocusAnchor("appearance-fadeOut", focalControl: fadeSwitch)
        section.addRow(fadeRow)
        return section
    }

    private static func makeApparitionDelayRow() -> SettingsRowView {
        let value = CachedUserDefaults.int("windowDisplayDelay")
        let formatter = MeasurementFormatter()
        formatter.numberFormatter = NumberFormatter()
        let suffix = NSTextField(labelWithString: formatter.string(from: Measurement(value: Double(value), unit: Unit(symbol: "ms"))))
        suffix.identifier = NSUserInterfaceItemIdentifier("windowDisplayDelay" + ControlIdentifierDiscriminator.SUFFIX.rawValue)
        suffix.textColor = .secondaryLabelColor
        let slider = NSSlider()
        slider.minValue = 0
        slider.maxValue = 900
        slider.stringValue = String(value)
        slider.isContinuous = true
        slider.numberOfTickMarks = 19
        slider.allowsTickMarkValuesOnly = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        _ = LabelAndControl.setupControl(slider, "windowDisplayDelay")
        return SettingsRowView(title: labelApparitionDelay, content: [slider, suffix])
    }

    /// Build the override-indicator icon button parked at the trailing edge of each global row.
    /// Visible iff at least one shortcut overrides this global. Tooltip lists the overriding
    /// shortcut numbers; click navigates to the first overriding shortcut's Appearance pane in
    /// `ControlsTab` (same behaviour the previous text-link version had).
    private static func makeOverrideIcon(_ overrideBaseName: String) -> NSButton {
        // `arrow.triangle.branch` rotated 180° — reads as "this value has branches going
        // downward to other shortcuts". Visually distinct from the chain-link unlink button.
        let image = NSImage.fromSymbol(.arrowTriangleBranch, pointSize: 14, rotated180: true)
        let button = NSButton(image: image, target: self, action: #selector(overrideInfoClicked(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(overrideBaseName)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        if #available(macOS 10.14, *) {
            button.contentTintColor = .controlAccentColor
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 20).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20).isActive = true
        button.isHidden = true
        overrideInfoIcons[overrideBaseName] = button
        return button
    }

    private static func refreshOverrideInfoIcon(_ overrideBaseName: String, _ globalKey: String) {
        guard let icon = overrideInfoIcons[overrideBaseName] else { return }
        let indices = Preferences.shortcutIndicesWithDifferentValue(overrideBaseName, globalKey: globalKey)
        if indices.isEmpty {
            icon.isHidden = true
            icon.toolTip = nil
        } else {
            let numbers = indices.map { String($0 + 1) }.joined(separator: ", ")
            icon.toolTip = NSLocalizedString("Overridden in Shortcut:", comment: "") + " " + numbers
            icon.tag = indices[0]
            icon.isHidden = false
        }
    }

    /// Refresh every override-indicator icon's visibility + tooltip. Wrapped in
    /// `preserveScrollPosition` since toggling icon visibility can change the row's measured
    /// width and otherwise nudge the user's scroll position. During the initial build the window
    /// singleton isn't assigned yet (`init` sets `SettingsWindow.shared` only after `setupView`
    /// returns), so we still run the refresh — just without scroll preservation, which isn't
    /// needed before the window is on-screen anyway.
    static func refreshAllOverrideInfoLabels() {
        let refresh = {
            for (overrideBaseName, globalKey) in Preferences.overrideToGlobalKey {
                refreshOverrideInfoIcon(overrideBaseName, globalKey)
            }
        }
        if let window = SettingsWindow.shared {
            window.preserveScrollPosition(during: refresh)
        } else {
            refresh()
        }
    }

    @objc static func overrideInfoClicked(_ sender: NSButton) {
        let id = Preferences.shortcutIdentifier(at: sender.tag)
        SettingsWindow.shared?.navigate(to: .controls(.shortcut(id: id, pane: .appearance)))
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
