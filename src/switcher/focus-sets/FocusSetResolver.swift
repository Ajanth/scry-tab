import Foundation

/// Immutable app-membership facts compiled once from a Focus Sets configuration.
struct FocusSetResolver: Equatable {
    private let bundleIdentifiersBySet: [UUID: Set<String>]
    private let assignedBundleIdentifiers: Set<String>

    init(configuration: FocusSetsConfiguration) {
        var bundleIdentifiersBySet = [UUID: Set<String>]()
        var assignedBundleIdentifiers = Set<String>()
        for focusSet in configuration.sets {
            let bundleIdentifiers = Set(focusSet.rules.compactMap { rule -> String? in
                guard !rule.applicationBundleIdentifier.isEmpty else { return nil }
                return rule.applicationBundleIdentifier
            })
            bundleIdentifiersBySet[focusSet.id, default: []].formUnion(bundleIdentifiers)
            assignedBundleIdentifiers.formUnion(bundleIdentifiers)
        }
        self.bundleIdentifiersBySet = bundleIdentifiersBySet
        self.assignedBundleIdentifiers = assignedBundleIdentifiers
    }

    /// `titleContains` is intentionally ignored until title narrowing ships.
    func matchesApp(bundleIdentifier: String?, scope: FocusSetScope) -> Bool {
        switch scope {
            case .none, .allWindows:
                return true
            case let .set(id):
                guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
                return bundleIdentifiersBySet[id]?.contains(bundleIdentifier) ?? false
            case .unassigned:
                guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return true }
                return !assignedBundleIdentifiers.contains(bundleIdentifier)
        }
    }
}
