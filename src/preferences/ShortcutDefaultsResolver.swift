enum ShortcutDefaultAppScope: Equatable {
    case all
    case active
    case nonActive
}

struct ShortcutDefaultConfiguration: Equatable {
    let holdKeyEquivalent: String
    let nextWindowKeyEquivalent: String
    let appScope: ShortcutDefaultAppScope
}

enum ShortcutDefaultsResolver {
    static func resolve(at index: Int) -> ShortcutDefaultConfiguration {
        switch index {
        case 0:
            return ShortcutDefaultConfiguration(
                holdKeyEquivalent: "⌘", nextWindowKeyEquivalent: "⇥", appScope: .all)
        case 1:
            return ShortcutDefaultConfiguration(
                holdKeyEquivalent: "⌥", nextWindowKeyEquivalent: "⇥", appScope: .active)
        case 2:
            return ShortcutDefaultConfiguration(
                holdKeyEquivalent: "⌥", nextWindowKeyEquivalent: "", appScope: .nonActive)
        default:
            return ShortcutDefaultConfiguration(
                holdKeyEquivalent: "⌥", nextWindowKeyEquivalent: "", appScope: .all)
        }
    }
}
