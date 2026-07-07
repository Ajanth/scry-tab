import Cocoa

enum AppearanceLivePreviewArtwork {
    enum Metrics {
        static let wallpaperAspectRatio = CGFloat(1.6)
        static let wallpaperCornerRadius = CGFloat(18)
        static let wallpaperBorderWidth = CGFloat(1)
        static let switcherCornerRadius = CGFloat(16)
        static let switcherBorderWidth = CGFloat(1)
        static let appIconsSwitcherWidth = CGFloat(184)
        static let appIconsSwitcherHeight = CGFloat(96)
        static let appIconsTileWidth = CGFloat(48)
        static let appIconsTileHeight = CGFloat(68)
        static let appIconsTileSpacing = CGFloat(8)
        static let appIconsContentVerticalOffset = CGFloat(5)
        static let appIconsIconSize = CGFloat(48)
        static let appIconsIconTopInset = CGFloat(1)
        static let appIconsSelectionPadding = CGFloat(4)
        static let appIconsSelectionCornerRadius = CGFloat(14)
        static let appIconsSelectionBorderWidth = CGFloat(2)
        static let appIconsLabelFontSize = CGFloat(7.5)
        static let appIconsLabelWidth = CGFloat(60)
        static let appIconsLabelGap = CGFloat(7)
        static let titlesSwitcherWidth = CGFloat(192)
        static let titlesSwitcherHeight = CGFloat(148)
        static let titlesRowWidth = CGFloat(172)
        static let titlesRowHeight = CGFloat(36)
        static let titlesRowSpacing = CGFloat(8)
        static let titlesRowCornerRadius = CGFloat(12)
        static let titlesIconSize = CGFloat(22)
        static let titlesLabelFontSize = CGFloat(12)
        static let titlesSideInset = CGFloat(10)
        static let titlesLabelGap = CGFloat(9)
        static let titlesStatusGap = CGFloat(7)
        static let titlesStatusSize = CGFloat(18)
        static let pauseButtonDiameter = CGFloat(22)
        static let pauseButtonInset = CGFloat(10)
        static let pauseButtonGlyphSize = CGFloat(11)
    }

    enum Palette {
        static let wallpaperTopLeft = NSColor(srgbRed: 0.87, green: 0.40, blue: 0.31, alpha: 1)
        static let wallpaperTopRight = NSColor(srgbRed: 0.36, green: 0.44, blue: 0.95, alpha: 1)
        static let wallpaperBottom = NSColor(srgbRed: 0.33, green: 0.54, blue: 0.16, alpha: 1)
        static let wallpaperOrangeBlob = NSColor(srgbRed: 0.96, green: 0.43, blue: 0.26, alpha: 0.8)
        static let wallpaperBlueBlob = NSColor(srgbRed: 0.45, green: 0.46, blue: 0.97, alpha: 0.72)
        static let wallpaperGreenBlob = NSColor(srgbRed: 0.45, green: 0.64, blue: 0.05, alpha: 0.46)
        static let wallpaperBorder = NSColor.white.withAlphaComponent(0.12)
        static let switcherFill = NSColor.black.withAlphaComponent(0.58)
        static let switcherBorder = NSColor.white.withAlphaComponent(0.16)
        static let titleColor = NSColor.white.withAlphaComponent(0.94)
        static let titleStatusColor = NSColor.white.withAlphaComponent(0.94)
        static let pauseFill = NSColor.black.withAlphaComponent(0.12)
        static let pauseHoverFill = NSColor.black.withAlphaComponent(0.18)
        static let pauseBorder = NSColor.white.withAlphaComponent(0.12)
        static let pauseGlyph = NSColor.white.withAlphaComponent(0.86)
    }

    struct DemoItem {
        let bundleId: String
        let displayName: String
        let statusSymbols: [String]
    }

    static let demoItems = [
        DemoItem(bundleId: "com.google.Chrome",
                 displayName: "Chrome",
                 statusSymbols: [Symbols.arrowUpBackwardAndArrowDownForwardRectangle.rawValue, StatusIconsView.symbolForSpace(2)]),
        DemoItem(bundleId: "com.apple.finder",
                 displayName: "Finder",
                 statusSymbols: [Symbols.arrowUpBackwardAndArrowDownForwardRectangle.rawValue, StatusIconsView.symbolForSpace(2)]),
        DemoItem(bundleId: "com.apple.systempreferences",
                 displayName: "Settings",
                 statusSymbols: [StatusIconsView.symbolForSpace(1)]),
    ]

    final class WallpaperView: NSView {
        override var isOpaque: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            fatalError("Class only supports programmatic initialization")
        }

        override func draw(_ dirtyRect: NSRect) {
            let clipPath = NSBezierPath(roundedRect: bounds,
                                        xRadius: Metrics.wallpaperCornerRadius,
                                        yRadius: Metrics.wallpaperCornerRadius)
            clipPath.addClip()
            drawBaseGradient()
            drawBlob(NSRect(x: bounds.minX - bounds.width * 0.34,
                            y: bounds.midY - bounds.height * 0.16,
                            width: bounds.width * 1.18,
                            height: bounds.height * 0.84),
                     color: Palette.wallpaperOrangeBlob)
            drawBlob(NSRect(x: bounds.midX - bounds.width * 0.05,
                            y: bounds.minY - bounds.height * 0.08,
                            width: bounds.width * 0.88,
                            height: bounds.height * 0.9),
                     color: Palette.wallpaperBlueBlob)
            drawBlob(NSRect(x: bounds.minX - bounds.width * 0.1,
                            y: bounds.minY - bounds.height * 0.4,
                            width: bounds.width * 1.2,
                            height: bounds.height * 0.9),
                     color: Palette.wallpaperGreenBlob)
            Palette.wallpaperBorder.setStroke()
            clipPath.lineWidth = Metrics.wallpaperBorderWidth
            clipPath.stroke()
        }

