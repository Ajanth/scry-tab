import Foundation

enum GlobalAppearanceChangeDecision: Equatable {
    case skip
    case applyWithoutConfirmation
    case confirmOverrideReset
}

enum GlobalAppearanceChangeResolver {
    static func decide(previousValue: String?, newValue: String?, hasExplicitOverrides: Bool) -> GlobalAppearanceChangeDecision {
        guard let newValue, newValue != previousValue else { return .skip }
        return hasExplicitOverrides ? .confirmOverrideReset : .applyWithoutConfirmation
    }
}
