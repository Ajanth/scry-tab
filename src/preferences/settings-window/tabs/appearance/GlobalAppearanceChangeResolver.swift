import Foundation

enum GlobalAppearanceChangeDecision: Equatable {
    case skip
    case applyWithoutConfirmation
    case confirmOverrideReset
    case applyRememberedOverrideChoice(removesOverrides: Bool)
}

enum GlobalAppearanceChangeResolver {
    static func decide(previousValue: String?, newValue: String?, hasExplicitOverrides: Bool,
                        rememberedOverrideChoice: Bool?) -> GlobalAppearanceChangeDecision {
        guard let newValue, newValue != previousValue else { return .skip }
        guard hasExplicitOverrides else { return .applyWithoutConfirmation }
        guard let rememberedOverrideChoice else { return .confirmOverrideReset }
        return .applyRememberedOverrideChoice(removesOverrides: rememberedOverrideChoice)
    }
}