        private func drawBaseGradient() {
            let gradient = NSGradient(colors: [
                Palette.wallpaperTopLeft,
                Palette.wallpaperTopRight,
                Palette.wallpaperBottom,
            ])!
            gradient.draw(in: bounds, angle: -38)
        }

        private func drawBlob(_ rect: NSRect, color: NSColor) {
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    class ItemView: NSView {
        var selectionTarget: NSView { self }
        var selectionPadding: CGFloat { 0 }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
        }

        required init?(coder: NSCoder) {
            fatalError("Class only supports programmatic initialization")
        }

        func setFocused(_ focused: Bool) {}
    }

    final class AppIconTileView: ItemView {
        private let iconView = NSImageView()
        private let titleLabel = NSTextField(labelWithString: "")
        override var selectionTarget: NSView { iconView }
        override var selectionPadding: CGFloat { Metrics.appIconsSelectionPadding }

        init(_ info: AppDisplayInfo) {
            super.init(frame: .zero)
            configureIcon(info.icon)
            configureTitle(info.name)
            activateConstraints()
            setFocused(false)
        }

        required init?(coder: NSCoder) {
            fatalError("Class only supports programmatic initialization")
        }

        override func setFocused(_ focused: Bool) {
            titleLabel.isHidden = !focused
        }

        private func configureIcon(_ icon: NSImage) {
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.image = icon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.isEditable = false
            iconView.shadow = TileView.makeAppIconShadow(NSColor.black.withAlphaComponent(0.45))
            addSubview(iconView)
        }

        private func configureTitle(_ title: String) {
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.stringValue = title
            titleLabel.font = NSFont.systemFont(ofSize: Metrics.appIconsLabelFontSize)
            titleLabel.textColor = Palette.titleColor
            titleLabel.alignment = .center
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.usesSingleLineMode = true
            addSubview(titleLabel)
        }

        private func activateConstraints() {
            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: Metrics.appIconsTileWidth),
                heightAnchor.constraint(equalToConstant: Metrics.appIconsTileHeight),
                iconView.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.appIconsIconTopInset),
                iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconView.widthAnchor.constraint(equalToConstant: Metrics.appIconsIconSize),
                iconView.heightAnchor.constraint(equalToConstant: Metrics.appIconsIconSize),
                titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor,
                                                constant: Metrics.appIconsLabelGap),
                titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                titleLabel.widthAnchor.constraint(equalToConstant: Metrics.appIconsLabelWidth),
                titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            ])
        }
    }

    final class TitlesRowView: ItemView {
        private let iconView = NSImageView()
        private let titleLabel = NSTextField(labelWithString: "")
        private let statusStack = NSStackView()

        init(_ info: AppDisplayInfo, statusSymbols: [String]) {
            super.init(frame: .zero)
            configureIcon(info.icon)
            configureTitle(info.name)
            configureStatusStack(statusSymbols)
            activateConstraints()
        }

        required init?(coder: NSCoder) {
            fatalError("Class only supports programmatic initialization")
        }

        private func configureIcon(_ icon: NSImage) {
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.image = icon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.isEditable = false
            addSubview(iconView)
        }

        private func configureTitle(_ title: String) {
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.stringValue = title
            titleLabel.font = NSFont.systemFont(ofSize: Metrics.titlesLabelFontSize)
            titleLabel.textColor = Palette.titleColor
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.usesSingleLineMode = true
            addSubview(titleLabel)
        }

        private func configureStatusStack(_ statusSymbols: [String]) {
            statusStack.translatesAutoresizingMaskIntoConstraints = false
            statusStack.orientation = .horizontal
            statusStack.alignment = .centerY
            statusStack.spacing = Metrics.titlesStatusGap
            addSubview(statusStack)
            statusSymbols.forEach { symbol in
                let view = TileFontIconView(symbolText: symbol, size: Metrics.titlesStatusSize, color: Palette.titleStatusColor)
                view.translatesAutoresizingMaskIntoConstraints = false
                statusStack.addArrangedSubview(view)
            }
        }

        private func activateConstraints() {
            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: Metrics.titlesRowWidth),
                heightAnchor.constraint(equalToConstant: Metrics.titlesRowHeight),
                iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.titlesSideInset),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: Metrics.titlesIconSize),
                iconView.heightAnchor.constraint(equalToConstant: Metrics.titlesIconSize),
                statusStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.titlesSideInset),
                statusStack.centerYAnchor.constraint(equalTo: centerYAnchor),
                titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Metrics.titlesLabelGap),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusStack.leadingAnchor,
                                                     constant: -Metrics.titlesLabelGap),
                titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }
    }
}
