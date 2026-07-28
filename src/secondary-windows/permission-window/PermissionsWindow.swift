import Cocoa

class PermissionsWindow: NSWindow {
    static var accessibilityView: PermissionView!
    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }
    static var shared: PermissionsWindow!
    private var enableButton: NSButton!
    private var cancelButton: NSButton!

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        delegate = self
        setupWindow()
        setupView()
        setFrameAutosaveNameSafely("PermissionsWindow")
        Self.shared = self
    }

    static func updatePermissionViews() {
        let status = AccessibilityPermission.status
        accessibilityView.updatePermissionStatus(status)
        if status == .granted {
            AccessibilitySettingsGuide.shared.dismiss()
        }
    }

    static func show() {
        guard !Self.shared.isVisible else { return }
        Logger.debug { "" }
        Self.shared.center()
        App.shared.activate(ignoringOtherApps: true)
        Self.shared.makeKeyAndOrderFront(nil)
        SystemPermissions.setFrequentTimer()
    }

    private func setupWindow() {
        title = NSLocalizedString("ScryTab needs accessibility permission", comment: "")
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        styleMask.insert([.closable])
    }

    private func setupView() {
        let header = makeHeader()
        Self.accessibilityView = PermissionView(
            title: NSLocalizedString("Accessibility", comment: ""),
            symbol: .accessibility)
        Self.accessibilityView.updatePermissionStatus(AccessibilityPermission.status)
        let statusSection = makeStatusSection(Self.accessibilityView)
        let note = makeBuildNote()
        let divider = DesignSystemDividerView()
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let footer = makeFooter()
        let root = NSStackView(views: [header, statusSection, note, divider, footer])
        root.translatesAutoresizingMaskIntoConstraints = false
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = DesignSystem.Metrics.sectionGap
        root.edgeInsets = NSEdgeInsets(
            top: GridView.padding,
            left: GridView.padding,
            bottom: GridView.padding,
            right: GridView.padding)
        let contentWidth = CGFloat(396)
        [header, statusSection, note, divider, footer].forEach {
            $0.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        }
        root.setCustomSpacing(DesignSystem.Metrics.headerFooterGap, after: note)
        root.setCustomSpacing(DesignSystem.Metrics.formOuterPadding, after: divider)
        let container = DesignSystemWindowContentView(content: root, topPadding: 10)
        contentView = container
        setContentSize(container.fittingSize)
        cancelButton.nextKeyView = enableButton
        enableButton.nextKeyView = cancelButton
    }

    private func makeHeader() -> NSView {
        let appIcon = LightImageView()
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        let iconSize = NSSize(width: 48, height: 48)
        appIcon.updateContents(.cgImage(App.appIcon(for: iconSize)), iconSize)
        appIcon.fit(iconSize.width, iconSize.height)
        let title = BoldLabel(NSLocalizedString("ScryTab needs accessibility permission", comment: ""))
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: NSLocalizedString(
            "ScryTab uses Accessibility to focus windows after you release the shortcut.",
            comment: ""))
        subtitle.textColor = .secondaryLabelColor
        subtitle.preferredMaxLayoutWidth = 340
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

    private func makeStatusSection(_ statusRow: NSView) -> NSView {
        let label = NSTextField(labelWithString: NSLocalizedString("Permission", comment: ""))
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        let section = NSStackView(views: [label, statusRow])
        section.translatesAutoresizingMaskIntoConstraints = false
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = DesignSystem.Metrics.headerFooterGap
        statusRow.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private func makeBuildNote() -> NSTextField {
        let note = NSTextField(wrappingLabelWithString: String(
            format: NSLocalizedString(
                "Enable the “%@” row that matches this app’s icon. An older ScryTab entry from another build or certificate does not count.",
                comment: ""),
            App.displayName))
        note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        return note
    }

    private func makeFooter() -> NSView {
        cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        DesignSystemControlStyler.styleButton(cancelButton)
        enableButton = NSButton(
            title: NSLocalizedString("Enable Accessibility…", comment: ""),
            target: self,
            action: #selector(enableAccessibility))
        enableButton.keyEquivalent = "\r"
        DesignSystemControlStyler.styleButton(enableButton)
        if #available(macOS 10.14, *) {
            enableButton.bezelColor = .controlAccentColor
        }
        let actions = NSStackView(views: [cancelButton, enableButton])
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.alignment = .centerY
        actions.spacing = TableGroupView.toolRowSpacing
        let footer = NSStackView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.addView(actions, in: .trailing)
        return footer
    }

    @objc private func cancel(_ sender: Any?) {
        close()
    }

    @objc private func enableAccessibility(_ sender: Any?) {
        AccessibilitySettingsGuide.shared.begin(sourceFrameInScreen: enableButtonScreenFrame())
    }

    private func enableButtonScreenFrame() -> CGRect? {
        guard let window = enableButton.window else { return nil }
        return window.convertToScreen(enableButton.convert(enableButton.bounds, to: nil))
    }

    override func close() {
        AccessibilitySettingsGuide.shared.dismiss()
        hideAppIfLastWindowIsClosed()
        super.close()
    }
}


extension PermissionsWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Logger.debug { "preStartupPermissionsPassed:\(SystemPermissions.preStartupPermissionsPassed), accessibility:\(AccessibilityPermission.status)" }
        if !SystemPermissions.preStartupPermissionsPassed {
            if AccessibilityPermission.status == .notGranted {
                Logger.error {
                    """
                    Before using this app, you need to give permission in System Settings > Privacy & Security > Accessibility.
                    Please authorize and re-launch.
                    See https://help.rescuetime.com/article/59-how-do-i-enable-accessibility-permissions-on-mac-osx
                    """
                }
                AccessibilitySettingsGuide.shared.dismiss()
                App.shared.terminate(self)
                return false
            }
        }
        return true
    }
}
