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
    var descriptor: SettingsPageIconDescriptor {
        didSet { needsDisplay = true }
    }

    init(descriptor: SettingsPageIconDescriptor = SettingsPageIconDescriptor.descriptor(for: .appearance)) {
        self.descriptor = descriptor
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 22, height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        drawTile(in: rect)
        drawSymbol(in: rect)
    }

    private func drawTile(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: DesignSystem.Metrics.sidebarIconRadius, yRadius: DesignSystem.Metrics.sidebarIconRadius)
        let base = descriptor.baseColor
        let top = base.blended(withFraction: 0.12, of: .white) ?? base
        let bottom = base.blended(withFraction: 0.08, of: .black) ?? base
        NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: 90)
        let strokeColor = DesignSystem.isDark(effectiveAppearance)
            ? NSColor.white.withAlphaComponent(0.14)
            : NSColor.black.withAlphaComponent(0.08)
        strokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawSymbol(in rect: NSRect) {
        let font = NSFont(name: "SF Pro Text", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white, .paragraphStyle: paragraph]
        let string = NSString(string: descriptor.symbolValue)
        let size = string.size(withAttributes: attrs)
        let symbolRect = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2 - 0.5, width: size.width, height: size.height)
        string.draw(in: symbolRect, withAttributes: attrs)
    }
}
