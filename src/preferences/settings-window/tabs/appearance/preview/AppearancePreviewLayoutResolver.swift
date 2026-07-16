import Foundation

enum AppearancePreviewStyle: Equatable {
    case appIcons
    case titles
}

enum AppearancePreviewSize: Equatable {
    case small
    case medium
    case large
}

enum AppearancePreviewLayoutDirection: Equatable {
    case leftToRight
    case rightToLeft
}

enum AppearancePreviewPlatform: Equatable {
    case legacy
    case macOS26(supportsClearGlass: Bool)
}

enum AppearancePreviewMaterialKind: Equatable {
    case frosted
    case liquidGlassRegular
    case liquidGlassClear
}

enum AppearancePreviewFontWeight: Equatable {
    case regular
    case medium
    case semibold
}

struct AppearancePreviewVisualStyle: Equatable {
    let materialKind: AppearancePreviewMaterialKind
    let fontWeight: AppearancePreviewFontWeight
    let fontPointSize: CGFloat
    let statusFontPointSize: CGFloat
    let statusIconCellWidth: CGFloat
    let usesPanelShadow: Bool
    let panelBorderWidth: CGFloat

    static let empty = AppearancePreviewVisualStyle(
        materialKind: .frosted,
        fontWeight: .regular,
        fontPointSize: 0,
        statusFontPointSize: 0,
        statusIconCellWidth: 0,
        usesPanelShadow: false,
        panelBorderWidth: 0)
}

struct AppearancePreviewTileLayout: Equatable {
    let frame: CGRect
    let iconFrame: CGRect
    let labelFrame: CGRect
    let statusFrame: CGRect
    let showsLabel: Bool
}

struct AppearancePreviewLayout: Equatable {
    let panelFrame: CGRect
    let panelCornerRadius: CGFloat
    let selectionFrame: CGRect
    let selectionCornerRadius: CGFloat
    let selectionBorderWidth: CGFloat
    let tileLayouts: [AppearancePreviewTileLayout]
    let contentScale: CGFloat
    let visualStyle: AppearancePreviewVisualStyle

    static let empty = AppearancePreviewLayout(
        panelFrame: .zero,
        panelCornerRadius: 0,
        selectionFrame: .zero,
        selectionCornerRadius: 0,
        selectionBorderWidth: 0,
        tileLayouts: [],
        contentScale: 1,
        visualStyle: .empty)
}

enum AppearancePreviewLayoutResolver {
    private struct Metrics {
        static let maximumHostRatio = CGFloat(0.9)
        static let interCellPadding = CGFloat(1)
        static let intraCellPadding = CGFloat(5)
        static let appIconLabelSpacing = CGFloat(2)
        static let statusIconSpacing = CGFloat(2)

        let windowPadding: CGFloat
        let panelCornerRadius: CGFloat
        let cellCornerRadius: CGFloat
        let edgeInsets: CGFloat
        let iconSize: CGFloat
        let fontPointSize: CGFloat
        let labelHeight: CGFloat
        let statusFontPointSize: CGFloat
        let statusIconWidth: CGFloat
        let appIconsOuterLabelInset: CGFloat
        let selectionBorderWidth: CGFloat

