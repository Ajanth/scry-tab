import Cocoa

struct SettingsPageIconDescriptor: Equatable {
    let symbolValue: String
    let baseColor: NSColor

    static func descriptor(for page: SettingsTopLevelPage) -> SettingsPageIconDescriptor {
        switch page {
        case .appearance: return SettingsPageIconDescriptor(symbolValue: "􀝥", baseColor: NSColor(srgbRed: 0.00, green: 0.55, blue: 0.50, alpha: 1.0))
        case .controls: return SettingsPageIconDescriptor(symbolValue: "􀆔", baseColor: NSColor(srgbRed: 0.36, green: 0.33, blue: 0.78, alpha: 1.0))
        case .general: return SettingsPageIconDescriptor(symbolValue: "􀣋", baseColor: NSColor(srgbRed: 0.23, green: 0.62, blue: 0.28, alpha: 1.0))
        case .exceptions: return SettingsPageIconDescriptor(symbolValue: "􀉻", baseColor: NSColor(srgbRed: 0.88, green: 0.46, blue: 0.14, alpha: 1.0))
        case .about: return SettingsPageIconDescriptor(symbolValue: "􀅴", baseColor: NSColor(srgbRed: 0.45, green: 0.47, blue: 0.50, alpha: 1.0))
        }
    }
}

final class SettingsPageIconView: NSView {
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
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 12),
            imageView.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    private func refreshContent() {
        let image = Self.symbolImage(for: descriptor.symbolValue)
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
        let strokeColor = DesignSystem.isDark(effectiveAppearance)
            ? NSColor.white.withAlphaComponent(0.14)
            : NSColor.black.withAlphaComponent(0.08)
        layer?.borderColor = DesignSystem.resolvedCGColor(strokeColor, in: self)
    }

    private static func symbolImage(for symbolValue: String) -> NSImage? {
        if let image = symbolImages[symbolValue] {
            return image
        }
        guard let symbol = Symbols(rawValue: symbolValue) else {
            return nil
        }
        let image = NSImage.fromSymbol(symbol, pointSize: 12)
        symbolImages[symbolValue] = image
        return image
    }
}
