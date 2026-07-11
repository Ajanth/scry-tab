import Cocoa

enum AppearanceLivePreviewArtwork {
    enum Metrics {
        static let wallpaperAspectRatio = CGFloat(1.6)
        static let wallpaperCornerRadius = CGFloat(18)
        static let wallpaperBorderWidth = CGFloat(1)
        static let illustratedRenderSize = NSSize(width: 1000, height: 625)
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
        let isFullscreen: Bool
        let spaceNumber: Int
    }

    enum IllustratedTitleMode: Hashable {
        case focusedAppName
        case appName
        case windowTitle
        case appNameAndWindowTitle
    }

    enum IllustratedHighlight: Hashable {
        case none
        case statusIcons
        case spaceNumbers
    }

    struct IllustratedPreviewState: Hashable {
        let style: AppearanceStylePreference
        let titleMode: IllustratedTitleMode
        let showsStatusIcons: Bool
        let showsSpaceNumbers: Bool
        let highlight: IllustratedHighlight
    }

    struct IllustratedPreviewItem {
        let bundleId: String
        let appName: String
        let windowTitle: String
        let statusSymbol: String?
        let spaceNumber: Int
    }

    static let demoItems = [
        DemoItem(bundleId: "com.google.Chrome",
                 displayName: "Chrome",
                 isFullscreen: true,
                 spaceNumber: 2),
        DemoItem(bundleId: "com.apple.finder",
                 displayName: "Finder",
                 isFullscreen: true,
                 spaceNumber: 2),
        DemoItem(bundleId: "com.apple.systempreferences",
                 displayName: "Settings",
                 isFullscreen: false,
                 spaceNumber: 1),
    ]

    static let illustratedPreviewItems = [
        IllustratedPreviewItem(bundleId: "com.apple.Safari",
                               appName: "Safari",
                               windowTitle: "AltTab",
                               statusSymbol: AppearancePreviewStatusSymbols.fullscreen,
                               spaceNumber: 2),
        IllustratedPreviewItem(bundleId: "com.apple.finder",
                               appName: "Finder",
                               windowTitle: "Music",
                               statusSymbol: AppearancePreviewStatusSymbols.fullscreen,
                               spaceNumber: 2),
        IllustratedPreviewItem(bundleId: "com.apple.Notes",
                               appName: "Note",
                               windowTitle: "Memo",
                               statusSymbol: nil,
                               spaceNumber: 1),
    ]