        static func resolve(style: AppearancePreviewStyle,
                            size: AppearancePreviewSize,
                            platform: AppearancePreviewPlatform) -> Metrics {
            let fontPointSize = resolvedFontPointSize(size)
            let labelHeight = resolvedLabelHeight(size)
            let statusFontPointSize = resolvedStatusFontPointSize(size)
            let statusIconWidth = resolvedStatusIconWidth(size)
            switch style {
                case .appIcons:
                    let isMacOS26: Bool
                    if case .macOS26 = platform {
                        isMacOS26 = true
                    } else {
                        isMacOS26 = false
                    }
                    let windowPadding = size == .large ? CGFloat(28) : 25
                    let iconSize: CGFloat
                    let panelCornerRadius: CGFloat
                    let cellCornerRadius: CGFloat
                    switch size {
                        case .small:
                            iconSize = 70
                            panelCornerRadius = isMacOS26 ? 50 : 23
                            cellCornerRadius = isMacOS26 ? 24 : 10
                        case .medium:
                            iconSize = 110
                            panelCornerRadius = isMacOS26 ? 55 : 23
                            cellCornerRadius = isMacOS26 ? 35 : 10
                        case .large:
                            iconSize = 150
                            panelCornerRadius = isMacOS26 ? 75 : 23
                            cellCornerRadius = isMacOS26 ? 45 : 10
                    }
                    return Metrics(
                        windowPadding: windowPadding,
                        panelCornerRadius: panelCornerRadius,
                        cellCornerRadius: cellCornerRadius,
                        edgeInsets: isMacOS26 ? 6 : 5,
                        iconSize: iconSize,
                        fontPointSize: fontPointSize,
                        labelHeight: labelHeight,
                        statusFontPointSize: statusFontPointSize,
                        statusIconWidth: statusIconWidth,
                        appIconsOuterLabelInset: resolvedOuterLabelInset(size),
                        selectionBorderWidth: 3)
                case .titles:
                    let iconSize: CGFloat
                    switch size {
                        case .small: iconSize = 18
                        case .medium: iconSize = 24
                        case .large: iconSize = 30
                    }
                    return Metrics(
                        windowPadding: 18,
                        panelCornerRadius: 23,
                        cellCornerRadius: 10,
                        edgeInsets: 7,
                        iconSize: iconSize,
                        fontPointSize: fontPointSize,
                        labelHeight: labelHeight,
                        statusFontPointSize: statusFontPointSize,
                        statusIconWidth: statusIconWidth,
                        appIconsOuterLabelInset: 0,
                        selectionBorderWidth: 2)
            }
        }

        private static func resolvedFontPointSize(_ size: AppearancePreviewSize) -> CGFloat {
            switch size {
                case .small: return 13
                case .medium: return 14
                case .large: return 16
            }
        }

        private static func resolvedLabelHeight(_ size: AppearancePreviewSize) -> CGFloat {
            switch size {
                case .small: return 16
                case .medium: return 17
                case .large: return 19
            }
        }

        private static func resolvedStatusFontPointSize(_ size: AppearancePreviewSize) -> CGFloat {
            switch size {
                case .small: return 11
                case .medium: return 12
                case .large: return 14
            }
        }

        private static func resolvedStatusIconWidth(_ size: AppearancePreviewSize) -> CGFloat {
            switch size {
                case .small: return 12.10107421875
                case .medium: return 13.201171875
                case .large: return 15.4013671875
            }
        }

        private static func resolvedOuterLabelInset(_ size: AppearancePreviewSize) -> CGFloat {
            switch size {
                case .small: return 0
                case .medium: return 5
                case .large: return 10
            }
        }
    }

    static func resolve(style: AppearancePreviewStyle,
                        size: AppearancePreviewSize,
                        itemStatusCounts: [Int],
                        focusedIndex: Int,
                        hostSize: CGSize,
                        backingScale: CGFloat,
                        platform: AppearancePreviewPlatform,
                        layoutDirection: AppearancePreviewLayoutDirection = .leftToRight) -> AppearancePreviewLayout {
        let itemCount = itemStatusCounts.count
        guard itemCount > 0, hostSize.width > 0, hostSize.height > 0 else { return .empty }
        let metrics = Metrics.resolve(style: style, size: size, platform: platform)
        let availableSize = CGSize(
            width: hostSize.width * Metrics.maximumHostRatio,
            height: hostSize.height * Metrics.maximumHostRatio)
        let naturalPanelSize = panelSize(
            style: style,
            itemCount: itemCount,
            availableSize: availableSize,
            metrics: metrics)
        let contentScale = scaleToFit(naturalPanelSize, availableSize: availableSize)
        let pixelScale = max(1, backingScale)
        let resolvedPanelSize = aligned(
            size: scaled(naturalPanelSize, by: contentScale),
            backingScale: pixelScale)
        let panelOrigin = aligned(
            point: CGPoint(
                x: (hostSize.width - resolvedPanelSize.width) / 2,
                y: (hostSize.height - resolvedPanelSize.height) / 2),
            backingScale: pixelScale)
        let panelFrame = CGRect(origin: panelOrigin, size: resolvedPanelSize)
        let normalizedFocus = min(max(0, focusedIndex), itemCount - 1)
        var tileLayouts = naturalTileLayouts(
            style: style,
            itemStatusCounts: itemStatusCounts,
            focusedIndex: normalizedFocus,
            panelSize: naturalPanelSize,
            metrics: metrics)
        if layoutDirection == .rightToLeft {
            tileLayouts = mirrored(
                tileLayouts,
                style: style,
                panelWidth: naturalPanelSize.width)
        }
        let resolvedTiles = tileLayouts.map {
            scaled($0, by: contentScale, backingScale: pixelScale)
        }
        let selectionFrame = selectionFrame(
            style: style,
            focusedIndex: normalizedFocus,
            tileLayouts: resolvedTiles,
            backingScale: pixelScale)
        return AppearancePreviewLayout(
            panelFrame: panelFrame,
            panelCornerRadius: aligned(
                metrics.panelCornerRadius * contentScale,
                backingScale: pixelScale),
            selectionFrame: selectionFrame,
            selectionCornerRadius: aligned(
                metrics.cellCornerRadius * contentScale,
                backingScale: pixelScale),
            selectionBorderWidth: aligned(
                metrics.selectionBorderWidth * contentScale,
                backingScale: pixelScale),
            tileLayouts: resolvedTiles,
            contentScale: contentScale,
            visualStyle: visualStyle(
                style: style,
                platform: platform,
                metrics: metrics))
    }

