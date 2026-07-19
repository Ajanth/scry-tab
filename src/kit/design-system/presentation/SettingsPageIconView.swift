import Cocoa

struct SettingsPageIconDescriptor: Equatable {
    let systemSymbolName: String
    let baseColor: NSColor

    static func descriptor(for page: SettingsTopLevelPage) -> SettingsPageIconDescriptor {
        switch page {
        case .appearance: return SettingsPageIconDescriptor(systemSymbolName: "paintpalette.fill", baseColor: NSColor(srgbRed: 0.00, green: 0.55, blue: 0.50, alpha: 1.0))
        case .controls: return SettingsPageIconDescriptor(systemSymbolName: "command", baseColor: NSColor(srgbRed: 0.36, green: 0.33, blue: 0.78, alpha: 1.0))
        case .focusSets: return SettingsPageIconDescriptor(systemSymbolName: "star.circle.fill", baseColor: NSColor(srgbRed: 0.18, green: 0.49, blue: 0.78, alpha: 1.0))
        case .general: return SettingsPageIconDescriptor(systemSymbolName: "gearshape.fill", baseColor: NSColor(srgbRed: 0.23, green: 0.62, blue: 0.28, alpha: 1.0))
        case .exceptions: return SettingsPageIconDescriptor(systemSymbolName: "hand.raised.fill", baseColor: NSColor(srgbRed: 0.88, green: 0.46, blue: 0.14, alpha: 1.0))
        case .about: return SettingsPageIconDescriptor(systemSymbolName: "info.circle.fill", baseColor: NSColor(srgbRed: 0.45, green: 0.47, blue: 0.50, alpha: 1.0))
        }
    }
}

final class SettingsPageIconView: NSView {
    private static let glyphPointSize: CGFloat = 16
    private static var symbolImages = [String: NSImage]()
    private let imageView = NSImageView()

    var descriptor: SettingsPageIconDescriptor {
        didSet { refreshContent() }
    }

    init(descriptor: SettingsPageIconDescriptor = SettingsPageIconDescriptor.descriptor(for: .appearance)) {
        self.descriptor = descriptor
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
        refreshContent()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 22, height: 22)
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = DesignSystem.Metrics.sidebarIconRadius
        layer?.masksToBounds = true
        if #available(macOS 10.15, *) {
            layer?.cornerCurve = .continuous
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: Self.glyphPointSize),
            imageView.heightAnchor.constraint(equalToConstant: Self.glyphPointSize),
        ])
    }

    private func refreshContent() {
        let image = Self.symbolImage(for: descriptor.systemSymbolName)
        if #available(macOS 10.14, *) {
            imageView.image = image
            imageView.contentTintColor = .white
        } else {
            imageView.image = image?.tinted(.white)
        }
        refreshColors()
    }

    private func refreshColors() {
        layer?.backgroundColor = DesignSystem.resolvedCGColor(descriptor.baseColor, in: self)
    }

    private static func symbolImage(for systemSymbolName: String) -> NSImage? {
        if let image = symbolImages[systemSymbolName] {
            return image
        }
        guard let image = systemSymbolImage(named: systemSymbolName) ?? fallbackSymbolImage(named: systemSymbolName) else {
            return nil
        }
        symbolImages[systemSymbolName] = image
        return image
    }

    private static func systemSymbolImage(named systemSymbolName: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil) else {
            return nil
        }
        let configured = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .medium)) ?? image
        configured.isTemplate = true
        return configured
    }

    private static func fallbackSymbolImage(named systemSymbolName: String) -> NSImage? {
        guard let symbol = fallbackSymbol(for: systemSymbolName) else {
            return nil
        }
        return NSImage.fromSymbol(symbol, pointSize: glyphPointSize)
    }

    private static func fallbackSymbol(for systemSymbolName: String) -> Symbols? {
        switch systemSymbolName {
        case "paintpalette.fill": return .paintpalette
        case "command": return .command
        case "star.circle.fill": return .filledCircledStar
        case "gearshape.fill": return .gearshape
        case "hand.raised.fill": return .handRaised
        case "info.circle.fill": return .circledInfo
        default: return nil
        }
    }
}
