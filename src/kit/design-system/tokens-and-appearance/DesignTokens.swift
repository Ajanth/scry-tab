import Cocoa

enum DesignColorScheme: Equatable {
    case light
    case dark

    static func resolve(from appearance: NSAppearance) -> DesignColorScheme {
        if #available(macOS 10.14, *) {
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
        return .light
    }
}

struct DesignAccessibilityOptions: Equatable {
    let increaseContrast: Bool
    let reduceTransparency: Bool
    let reduceMotion: Bool

    static var current: DesignAccessibilityOptions {
        DesignAccessibilityOptions(increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
                                   reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                                   reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}

struct DesignSystemEnvironment: Equatable {
    let colorScheme: DesignColorScheme
    let isActive: Bool
    let accessibility: DesignAccessibilityOptions
    let primaryAccent: NSColor
    let secondaryAccent: NSColor
    let accentGradientEnabled: Bool

    init(colorScheme: DesignColorScheme,
         isActive: Bool = true,
         accessibility: DesignAccessibilityOptions = .current,
         primaryAccent: NSColor = DesignSystemColorDefaults.primaryAccent,
         secondaryAccent: NSColor = DesignSystemColorDefaults.secondaryAccent,
         accentGradientEnabled: Bool = true) {
        self.colorScheme = colorScheme
        self.isActive = isActive
        self.accessibility = accessibility
        self.primaryAccent = primaryAccent
        self.secondaryAccent = secondaryAccent
        self.accentGradientEnabled = accentGradientEnabled
    }

    static func current(for view: NSView?) -> DesignSystemEnvironment {
        let fallbackAppearance = NSAppearance(named: .aqua)!
        let appearance: NSAppearance
        if #available(macOS 10.14, *) {
            appearance = view?.effectiveAppearance ?? NSApp?.effectiveAppearance ?? fallbackAppearance
        } else {
            appearance = fallbackAppearance
        }
        return DesignSystemEnvironment(colorScheme: DesignColorScheme.resolve(from: appearance), isActive: view?.window?.isKeyWindow ?? NSApp?.isActive ?? true)
    }
}

enum DesignMetric {
    static let windowRadius = CGFloat(12)
    static let overlayRadius = CGFloat(16)
    static let surfaceRadius = CGFloat(12)
    static let joinedRowRadius = CGFloat(8)
    static let joinedRowInnerRadius = CGFloat(4)
    static let sidebarSelectionRadius = CGFloat(12)
    static let sidebarIconRadius = CGFloat(6)
    static let formOuterPadding = CGFloat(12)
    static let modalOuterPadding = CGFloat(16)
    static let sectionGap = CGFloat(16)
    static let sectionHeaderFooterGap = CGFloat(4)
    static let rowVerticalPadding = CGFloat(4)
    static let rowHorizontalPadding = CGFloat(8)
    static let rowContentGap = CGFloat(8)
    static let compactTextStackGap = CGFloat(1)
    static let standardControlMinHeight = CGFloat(32)
    static let standardListRowHeight = CGFloat(52)
    static let richListRowHeight = CGFloat(56)
    static let sidebarWidth = CGFloat(220)
    static let sidebarGroupGap = CGFloat(24)
    static let sidebarGroupLabelToItemsGap = CGFloat(4)
    static let sidebarGroupLabelHeight = CGFloat(16)
    static let sidebarItemIconSize = CGFloat(22)
    static let sidebarItemIconTextGap = CGFloat(6)
    static let pageHeaderHeight = CGFloat(50)
    static let pageHeaderHorizontalPadding = CGFloat(24)
    static let pageHeaderIconSize = CGFloat(22)
    static let pageHeaderIconTitleGap = CGFloat(8)
    static let sidebarSearchToListGap = CGFloat(12)
    static let settingsDividerWidth = CGFloat(1)
    static let settingsWindowWidth = CGFloat(920)
    static let settingsWindowHeight = CGFloat(620)
    static let settingsWindowMinHeight = CGFloat(520)
    static let focusRingWidth = CGFloat(2)
    static let highContrastFocusRingWidth = CGFloat(3)
    static let choiceCardIconSize = CGFloat(28)
    static let choiceCardOuterPadding = CGFloat(12)
    static let choiceCardVerticalPadding = CGFloat(10)
    static let choiceCardIconTextGap = CGFloat(10)
    static let choiceCardTextGap = CGFloat(2)
    static let choicePickerGap = CGFloat(8)
    static let listStackGap = CGFloat(2)
    static let listItemHorizontalPadding = CGFloat(10)
    static let listItemIconTextGap = CGFloat(10)
    static let listItemIconSize = CGFloat(24)
    static let richListItemIconSize = CGFloat(32)
    static let textEditorMinHeight = CGFloat(120)
    static let permissionIconSize = CGFloat(20)
    static let galleryOuterPadding = CGFloat(16)
    static let gallerySectionGap = CGFloat(18)
    static let galleryRowGap = CGFloat(10)
    static let gallerySampleWidth = CGFloat(128)
    static let gallerySampleHeight = CGFloat(54)
    static let galleryContentWidth = CGFloat(860)
    static let galleryChoicePickerWidth = CGFloat(360)
    static let galleryFormWidth = CGFloat(620)
    static let galleryListWidth = CGFloat(260)
    static let galleryTextFieldWidth = CGFloat(220)
    static let galleryTextEditorWidth = CGFloat(260)
    static let sidebarFadeMaskHeight = CGFloat(16)
}

enum DesignTypography {
    static var pageTitle: NSFont { NSFont.systemFont(ofSize: 20, weight: .medium) }
    static var sectionHeader: NSFont { NSFont.systemFont(ofSize: 13, weight: .medium) }
    static var rowTitle: NSFont { NSFont.systemFont(ofSize: 13, weight: .regular) }
    static var rowTitleEmphasized: NSFont { NSFont.systemFont(ofSize: 13, weight: .medium) }
    static var supportingText: NSFont { NSFont.systemFont(ofSize: 12, weight: .regular) }
    static var footnoteText: NSFont { NSFont.systemFont(ofSize: 11, weight: .regular) }
    static var metrics: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 22, weight: .medium) }
}