    private static func visualStyle(style: AppearancePreviewStyle,
                                    platform: AppearancePreviewPlatform,
                                    metrics: Metrics) -> AppearancePreviewVisualStyle {
        switch platform {
            case .legacy:
                return AppearancePreviewVisualStyle(
                    materialKind: .frosted,
                    fontWeight: .regular,
                    fontPointSize: metrics.fontPointSize,
                    statusFontPointSize: metrics.statusFontPointSize,
                    statusIconCellWidth: metrics.statusIconWidth,
                    usesPanelShadow: true,
                    panelBorderWidth: 0)
            case .macOS26(let supportsClearGlass):
                let usesClearGlass = style == .appIcons && supportsClearGlass
                return AppearancePreviewVisualStyle(
                    materialKind: usesClearGlass ? .liquidGlassClear : .liquidGlassRegular,
                    fontWeight: style == .appIcons ? .semibold : .medium,
                    fontPointSize: metrics.fontPointSize,
                    statusFontPointSize: metrics.statusFontPointSize,
                    statusIconCellWidth: metrics.statusIconWidth,
                    usesPanelShadow: !usesClearGlass,
                    panelBorderWidth: 0)
        }
    }

    private static func panelSize(style: AppearancePreviewStyle,
                                  itemCount: Int,
                                  availableSize: CGSize,
                                  metrics: Metrics) -> CGSize {
        switch style {
            case .appIcons:
                let tileSize = appIconsTileSize(metrics)
                let rowWidth = Metrics.interCellPadding
                    + CGFloat(itemCount) * (tileSize.width + Metrics.interCellPadding)
                let rowHeight = tileSize.height + Metrics.interCellPadding * 2
                return CGSize(
                    width: rowWidth + metrics.windowPadding * 2,
                    height: rowHeight + metrics.windowPadding * 2
                        - Metrics.intraCellPadding - metrics.labelHeight)
            case .titles:
                let tileHeight = titlesTileHeight(metrics)
                let rowHeight = Metrics.interCellPadding
                    + CGFloat(itemCount) * (tileHeight + Metrics.interCellPadding)
                return CGSize(
                    width: availableSize.width,
                    height: rowHeight + metrics.windowPadding * 2)
        }
    }

    private static func naturalTileLayouts(style: AppearancePreviewStyle,
                                           itemStatusCounts: [Int],
                                           focusedIndex: Int,
                                           panelSize: CGSize,
                                           metrics: Metrics) -> [AppearancePreviewTileLayout] {
        switch style {
            case .appIcons:
                return appIconsTileLayouts(
                    itemCount: itemStatusCounts.count,
                    focusedIndex: focusedIndex,
                    panelSize: panelSize,
                    metrics: metrics)
            case .titles:
                return titlesTileLayouts(
                    itemStatusCounts: itemStatusCounts,
                    panelSize: panelSize,
                    metrics: metrics)
        }
    }

