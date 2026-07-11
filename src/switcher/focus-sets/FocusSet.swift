import Foundation

struct FocusSetsConfiguration: Codable, Equatable {
    static let currentVersion = 2

    let version: Int
    let presentationShortcutIdentifier: String
    let sets: [FocusSet]

    init(version: Int = FocusSetsConfiguration.currentVersion,
         presentationShortcutIdentifier: String = "",
         sets: [FocusSet] = []) {
        self.version = version
        self.presentationShortcutIdentifier = presentationShortcutIdentifier
        self.sets = sets
    }
}

struct FocusSet: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let rules: [FocusSetRule]
    let shortcutKeyEquivalent: String?

    init(id: UUID = UUID(),
         name: String,
         rules: [FocusSetRule],
         shortcutKeyEquivalent: String? = nil) {
        self.id = id
        self.name = name
        self.rules = rules
        self.shortcutKeyEquivalent = shortcutKeyEquivalent
    }
}

struct FocusSetShortcutBinding: Equatable {
    let focusSetIdentifier: UUID
    let actionIdentifier: String
    let keyEquivalent: String
    let name: String
}

enum FocusSetShortcutBindingResolver {
    static let actionIdentifierPrefix = "focusSetShortcut:"

    static func bindings(in configuration: FocusSetsConfiguration) -> [FocusSetShortcutBinding] {
        configuration.sets.compactMap { focusSet in
            guard let keyEquivalent = focusSet.shortcutKeyEquivalent, !keyEquivalent.isEmpty else { return nil }
            return FocusSetShortcutBinding(
                focusSetIdentifier: focusSet.id,
                actionIdentifier: actionIdentifier(for: focusSet.id),
                keyEquivalent: keyEquivalent,
                name: focusSet.name)
        }
    }

    static func actionIdentifier(for focusSetIdentifier: UUID) -> String {
        actionIdentifierPrefix + focusSetIdentifier.uuidString
    }

    static func focusSetIdentifier(from actionIdentifier: String) -> UUID? {
        guard actionIdentifier.hasPrefix(actionIdentifierPrefix) else { return nil }
        return UUID(uuidString: String(actionIdentifier.dropFirst(actionIdentifierPrefix.count)))
    }
}

struct FocusSetRule: Codable, Equatable {
    let applicationBundleIdentifier: String
    let cachedApplicationName: String
    let titleContains: String?

    init(applicationBundleIdentifier: String,
         cachedApplicationName: String,
         titleContains: String? = nil) {
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.cachedApplicationName = cachedApplicationName
        self.titleContains = titleContains
    }
}

enum FocusSetScope: Equatable, Hashable {
    case none
    case allWindows
    case set(id: UUID)
    case unassigned
}
