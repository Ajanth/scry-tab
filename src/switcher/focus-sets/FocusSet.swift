import Foundation
import ShortcutRecorder

struct FocusSetsConfiguration: Codable, Equatable {
    static let currentVersion = 3

    let version: Int
    let sets: [FocusSet]

    init(version: Int = FocusSetsConfiguration.currentVersion,
         sets: [FocusSet] = []) {
        self.version = version
        self.sets = sets
    }
}

/// Focus Sets uses one explicit visibility policy rather than inheriting a numbered shortcut.
/// Normal safety exclusions and exception handling remain in `WindowFilterResolver`.
struct FocusSetsPresentationPolicy: Equatable {
    let hideHidden: Bool
    let hideWindowless: Bool
    let windowlessAtEnd: Bool
    let hideFullscreen: Bool
    let hideMinimized: Bool
    let onlyVisibleSpaces: Bool
    let onlyNonVisibleSpaces: Bool
    let onlyPreferredScreen: Bool

    static let standard = FocusSetsPresentationPolicy(
        hideHidden: false,
        hideWindowless: false,
        windowlessAtEnd: true,
        hideFullscreen: false,
        hideMinimized: false,
        onlyVisibleSpaces: false,
        onlyNonVisibleSpaces: false,
        onlyPreferredScreen: false)
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

struct FocusSetShortcutTrigger {
    let modifier: Shortcut
    let key: Shortcut
}

enum FocusSetShortcutBindingResolver {
    static let actionIdentifierPrefix = "focusSetShortcut:"
    private static let modifierShortcuts = ["⌘", "⌥", "⌃", "⇧"].compactMap(Shortcut.init(keyEquivalent:))

    static func bindings(in configuration: FocusSetsConfiguration) -> [FocusSetShortcutBinding] {
        configuration.sets.compactMap { focusSet in
            guard let keyEquivalent = focusSet.shortcutKeyEquivalent,
                  trigger(for: keyEquivalent) != nil else { return nil }
            return FocusSetShortcutBinding(
                focusSetIdentifier: focusSet.id,
                actionIdentifier: actionIdentifier(for: focusSet.id),
                keyEquivalent: keyEquivalent,
                name: focusSet.name)
        }
    }

    static func trigger(for keyEquivalent: String?) -> FocusSetShortcutTrigger? {
        guard let keyEquivalent,
              let shortcut = Shortcut(keyEquivalent: keyEquivalent) else { return nil }
        return trigger(for: shortcut)
    }

    static func trigger(for shortcut: Shortcut) -> FocusSetShortcutTrigger? {
        guard shortcut.keyCode != .none,
              let modifier = modifierShortcut(in: shortcut) else { return nil }
        return FocusSetShortcutTrigger(
            modifier: modifier,
            key: Shortcut(
                code: shortcut.keyCode,
                modifierFlags: [],
                characters: shortcut.characters,
                charactersIgnoringModifiers: shortcut.charactersIgnoringModifiers))
    }

    static func isModifierShortcut(_ shortcut: Shortcut) -> Bool {
        shortcut.keyCode == .none && modifierShortcut(in: shortcut) != nil
    }

    static func isKeyShortcut(_ shortcut: Shortcut) -> Bool {
        shortcut.keyCode != .none && shortcut.modifierFlags == []
    }

    static func shortcut(modifier: Shortcut?, key: Shortcut?) -> Shortcut? {
        guard let modifier,
              let key,
              isModifierShortcut(modifier),
              isKeyShortcut(key) else { return nil }
        return Shortcut(
            code: key.keyCode,
            modifierFlags: modifier.modifierFlags,
            characters: key.characters,
            charactersIgnoringModifiers: key.charactersIgnoringModifiers)
    }

    static func actionIdentifier(for focusSetIdentifier: UUID) -> String {
        actionIdentifierPrefix + focusSetIdentifier.uuidString
    }

    static func focusSetIdentifier(from actionIdentifier: String) -> UUID? {
        guard actionIdentifier.hasPrefix(actionIdentifierPrefix) else { return nil }
        return UUID(uuidString: String(actionIdentifier.dropFirst(actionIdentifierPrefix.count)))
    }

    private static func modifierShortcut(in shortcut: Shortcut) -> Shortcut? {
        let matches = modifierShortcuts.filter { shortcut.modifierFlags.contains($0.modifierFlags) }
        guard matches.count == 1,
              let modifier = matches.first,
              shortcut.modifierFlags == modifier.modifierFlags else { return nil }
        return modifier
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
