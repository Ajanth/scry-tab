import Cocoa

class PermissionView: NSStackView {
    private var statusLabel: NSTextField!
    private var permissionStatus = PermissionStatus.notGranted

    convenience init(title: String, symbol: Symbols) {
        self.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = DesignSystem.Metrics.formOuterPadding
        edgeInsets = NSEdgeInsets(
            top: TableGroupView.rowVerticalPadding,
            left: TableGroupView.rowHorizontalPadding,
            bottom: TableGroupView.rowVerticalPadding,
            right: TableGroupView.rowHorizontalPadding)
        translatesAutoresizingMaskIntoConstraints = false
        let iconImage = NSImage.fromSymbol(symbol, pointSize: 18)
        let icon = NSImageView(image: iconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 10.14, *) { icon.contentTintColor = .secondaryLabelColor }
        icon.fit(iconImage.size.width, iconImage.size.height)
        let name = NSTextField(labelWithString: title)
        name.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        addArrangedSubview(icon)
        addArrangedSubview(name)
        addArrangedSubview(statusLabel)
        setHuggingPriority(.defaultLow, for: .horizontal)
        DesignSystemControlStyler.styleSurface(self)
        heightAnchor.constraint(greaterThanOrEqualToConstant: TableGroupView.minimumRowHeight).isActive = true
    }

    func updatePermissionStatus(_ permissionStatus: PermissionStatus) {
        guard statusLabel.stringValue.isEmpty || permissionStatus != self.permissionStatus else { return }
        self.permissionStatus = permissionStatus
        let label = permissionStatus == .granted ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("Not allowed", comment: "")
        statusLabel.stringValue = "● " + label
        refreshStatusColor()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        DesignSystemControlStyler.refreshSurface(self)
        refreshStatusColor()
    }

    private func refreshStatusColor() {
        let role: DesignSystem.ColorRole = permissionStatus == .granted ? .statusSuccess : .statusDestructive
        statusLabel.textColor = DesignSystem.color(role, appearance: effectiveAppearance)
    }
}

enum PermissionStatus {
    case granted
    case notGranted
}
