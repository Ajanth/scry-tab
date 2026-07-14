import Cocoa

struct AppearancePreviewItem {
    let title: String
    let icon: NSImage
    let statusSymbols: [String]
    let highlightedStatusSymbolIndexes: Set<Int>

    init(title: String,
         icon: NSImage,
         statusSymbols: [String],
         highlightedStatusSymbolIndexes: Set<Int> = []) {
        self.title = title
        self.icon = icon
        self.statusSymbols = statusSymbols
        self.highlightedStatusSymbolIndexes = highlightedStatusSymbolIndexes
    }
}

struct AppearancePreviewModel {
    let appearance: AppearancePreviewAppearanceSnapshot
    let items: [AppearancePreviewItem]
    let focusedIndex: Int

    init(appearance: AppearancePreviewAppearanceSnapshot,
         items: [AppearancePreviewItem]) {
        self.appearance = appearance
        self.items = items
        self.focusedIndex = AppearancePreviewStateResolver.initialFocusedIndex(
            style: appearance.style,
            itemCount: items.count)
    }

    private init(appearance: AppearancePreviewAppearanceSnapshot,
                 items: [AppearancePreviewItem],
                 focusedIndex: Int) {
        self.appearance = appearance
        self.items = items
        self.focusedIndex = focusedIndex
    }

    func advancingFocus() -> AppearancePreviewModel {
        AppearancePreviewModel(
            appearance: appearance,
            items: items,
            focusedIndex: AnimatedSelectionResolver.nextFocusedIndex(
                current: focusedIndex,
                count: items.count))
    }
}

enum AppearancePreviewStatusSymbols {
    static let fullscreen = "􂂡"
    private static let circledZero = "􀀸"
    private static let circledTen = "􀓵"

    static func space(_ number: Int) -> String {
        guard number >= 0 else { return String(number) }
        let base = number <= 9 ? circledZero : circledTen
        let offset = number <= 9 ? number * 2 : number - 10
        guard let scalar = base.unicodeScalars.first,
              let resolved = UnicodeScalar(Int(scalar.value) + offset) else {
            return String(number)
        }
        return String(resolved)
    }
}

extension AppearanceStylePreference {
    var previewStyle: AppearancePreviewStyle {
        self == .appIcons ? .appIcons : .titles
    }
}

extension AppearanceSizePreference {
    var previewSize: AppearancePreviewSize {
        switch self {
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .auto: return .auto
        }
    }
}

extension AppearanceThemePreference {
    var previewTheme: AppearancePreviewTheme {
        switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return .system
        }
    }
}