enum DesignMotionToken {
    case normal
    case fast
    case removal
    case overlayOffset
}

enum DesignMotion {
    static func duration(_ token: DesignMotionToken, reduceMotion: Bool) -> TimeInterval {
        if reduceMotion {
            switch token {
            case .normal, .fast, .removal: return 0.05
            case .overlayOffset: return 0
            }
        }
        switch token {
        case .normal: return 0.2
        case .fast: return 0.1
        case .removal: return 0.25
        case .overlayOffset: return 0
        }
    }

    static func distance(_ token: DesignMotionToken, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion, token == .overlayOffset else { return 0 }
        return 8
    }
}

enum DesignComponentStateKind: Equatable {
    case normal
    case hovered
    case pressed
    case selected
    case disabled
}

struct DesignComponentState: Equatable {
    let isEnabled: Bool
    let isPressed: Bool
    let isSelected: Bool
    let isHovered: Bool
    let isFocused: Bool

    init(isEnabled: Bool = true, isPressed: Bool = false, isSelected: Bool = false, isHovered: Bool = false, isFocused: Bool = false) {
        self.isEnabled = isEnabled
        self.isPressed = isPressed
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.isFocused = isFocused
    }

    var resolvedKind: DesignComponentStateKind {
        if !isEnabled { return .disabled }
        if isPressed { return .pressed }
        if isSelected { return .selected }
        if isHovered { return .hovered }
        return .normal
    }
}

enum DesignColorRole: CaseIterable {
    case windowMaterial
    case windowAccentTint
    case surfacePlateau
    case surfaceFlat
    case surfaceHover
    case surfacePressed
    case surfaceSelected
    case borderSubtle
    case borderSelected
    case textPrimary
    case textSecondary
    case textDisabled
    case statusSuccess
    case statusWarning
    case statusDestructive
    case searchMatch
    case accentPrimary
    case accentSecondary
}

enum DesignSystemColorDefaults {
    static var primaryAccent: NSColor { NSColor.systemTeal }
    static var secondaryAccent: NSColor { NSColor.systemBlue }
}
