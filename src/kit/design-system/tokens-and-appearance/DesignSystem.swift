import Cocoa

enum DesignSystem {
    enum Metrics {
        static let windowRadius = CGFloat(12)
        static let sectionRadius = CGFloat(12)
        static let joinedOuterRowRadius = CGFloat(8)
        static let joinedInnerRowRadius = CGFloat(4)
        static let sidebarSelectionRadius = CGFloat(12)
        static let sidebarIconRadius = CGFloat(6)
        static let formOuterPadding = CGFloat(12)
        static let sectionGap = CGFloat(16)
        static let headerFooterGap = CGFloat(4)
        static let rowHorizontalPadding = CGFloat(8)
        static let rowVerticalPadding = CGFloat(4)
        static let standardControlMinHeight = CGFloat(32)
        static let controlRadius = CGFloat(8)
        static let controlTextInset = CGFloat(10)
        static let searchGlyphInset = CGFloat(8)
        static let searchTextInset = CGFloat(4)
        static let buttonHorizontalPadding = CGFloat(14)
        static let buttonVerticalPadding = CGFloat(7)
        static let splitDividerThickness = CGFloat(1)
        static let settingsEditorSidebarHeight = CGFloat(470)
    }

    enum ColorRole {
        case windowAccentTint, surfacePlateau, surfaceFlat, surfaceHover, surfacePressed, surfaceSelected
        case borderSubtle, borderSelected, focusAccent, textPrimary, textSecondary, textDisabled
        case statusSuccess, statusWarning, statusDestructive, searchMatch, accentPrimary, accentSecondary
    }

    static func isDark(_ appearance: NSAppearance? = NSAppearance.current) -> Bool {
        if #available(macOS 10.14, *) {
            let name = (appearance ?? NSApp.effectiveAppearance).bestMatch(from: [.darkAqua, .aqua])
            return name == .darkAqua
        }
        return false
    }

    static func materialTintAlpha(_ appearance: NSAppearance? = NSAppearance.current) -> CGFloat {
        isDark(appearance) ? 0.10 : 0.025
    }

    static func color(_ role: ColorRole, appearance: NSAppearance? = NSAppearance.current) -> NSColor {
        let dark = isDark(appearance)
        switch role {
        case .windowAccentTint, .accentPrimary: return .systemAccentColor
        case .accentSecondary: return .secondaryLabelColor
        case .surfacePlateau:
            return dark
                ? NSColor(srgbRed: 0.18, green: 0.18, blue: 0.17, alpha: 1.0)
                : NSColor(white: 1.0, alpha: 0.70)
        case .surfaceFlat:
            return dark
                ? NSColor(srgbRed: 0.24, green: 0.24, blue: 0.23, alpha: 1.0)
                : NSColor(white: 1.0, alpha: 0.48)
        case .surfaceHover:
            return dark
                ? NSColor(srgbRed: 0.27, green: 0.27, blue: 0.26, alpha: 1.0)
                : NSColor(white: 1.0, alpha: 0.60)
        case .surfacePressed:
            return dark
                ? NSColor(srgbRed: 0.30, green: 0.30, blue: 0.29, alpha: 1.0)
                : NSColor(white: 0.0, alpha: 0.08)
        case .surfaceSelected:
            return dark
                ? NSColor(srgbRed: 0.33, green: 0.33, blue: 0.32, alpha: 1.0)
                : NSColor(white: 0.0, alpha: 0.10)
        case .borderSubtle:
            return dark
                ? NSColor(srgbRed: 0.31, green: 0.31, blue: 0.30, alpha: 1.0)
                : NSColor(white: 0.0, alpha: 0.13)
        case .borderSelected: return .systemAccentColor.withAlphaComponent(dark ? 0.34 : 0.28)
        case .focusAccent: return .systemAccentColor.withAlphaComponent(dark ? 0.58 : 0.46)
        case .textPrimary: return .labelColor
        case .textSecondary: return .secondaryLabelColor
        case .textDisabled: return .disabledControlTextColor
        case .statusSuccess: return .systemGreen
        case .statusWarning: return .systemOrange
        case .statusDestructive: return .systemRed
        case .searchMatch: return NSColor(srgbRed: 1.0, green: 0.83, blue: 0.22, alpha: 0.45)
        }
    }

    static func resolvedCGColor(_ color: NSColor, in view: NSView?) -> CGColor {
        let previous = NSAppearance.current
        NSAppearance.current = view?.effectiveAppearance ?? previous
        defer { NSAppearance.current = previous }
        return color.cgColor
    }

    static func semanticCGColor(_ role: ColorRole, in view: NSView?) -> CGColor {
        resolvedCGColor(color(role, appearance: view?.effectiveAppearance), in: view)
    }
}
