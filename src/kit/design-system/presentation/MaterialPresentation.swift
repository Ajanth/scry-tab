import Cocoa

final class MaterialModalPanel: NSPanel {
    private let surface = MaterialSurfaceView(role: .window)
    private let contentContainer = NSView()

    init(contentSize: NSSize, title: String = "") {
        super.init(contentRect: NSRect(origin: .zero, size: contentSize),
                   styleMask: [.titled, .closable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        self.title = title
        setupPanel()
    }

    func setModalContent(_ view: NSView) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: DesignMetric.modalOuterPadding),
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: DesignMetric.modalOuterPadding),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -DesignMetric.modalOuterPadding),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -DesignMetric.modalOuterPadding),
        ])
    }

    private func setupPanel() {
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        contentView = surface
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(contentContainer)
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: surface.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
        ])
    }
}

final class MaterialPopoverPresenter: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let surface = MaterialSurfaceView(role: .plateau)
    private let contentContainer = NSView()
    private let host = NSViewController()

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.delegate = self
        setupSurface()
        host.view = surface
        popover.contentViewController = host
    }

    func show(content: NSView, relativeTo rect: NSRect, of view: NSView, preferredEdge: NSRectEdge = .maxY) {
        install(content)
        popover.show(relativeTo: rect, of: view, preferredEdge: preferredEdge)
    }

    func close() {
        popover.close()
    }

    private func install(_ content: NSView) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        content.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: DesignMetric.modalOuterPadding),
            content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: DesignMetric.modalOuterPadding),
            content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -DesignMetric.modalOuterPadding),
            content.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -DesignMetric.modalOuterPadding),
        ])
    }

    private func setupSurface() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(contentContainer)
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: surface.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
        ])
    }
}

enum PermissionStatusKind {
    case granted
    case missing
    case unknown

    var colorRole: DesignColorRole {
        switch self {
        case .granted: return .statusSuccess
        case .missing: return .statusWarning
        case .unknown: return .textSecondary
        }
    }
}

final class PermissionStatusRow: SettingsRowView {
    private let iconView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let actionButton = SurfaceButton(title: NSLocalizedString("Open System Settings", comment: ""))
    private var status = PermissionStatusKind.unknown

    init(title: String, text: String, image: NSImage?, statusText: String, status: PermissionStatusKind, action: ActionClosure? = nil) {
        super.init(title: title, subtitle: text, content: [iconView, statusLabel, actionButton])
        iconView.image = image
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.isHidden = image == nil
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: DesignMetric.permissionIconSize).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: DesignMetric.permissionIconSize).isActive = true
        actionButton.onAction = action
        setStatus(statusText, status)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshStatusColor()
    }

    func setStatus(_ text: String, _ status: PermissionStatusKind) {
        self.status = status
        statusLabel.stringValue = text
        refreshStatusColor()
    }

    private func refreshStatusColor() {
        let environment = DesignSystemEnvironment.current(for: self)
        DesignSystemColors.withAppearance(currentAppearance) {
            statusLabel.textColor = DesignSystemColors.color(status.colorRole, environment: environment)
        }
    }

    private var currentAppearance: NSAppearance {
        if #available(macOS 10.14, *) { return effectiveAppearance }
        return NSAppearance(named: .aqua)!
    }
}
