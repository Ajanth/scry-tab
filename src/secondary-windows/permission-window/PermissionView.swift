import Cocoa

class PermissionView: StackView {
    var status: NSTextField!
    var permissionStatus = PermissionStatus.notGranted

    convenience init(_ symbol: Symbols, _ title: String, _ justification: String, _ buttonText: String, _ buttonUrl: String) {
        let iconImage = NSImage.fromSymbol(symbol, pointSize: 28)
        let icon = NSImageView(image: iconImage)
        if #available(macOS 10.14, *) { icon.contentTintColor = .systemBlue }
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.fit(iconImage.size.width * 0.75, iconImage.size.height * 0.75)
        let title = BoldLabel(title)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.fit()
        let titleStack = NSStackView(views: [icon, title])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.alignment = .centerY
        titleStack.spacing = GridView.interPadding
        titleStack.fit()
        let justification = NSTextField(wrappingLabelWithString: justification)
        justification.translatesAutoresizingMaskIntoConstraints = false
        justification.preferredMaxLayoutWidth = 500
        justification.addOrUpdateConstraint(justification.widthAnchor, justification.fittingSize.width + 5)
        let button = Button(buttonText) { _ in NSWorkspace.shared.open(URL(string: buttonUrl)!) }
        DesignSystemControlStyler.styleButton(button)
        let status = NSTextField(wrappingLabelWithString: "")
        status.translatesAutoresizingMaskIntoConstraints = false
        let buttonStack = NSStackView(views: [button, status])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.alignment = .centerY
        let views = [titleStack, justification, buttonStack]
        self.init(views, .vertical, top: GridView.interPadding, right: GridView.interPadding, bottom: GridView.interPadding, left: GridView.interPadding)
        self.status = status
        wantsLayer = true
        layer?.cornerRadius = DesignSystem.Metrics.sectionRadius
        layer?.borderWidth = 1
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        refreshStyle()
    }

    func updatePermissionStatus(_ permissionStatus: PermissionStatus) {
        guard status.stringValue.isEmpty || permissionStatus != self.permissionStatus else { return }
        self.permissionStatus = permissionStatus
        let label = permissionStatus == .granted ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("Not allowed", comment: "")
        status.stringValue = "● " + label
        refreshStyle()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshStyle()
    }

    private func refreshStyle() {
        let role: DesignSystem.ColorRole = permissionStatus == .granted ? .statusSuccess : .statusDestructive
        let statusColor = DesignSystem.color(role, appearance: effectiveAppearance)
        status.textColor = statusColor
        layer?.backgroundColor = DesignSystem.resolvedCGColor(statusColor.withAlphaComponent(statusFillAlpha()), in: self)
        layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: self)
    }

    private func statusFillAlpha() -> CGFloat {
        return DesignSystem.isDark(effectiveAppearance) ? 0.20 : 0.12
    }
}

enum PermissionStatus {
    case granted
    case notGranted
}
