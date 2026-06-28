import Cocoa

enum DesignSystemColors {
    static func color(_ role: DesignColorRole, environment: DesignSystemEnvironment) -> NSColor {
        switch role {
        case .windowMaterial: return windowMaterial(environment)
        case .windowAccentTint: return environment.primaryAccent.withAlphaComponent(environment.colorScheme == .dark ? 0.10 : 0.025)
        case .surfacePlateau: return surfacePlateau(environment)
        case .surfaceFlat: return surfaceFlat(environment)
        case .surfaceHover: return surfaceHover(environment)
        case .surfacePressed: return surfacePressed(environment)
        case .surfaceSelected: return environment.primaryAccent.withAlphaComponent(environment.accessibility.increaseContrast ? 0.22 : 0.15)
        case .borderSubtle: return borderSubtle(environment)
        case .borderSelected: return environment.primaryAccent.withAlphaComponent(environment.accessibility.increaseContrast ? 0.95 : 0.75)
        case .textPrimary: return environment.isActive ? .labelColor : .secondaryLabelColor
        case .textSecondary: return .secondaryLabelColor
        case .textDisabled: return .disabledControlTextColor
        case .statusSuccess: return .systemGreen
        case .statusWarning: return .systemOrange
        case .statusDestructive: return .systemRed
        case .searchMatch: return .selectedTextBackgroundColor
        case .accentPrimary: return environment.primaryAccent
        case .accentSecondary: return environment.secondaryAccent
        }
    }

    static func cgColor(_ role: DesignColorRole, environment: DesignSystemEnvironment, appearance: NSAppearance) -> CGColor {
        withAppearance(appearance) {
            color(role, environment: environment).cgColor
        }
    }

    static func withAppearance<T>(_ appearance: NSAppearance, _ body: () -> T) -> T {
        let previous = NSAppearance.current
        NSAppearance.current = appearance
        defer { NSAppearance.current = previous }
        return body()
    }

    private static func windowMaterial(_ environment: DesignSystemEnvironment) -> NSColor {
        if environment.accessibility.reduceTransparency {
            return environment.colorScheme == .dark ? .windowBackgroundColor : .controlBackgroundColor
        }
        return .clear
    }

    private static func surfacePlateau(_ environment: DesignSystemEnvironment) -> NSColor {
        if environment.accessibility.reduceTransparency {
            return environment.colorScheme == .dark ? .controlBackgroundColor : .textBackgroundColor
        }
        if environment.colorScheme == .dark {
            return NSColor.controlBackgroundColor.withAlphaComponent(environment.accessibility.increaseContrast ? 0.92 : 0.78)
        }
        return NSColor.white.withAlphaComponent(environment.accessibility.increaseContrast ? 0.86 : 0.70)
    }

    private static func surfaceFlat(_ environment: DesignSystemEnvironment) -> NSColor {
        if environment.accessibility.reduceTransparency {
            return .controlBackgroundColor
        }
        let alpha: CGFloat = environment.colorScheme == .dark ? 0.32 : 0.42
        return NSColor.quaternaryLabelColor.withAlphaComponent(environment.accessibility.increaseContrast ? alpha + 0.16 : alpha)
    }

    private static func surfaceHover(_ environment: DesignSystemEnvironment) -> NSColor {
        let alpha: CGFloat = environment.accessibility.increaseContrast ? 0.30 : 0.18
        return environment.primaryAccent.withAlphaComponent(alpha)
    }

    private static func surfacePressed(_ environment: DesignSystemEnvironment) -> NSColor {
        let alpha: CGFloat = environment.accessibility.increaseContrast ? 0.36 : 0.24
        return environment.primaryAccent.withAlphaComponent(alpha)
    }

    private static func borderSubtle(_ environment: DesignSystemEnvironment) -> NSColor {
        if environment.accessibility.increaseContrast {
            if #available(macOS 10.14, *) { return .separatorColor }
            return .gridColor
        }
        let separator: NSColor
        if #available(macOS 10.14, *) {
            separator = .separatorColor
        } else {
            separator = .gridColor
        }
        return environment.colorScheme == .dark ? separator.withAlphaComponent(0.70) : separator.withAlphaComponent(0.55)
    }
}

enum DesignSurfaceRole {
    case window
    case plateau
    case flat
    case selection
    case icon

    var usesGradientLayer: Bool {
        switch self {
        case .window, .icon: return true
        case .plateau, .flat, .selection: return false
        }
    }

    var usesBorderLayer: Bool {
        switch self {
        case .plateau, .flat, .selection, .icon: return true
        case .window: return false
        }
    }
}

struct DesignSurfaceStyle {
    let fillRole: DesignColorRole
    let borderRole: DesignColorRole?
    let borderWidth: CGFloat
    let focusRingRole: DesignColorRole?
    let focusRingWidth: CGFloat
    let cornerRadius: CGFloat
    let shadow: NSShadow?

    static func resolve(role: DesignSurfaceRole, state: DesignComponentState, environment: DesignSystemEnvironment) -> DesignSurfaceStyle {
        let fill = fillRole(role: role, state: state)
        let border = borderRole(role: role, state: state)
        let borderWidth = border == nil ? 0 : (state.isSelected || environment.accessibility.increaseContrast ? 1.5 : 1)
        let focusRingWidth = state.isFocused ? (environment.accessibility.increaseContrast ? DesignMetric.highContrastFocusRingWidth : DesignMetric.focusRingWidth) : 0
        return DesignSurfaceStyle(fillRole: fill, borderRole: border, borderWidth: borderWidth, focusRingRole: state.isFocused ? .accentPrimary : nil, focusRingWidth: focusRingWidth, cornerRadius: radius(role), shadow: shadow(role: role, environment: environment))
    }

    private static func fillRole(role: DesignSurfaceRole, state: DesignComponentState) -> DesignColorRole {
        switch state.resolvedKind {
        case .disabled: return .surfaceFlat
        case .pressed: return .surfacePressed
        case .selected: return .surfaceSelected
        case .hovered: return role == .plateau ? .surfacePlateau : .surfaceHover
        case .normal:
            switch role {
            case .window: return .windowMaterial
            case .plateau, .icon: return .surfacePlateau
            case .flat, .selection: return .surfaceFlat
            }
        }
    }

    private static func borderRole(role: DesignSurfaceRole, state: DesignComponentState) -> DesignColorRole? {
        guard role.usesBorderLayer else { return nil }
        return state.isSelected ? .borderSelected : .borderSubtle
    }

    private static func radius(_ role: DesignSurfaceRole) -> CGFloat {
        switch role {
        case .window: return DesignMetric.windowRadius
        case .icon: return DesignMetric.overlayRadius
        case .plateau, .flat, .selection: return DesignMetric.surfaceRadius
        }
    }

    private static func shadow(role: DesignSurfaceRole, environment: DesignSystemEnvironment) -> NSShadow? {
        guard role == .plateau, environment.colorScheme == .light, !environment.accessibility.reduceTransparency else { return nil }
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(environment.accessibility.increaseContrast ? 0.14 : 0.10)
        shadow.shadowOffset = NSSize(width: 0, height: -0.5)
        shadow.shadowBlurRadius = 0.5
        return shadow
    }
}