    private static func appIconsTileLayouts(itemCount: Int,
                                            focusedIndex: Int,
                                            panelSize: CGSize,
                                            metrics: Metrics) -> [AppearancePreviewTileLayout] {
        let tileSize = appIconsTileSize(metrics)
        let bottomOrigin = metrics.windowPadding
            - Metrics.intraCellPadding
            - metrics.labelHeight
            + Metrics.interCellPadding
        let tileY = panelSize.height - bottomOrigin - tileSize.height
        return (0..<itemCount).map { index in
            let tileX = metrics.windowPadding
                + Metrics.interCellPadding
                + CGFloat(index) * (tileSize.width + Metrics.interCellPadding)
            let labelInset = index == 0 || index == itemCount - 1
                ? metrics.appIconsOuterLabelInset
                : 0
            return AppearancePreviewTileLayout(
                frame: CGRect(origin: CGPoint(x: tileX, y: tileY), size: tileSize),
                iconFrame: CGRect(
                    x: metrics.edgeInsets,
                    y: metrics.edgeInsets,
                    width: metrics.iconSize,
                    height: metrics.iconSize),
                labelFrame: CGRect(
                    x: labelInset,
                    y: metrics.edgeInsets + metrics.iconSize + Metrics.intraCellPadding * 2,
                    width: tileSize.width - labelInset * 2,
                    height: metrics.labelHeight),
                statusFrame: .zero,
                showsLabel: index == focusedIndex)
        }
    }

    private static func titlesTileLayouts(itemStatusCounts: [Int],
                                          panelSize: CGSize,
                                          metrics: Metrics) -> [AppearancePreviewTileLayout] {
        let tileHeight = titlesTileHeight(metrics)
        let tileWidth = max(
            0,
            panelSize.width - metrics.windowPadding * 2 - Metrics.interCellPadding * 2)
        return itemStatusCounts.enumerated().map { index, statusCount in
            let statusWidth = CGFloat(max(0, statusCount)) * metrics.statusIconWidth
                + CGFloat(max(0, statusCount - 1)) * Metrics.statusIconSpacing
            let horizontalContentWidth = tileWidth - metrics.edgeInsets * 2
            let contentHeight = max(metrics.iconSize, metrics.labelHeight)
            let statusX = metrics.edgeInsets + horizontalContentWidth - statusWidth
            let labelX = metrics.edgeInsets + metrics.iconSize + Metrics.appIconLabelSpacing
            let labelWidth = max(
                0,
                horizontalContentWidth
                    - metrics.iconSize
                    - Metrics.appIconLabelSpacing
                    - statusWidth)
            return AppearancePreviewTileLayout(
                frame: CGRect(
                    x: metrics.windowPadding + Metrics.interCellPadding,
                    y: metrics.windowPadding
                        + Metrics.interCellPadding
                        + CGFloat(index) * (tileHeight + Metrics.interCellPadding),
                    width: tileWidth,
                    height: tileHeight),
                iconFrame: CGRect(
                    x: metrics.edgeInsets,
                    y: metrics.edgeInsets,
                    width: metrics.iconSize,
                    height: metrics.iconSize),
                labelFrame: CGRect(
                    x: labelX,
                    y: metrics.edgeInsets
                        + ((contentHeight - metrics.labelHeight) / 2).rounded(),
                    width: labelWidth,
                    height: metrics.labelHeight),
                statusFrame: CGRect(
                    x: statusX,
                    y: metrics.edgeInsets,
                    width: statusWidth,
                    height: contentHeight),
                showsLabel: true)
        }
    }

    private static func appIconsTileSize(_ metrics: Metrics) -> CGSize {
        CGSize(
            width: metrics.iconSize + metrics.edgeInsets * 2,
            height: metrics.iconSize
                + metrics.edgeInsets * 2
                + Metrics.intraCellPadding * 2
                + metrics.labelHeight)
    }

