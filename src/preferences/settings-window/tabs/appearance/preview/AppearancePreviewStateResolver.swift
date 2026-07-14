import Foundation

enum AppearancePreviewTheme: Equatable {
    case light
    case dark
    case system
}

struct AppearancePreviewAppearanceSnapshot: Equatable {
    let style: AppearancePreviewStyle
    let size: AppearancePreviewSize
    let theme: AppearancePreviewTheme
    let systemIsDark: Bool

    var isDark: Bool {
        AppearancePreviewStateResolver.resolvedIsDark(
            theme: theme,
            systemIsDark: systemIsDark)
    }

    func updating(style: AppearancePreviewStyle? = nil,
                  size: AppearancePreviewSize? = nil,
                  theme: AppearancePreviewTheme? = nil,
                  systemIsDark: Bool? = nil) -> AppearancePreviewAppearanceSnapshot {
        AppearancePreviewAppearanceSnapshot(
            style: style ?? self.style,
            size: size ?? self.size,
            theme: theme ?? self.theme,
            systemIsDark: systemIsDark ?? self.systemIsDark)
    }
}

enum AppearancePreviewStatusHighlight: Equatable {
    case none
    case statusIcons
    case spaceNumbers
}

enum AppearancePreviewStatusHighlightResolver {
    static func indexes(for highlight: AppearancePreviewStatusHighlight,
                        hasStatusIcon: Bool,
                        showsSpaceNumber: Bool) -> Set<Int> {
        switch highlight {
            case .none: return []
            case .statusIcons: return hasStatusIcon ? [0] : []
            case .spaceNumbers:
                guard showsSpaceNumber else { return [] }
                return [hasStatusIcon ? 1 : 0]
        }
    }
}

enum AppearancePreviewStateResolver {
    static func resolvedIsDark(theme: AppearancePreviewTheme,
                               systemIsDark: Bool) -> Bool {
        switch theme {
            case .light: return false
            case .dark: return true
            case .system: return systemIsDark
        }
    }

    static func initialFocusedIndex(style: AppearancePreviewStyle, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        return style == .appIcons ? min(1, itemCount - 1) : 0
    }

    static func pausedStates(previewCount: Int, playingIndex: Int?) -> [Bool] {
        guard previewCount > 0 else { return [] }
        return (0..<previewCount).map { $0 != playingIndex }
    }

    static func orderedStatusSymbols(_ symbols: [String],
                                     layoutDirection: AppearancePreviewLayoutDirection) -> [String] {
        layoutDirection == .rightToLeft ? Array(symbols.reversed()) : symbols
    }
}
