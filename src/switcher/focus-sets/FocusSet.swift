import Foundation

struct FocusSetsConfiguration: Codable, Equatable {
    static let currentVersion = 1

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

    init(id: UUID = UUID(), name: String, rules: [FocusSetRule]) {
        self.id = id
        self.name = name
        self.rules = rules
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