    private static func titlesTileHeight(_ metrics: Metrics) -> CGFloat {
        max(metrics.iconSize, metrics.labelHeight) + metrics.edgeInsets * 2
    }

    private static func mirrored(_ layouts: [AppearancePreviewTileLayout],
                                 style: AppearancePreviewStyle,
                                 panelWidth: CGFloat) -> [AppearancePreviewTileLayout] {
        layouts.map { layout in
            switch style {
                case .appIcons:
                    return AppearancePreviewTileLayout(
                        frame: mirrored(layout.frame, width: panelWidth),
                        iconFrame: layout.iconFrame,
                        labelFrame: layout.labelFrame,
                        statusFrame: layout.statusFrame,
                        showsLabel: layout.showsLabel)
                case .titles:
                    return AppearancePreviewTileLayout(
                        frame: layout.frame,
                        iconFrame: mirrored(layout.iconFrame, width: layout.frame.width),
                        labelFrame: mirrored(layout.labelFrame, width: layout.frame.width),
                        statusFrame: mirrored(layout.statusFrame, width: layout.frame.width),
                        showsLabel: layout.showsLabel)
            }
        }
    }

    private static func mirrored(_ rect: CGRect, width: CGFloat) -> CGRect {
        CGRect(
            x: width - rect.maxX,
            y: rect.minY,
            width: rect.width,
            height: rect.height)
    }

    private static func selectionFrame(style: AppearancePreviewStyle,
                                       focusedIndex: Int,
                                       tileLayouts: [AppearancePreviewTileLayout],
                                       backingScale: CGFloat) -> CGRect {
        guard tileLayouts.indices.contains(focusedIndex) else { return .zero }
        let tile = tileLayouts[focusedIndex]
        guard style == .appIcons else { return tile.frame }
        let highlightHeight = tile.iconFrame.maxY + tile.iconFrame.minY
        return aligned(
            rect: CGRect(
                x: tile.frame.minX,
                y: tile.frame.minY,
                width: tile.frame.width,
                height: highlightHeight),
            backingScale: backingScale)
    }

    private static func scaleToFit(_ contentSize: CGSize,
                                   availableSize: CGSize) -> CGFloat {
        min(
            1,
            min(
                availableSize.width / max(contentSize.width, 1),
                availableSize.height / max(contentSize.height, 1)))
    }

    private static func scaled(_ layout: AppearancePreviewTileLayout,
                               by scale: CGFloat,
                               backingScale: CGFloat) -> AppearancePreviewTileLayout {
        AppearancePreviewTileLayout(
            frame: aligned(
                rect: scaled(layout.frame, by: scale),
                backingScale: backingScale),
            iconFrame: aligned(
                rect: scaled(layout.iconFrame, by: scale),
                backingScale: backingScale),
            labelFrame: aligned(
                rect: scaled(layout.labelFrame, by: scale),
                backingScale: backingScale),
            statusFrame: aligned(
                rect: scaled(layout.statusFrame, by: scale),
                backingScale: backingScale),
            showsLabel: layout.showsLabel)
    }

    private static func scaled(_ rect: CGRect, by scale: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale)
    }

    private static func scaled(_ size: CGSize, by scale: CGFloat) -> CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }

    private static func aligned(rect: CGRect, backingScale: CGFloat) -> CGRect {
        let minX = aligned(rect.minX, backingScale: backingScale)
        let minY = aligned(rect.minY, backingScale: backingScale)
        let maxX = aligned(rect.maxX, backingScale: backingScale)
        let maxY = aligned(rect.maxY, backingScale: backingScale)
        return CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY))
    }

    private static func aligned(size: CGSize, backingScale: CGFloat) -> CGSize {
        CGSize(
            width: aligned(size.width, backingScale: backingScale),
            height: aligned(size.height, backingScale: backingScale))
    }

    private static func aligned(point: CGPoint, backingScale: CGFloat) -> CGPoint {
        CGPoint(
            x: aligned(point.x, backingScale: backingScale),
            y: aligned(point.y, backingScale: backingScale))
    }

    private static func aligned(_ value: CGFloat,
                                backingScale: CGFloat) -> CGFloat {
        (value * backingScale).rounded() / backingScale
    }
}