    private static let wallpaperImage = loadWallpaperImage()
    private static var illustratedPreviewCache = [IllustratedPreviewState: NSImage]()
    private static let symbolParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 0.85
        return style
    }()

    static func illustratedPreviewImage(_ state: IllustratedPreviewState) -> NSImage {
        if let cached = illustratedPreviewCache[state] {
            return cached
        }
        let image = IllustratedPreviewRenderer(state: state, size: Metrics.illustratedRenderSize).makeImage()
        illustratedPreviewCache[state] = image
        return image
    }

    static func drawWallpaper(in rect: NSRect) {
        if let wallpaperImage {
            drawWallpaperImage(wallpaperImage, in: rect)
            return
        }
        drawFallbackWallpaper(in: rect)
    }

    final class WallpaperView: NSView {
        override var isOpaque: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            translatesAutoresizingMaskIntoConstraints = false
            wantsLayer = true
            layer?.cornerRadius = Metrics.wallpaperCornerRadius
            layer?.masksToBounds = true
        }

        required init?(coder: NSCoder) {
            fatalError("Class only supports programmatic initialization")
        }

        override func draw(_ dirtyRect: NSRect) {
            let clipPath = NSBezierPath(roundedRect: bounds,
                                        xRadius: Metrics.wallpaperCornerRadius,
                                        yRadius: Metrics.wallpaperCornerRadius)
            clipPath.addClip()
            AppearanceLivePreviewArtwork.drawWallpaper(in: bounds)
            Palette.wallpaperBorder.setStroke()
            clipPath.lineWidth = Metrics.wallpaperBorderWidth
            clipPath.stroke()
        }
    }

    private static func loadWallpaperImage() -> NSImage? {
        guard let path = Bundle.main.path(forResource: "scry_wallpaper@2x", ofType: "heic") else { return nil }
        let image = NSImage(contentsOfFile: path)
        image?.cacheMode = .never
        return image
    }

    private static func drawWallpaperImage(_ image: NSImage, in rect: NSRect) {
        guard image.size.width > 0, image.size.height > 0 else {
            drawFallbackWallpaper(in: rect)
            return
        }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawRect = NSRect(x: rect.midX - drawSize.width / 2,
                              y: rect.midY - drawSize.height / 2,
                              width: drawSize.width,
                              height: drawSize.height)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: drawRect)
    }

    private static func drawFallbackWallpaper(in rect: NSRect) {
        let gradient = NSGradient(colors: [
            Palette.wallpaperTopLeft,
            Palette.wallpaperTopRight,
            Palette.wallpaperBottom,
        ])!
        gradient.draw(in: rect, angle: -38)
        drawBlob(NSRect(x: rect.minX - rect.width * 0.34,
                        y: rect.midY - rect.height * 0.16,
                        width: rect.width * 1.18,
                        height: rect.height * 0.84),
                 color: Palette.wallpaperOrangeBlob)
        drawBlob(NSRect(x: rect.midX - rect.width * 0.05,
                        y: rect.minY - rect.height * 0.08,
                        width: rect.width * 0.88,
                        height: rect.height * 0.9),
                 color: Palette.wallpaperBlueBlob)
        drawBlob(NSRect(x: rect.minX - rect.width * 0.1,
                        y: rect.minY - rect.height * 0.4,
                        width: rect.width * 1.2,
                        height: rect.height * 0.9),
                 color: Palette.wallpaperGreenBlob)
    }

    private static func drawBlob(_ rect: NSRect, color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private struct IllustratedPreviewRenderer {
        let state: IllustratedPreviewState
        let size: NSSize

        func makeImage() -> NSImage {
            let image = NSImage(size: size)
            image.lockFocus()
            drawWallpaper(in: NSRect(origin: .zero, size: size))
            drawSwitcher()
            image.unlockFocus()
            return image
        }

        private func drawSwitcher() {
            if state.style == .appIcons {
                drawAppIconsSwitcher()
                return
            }
            drawTitlesSwitcher()
        }

        private func drawAppIconsSwitcher() {
            let frame = NSRect(x: 78, y: 153, width: 846, height: 308)
            drawRoundedRect(frame, radius: 22, fill: NSColor(calibratedWhite: 0.79, alpha: 0.68))
            let tileInset = CGFloat(30)
            let tileSpacing = CGFloat(28)
            let tileWidth = (frame.width - tileInset * 2 - tileSpacing * 2) / 3
            let tileHeight = frame.height - tileInset * 2
            let tileY = frame.minY + tileInset
            let iconSize = CGFloat(160)
            let labelFont = NSFont.systemFont(ofSize: 22, weight: .regular)
            let accessoryFont = NSFont.systemFont(ofSize: 19, weight: .regular)
            illustratedPreviewItems.enumerated().forEach { index, item in
                let tileX = frame.minX + tileInset + CGFloat(index) * (tileWidth + tileSpacing)
                let tileRect = NSRect(x: tileX, y: tileY, width: tileWidth, height: tileHeight)
                drawRoundedRect(tileRect, radius: 18, fill: NSColor(calibratedWhite: 0.23, alpha: 0.72))
                drawAppIcon(item, in: NSRect(x: tileRect.midX - iconSize / 2,
                                             y: tileRect.midY - iconSize / 2 + 12,
                                             width: iconSize,
                                             height: iconSize))
                drawAppIconsTitle(item, index: index, in: tileRect, font: labelFont)
                drawAppIconsAccessory(item, index: index, in: tileRect, font: accessoryFont)
            }
        }

        private func drawTitlesSwitcher() {
            let frame = NSRect(x: 154, y: 116, width: 692, height: 392)
            drawRoundedRect(frame, radius: 21, fill: NSColor(calibratedWhite: 0.79, alpha: 0.68))
            let rowInset = CGFloat(28)
            let rowSpacing = CGFloat(22)
            let rowHeight = (frame.height - rowInset * 2 - rowSpacing * 2) / 3
            let iconSize = CGFloat(72)
            let titleFont = NSFont.systemFont(ofSize: 34, weight: .regular)
            let accessoryFont = NSFont.systemFont(ofSize: 34, weight: .regular)
            illustratedPreviewItems.enumerated().forEach { index, item in
                let rowY = frame.maxY - rowInset - rowHeight - CGFloat(index) * (rowHeight + rowSpacing)
                let rowRect = NSRect(x: frame.minX + rowInset, y: rowY, width: frame.width - rowInset * 2, height: rowHeight)
                drawRoundedRect(rowRect, radius: 17, fill: NSColor(calibratedWhite: 0.23, alpha: 0.72))
                drawAppIcon(item, in: NSRect(x: rowRect.minX + 20,
                                             y: rowRect.midY - iconSize / 2,
                                             width: iconSize,
                                             height: iconSize))
                drawTitleRowTitle(item,
                                  in: NSRect(x: rowRect.minX + 110, y: rowRect.minY + 12, width: rowRect.width - 280, height: rowRect.height - 24),
                                  font: titleFont)
                drawTitleRowAccessories(item, in: rowRect, font: accessoryFont)
            }
        }

        private func drawAppIconsTitle(_ item: IllustratedPreviewItem, index: Int, in rect: NSRect, font: NSFont) {
            guard let text = appIconsTitle(item, index: index) else { return }
            let labelRect = NSRect(x: rect.minX + 12, y: rect.minY + 10, width: rect.width - 24, height: 34)
            drawText(text, in: labelRect, font: font, alignment: .center)
        }

        private func drawAppIconsAccessory(_ item: IllustratedPreviewItem, index: Int, in rect: NSRect, font: NSFont) {
            guard index == 1 else { return }
            var x = rect.minX + 48
            let y = rect.minY + 44
            if state.showsStatusIcons, let statusSymbol = item.statusSymbol {
                let statusRect = drawSymbol(statusSymbol,
                                            font: font,
                                            color: Palette.titleStatusColor,
                                            origin: NSPoint(x: x, y: y))
                if state.highlight == .statusIcons {
                    drawHighlight(statusRect.insetBy(dx: -8, dy: -6))
                }
                x = statusRect.maxX + 10
            }
            if state.showsSpaceNumbers {
                let spaceRect = drawSymbol(AppearancePreviewStatusSymbols.space(item.spaceNumber),
                                           font: font,
                                           color: Palette.titleStatusColor,
                                           origin: NSPoint(x: x, y: y))
                if state.highlight == .spaceNumbers {
                    drawHighlight(spaceRect.insetBy(dx: -8, dy: -6))
                }
            }
        }

        private func drawTitleRowTitle(_ item: IllustratedPreviewItem, in rect: NSRect, font: NSFont) {
            drawText(titleText(item), in: rect, font: font, alignment: .left)
        }

        private func drawTitleRowAccessories(_ item: IllustratedPreviewItem, in rect: NSRect, font: NSFont) {
            var cursorX = rect.maxX - 34
            if state.showsSpaceNumbers {
                let symbol = AppearancePreviewStatusSymbols.space(item.spaceNumber)
                let spaceRect = drawSymbol(symbol,
                                           font: font,
                                           color: Palette.titleStatusColor,
                                           origin: NSPoint(x: cursorX - symbolWidth(symbol, font: font),
                                                           y: rect.midY - font.capHeight / 2 - 4))
                if state.highlight == .spaceNumbers {
                    drawHighlight(spaceRect.insetBy(dx: -8, dy: -6))
                }
                cursorX = spaceRect.minX - 28
            }
            if state.showsStatusIcons, let statusSymbol = item.statusSymbol {
                let statusRect = drawSymbol(statusSymbol,
                                            font: font,
                                            color: Palette.titleStatusColor,
                                            origin: NSPoint(x: cursorX - symbolWidth(statusSymbol, font: font),
                                                            y: rect.midY - font.capHeight / 2 - 4))
                if state.highlight == .statusIcons {
                    drawHighlight(statusRect.insetBy(dx: -8, dy: -6))
                }
            }
        }

        private func appIconsTitle(_ item: IllustratedPreviewItem, index: Int) -> String? {
            if state.titleMode == .focusedAppName {
                return index == 1 ? item.appName : nil
            }
            return titleText(item)
        }

        private func titleText(_ item: IllustratedPreviewItem) -> String {
            switch state.titleMode {
                case .focusedAppName, .appName:
                    return item.appName
                case .windowTitle:
                    return item.windowTitle
                case .appNameAndWindowTitle:
                    return "\(item.appName) - \(item.windowTitle)"
            }
        }

        private func drawAppIcon(_ item: IllustratedPreviewItem, in rect: NSRect) {
            let info = AppDisplayInfo.resolve(bundleId: item.bundleId)
            NSGraphicsContext.saveGraphicsState()
            makeAppIconShadow().set()
            info.icon.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
        }

        private func makeAppIconShadow() -> NSShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
            shadow.shadowOffset = NSSize(width: 0.1, height: 1)
            shadow.shadowBlurRadius = 2
            return shadow
        }

        private func drawText(_ text: String, in rect: NSRect, font: NSFont, alignment: NSTextAlignment) {
            let style = NSMutableParagraphStyle()
            style.alignment = alignment
            style.lineBreakMode = .byTruncatingTail
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: Palette.titleColor,
                .paragraphStyle: style,
            ]
            (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
        }

        private func drawSymbol(_ symbol: String, font: NSFont, color: NSColor, origin: NSPoint) -> NSRect {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: AppearanceLivePreviewArtwork.symbolParagraphStyle,
            ]
            let attributed = NSAttributedString(string: symbol, attributes: attributes)
            attributed.draw(at: origin)
            return NSRect(origin: origin, size: attributed.size())
        }

        private func symbolWidth(_ symbol: String, font: NSFont) -> CGFloat {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: AppearanceLivePreviewArtwork.symbolParagraphStyle,
            ]
            return NSAttributedString(string: symbol, attributes: attributes).size().width
        }

        private func drawRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
            fill.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }

        private func drawHighlight(_ rect: NSRect) {
            let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
            path.lineWidth = 6
            NSColor.systemRed.withAlphaComponent(0.85).setStroke()
            path.stroke()
        }
    }
}
