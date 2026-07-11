import Cocoa

final class DesignSystemMaterialView: NSView {
    private let materialView = NSVisualEffectView()
    private let tintView = NSView()
    private var observers = [NSObjectProtocol]()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        let center = NotificationCenter.default
        if let window {
            observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in self?.refresh() })
            observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.refresh() })
        }
        observers.append(center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        refresh()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    private func setup() {
        wantsLayer = true
        materialView.material = .menu
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.translatesAutoresizingMaskIntoConstraints = false
        tintView.wantsLayer = true
        tintView.translatesAutoresizingMaskIntoConstraints = false
        tintView.layer?.compositingFilter = "multiplyBlendMode"
        addSubview(materialView)
        addSubview(tintView)
        NSLayoutConstraint.activate([
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tintView.topAnchor.constraint(equalTo: topAnchor),
            tintView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        refresh()
    }

    private func refresh() {
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        materialView.isHidden = reduceTransparency
        layer?.backgroundColor = reduceTransparency ? DesignSystem.semanticCGColor(.surfaceFlat, in: self) : NSColor.clear.cgColor
        let tint = DesignSystem.color(.windowAccentTint, appearance: effectiveAppearance).withAlphaComponent(DesignSystem.materialTintAlpha(effectiveAppearance))
        tintView.layer?.backgroundColor = DesignSystem.resolvedCGColor(tint, in: self)
    }
}

final class DesignSystemDividerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    private func refresh() {
        layer?.backgroundColor = DesignSystem.semanticCGColor(.borderSubtle, in: self)
    }
}

class DesignSystemFlatSurfaceView: NSView {
    private var accessibilityObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let accessibilityObserver { NotificationCenter.default.removeObserver(accessibilityObserver) }
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        refresh()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = DesignSystem.Metrics.controlRadius
        layer?.borderWidth = 1
        refresh()
    }

    private func refresh() {
        layer?.backgroundColor = DesignSystem.semanticCGColor(.surfaceFlat, in: self)
        layer?.borderColor = DesignSystem.semanticCGColor(.borderSubtle, in: self)
    }
}

final class DesignSystemWindowContentView: NSView {
    private let materialView = DesignSystemMaterialView()
    private let content: NSView
    private let topPadding: CGFloat
    private var accessibilityObserver: NSObjectProtocol?

    init(content: NSView, topPadding: CGFloat = 0) {
        self.content = content
        self.topPadding = topPadding
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshLayerBackedControls()
        }
        refreshLayerBackedControls()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshLayerBackedControls()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        materialView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(materialView)
        addSubview(content)
        NSLayoutConstraint.activate([
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.topAnchor.constraint(equalTo: topAnchor, constant: topPadding),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func refreshLayerBackedControls() {
        DesignSystemControlStyler.refreshEditableFields(in: content)
    }
}
