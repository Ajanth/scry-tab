import Foundation

enum FocusSetPickerItemIdentifier: Hashable {
    case allWindows
    case focusSet(UUID)
    case unassignedWindows
}

enum FocusSetPickerItemName: Equatable, Hashable {
    case allWindows
    case savedFocusSet(String)
    case unassignedWindows
}

struct FocusSetPickerItem: Equatable, Hashable {
    let identifier: FocusSetPickerItemIdentifier
    let scope: FocusSetScope
    let name: FocusSetPickerItemName
    let candidateCount: Int
}

struct FocusSetPickerBuiltInNames: Equatable {
    let allWindows: String
    let unassignedWindows: String

    init(allWindows: String, unassignedWindows: String) {
        self.allWindows = allWindows
        self.unassignedWindows = unassignedWindows
    }
}

struct FocusSetPresentationSnapshot {
    let configuration: FocusSetsConfiguration
    let resolver: FocusSetResolver
    let candidates: [FocusSetCandidate]
    let visibility: FocusSetsVisibilitySnapshot
    let candidateCounts: [FocusSetScope: Int]

    var candidateCountsByBundleIdentifier: [String: Int] {
        FocusSetCandidateCounter.countsByBundleIdentifier(candidates, visibility: visibility)
    }
}

struct FocusSetPickerSnapshot {
    let presentation: FocusSetPresentationSnapshot
    let names: FocusSetPickerBuiltInNames
    let resolver: FocusSetPickerResolver
    let availableScopes: Set<FocusSetPickerScope>
}

enum FocusSetPickerNavigationDirection: Equatable {
    case previous
    case next
}

enum FocusSetPickerPanelOwnership: Equatable {
    case unowned
    case owned
}

struct FocusSetPickerPanelRemovalDecision: Equatable {
    let nextOwnership: FocusSetPickerPanelOwnership
    let shouldRestoreOrdinaryState: Bool
}

enum FocusSetPickerPresentationPolicy {
    static let rowsParticipateInKeyViewLoop = false

    static func remove(_ ownership: FocusSetPickerPanelOwnership) -> FocusSetPickerPanelRemovalDecision {
        switch ownership {
        case .unowned:
            return FocusSetPickerPanelRemovalDecision(
                nextOwnership: .unowned,
                shouldRestoreOrdinaryState: false)
        case .owned:
            return FocusSetPickerPanelRemovalDecision(
                nextOwnership: .unowned,
                shouldRestoreOrdinaryState: true)
        }
    }
}

struct FocusSetPickerResolver {
    private let allItems: [FocusSetPickerItem]
    private let builtInNames: FocusSetPickerBuiltInNames

    init(configuration: FocusSetsConfiguration,
         candidateCounts: [FocusSetScope: Int],
         builtInNames: FocusSetPickerBuiltInNames) {
        allItems = Self.makeItems(configuration.sets, candidateCounts: candidateCounts)
        self.builtInNames = builtInNames
    }

    var availableScopes: Set<FocusSetScope> {
        Set(allItems.map(\.scope))
    }

    var itemCount: Int {
        allItems.count
    }

    func visibleItems(matching query: String = "") -> [FocusSetPickerItem] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { Self.matches($0, query: query, builtInNames: builtInNames) }
    }

    func confirmedItem(selectedIdentifier: FocusSetPickerItemIdentifier?,
                       matching query: String = "") -> FocusSetPickerItem? {
        guard let selectedIdentifier else { return nil }
        return visibleItems(matching: query).first { $0.identifier == selectedIdentifier }
    }

    func confirmedScope(selectedIdentifier: FocusSetPickerItemIdentifier?,
                        matching query: String = "") -> FocusSetScope? {
        confirmedItem(selectedIdentifier: selectedIdentifier, matching: query)?.scope
    }

    static func clampedSelectionIndex(_ selectionIndex: Int?, itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        guard let selectionIndex else { return 0 }
        return min(max(selectionIndex, 0), itemCount - 1)
    }

    static func cycledSelectionIndex(_ selectionIndex: Int?,
                                     direction: FocusSetPickerNavigationDirection,
                                     itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        guard let selectionIndex else {
            return direction == .next ? 0 : itemCount - 1
        }
        guard let clampedSelectionIndex = clampedSelectionIndex(selectionIndex, itemCount: itemCount) else {
            return nil
        }
        switch direction {
            case .previous:
                return clampedSelectionIndex == 0 ? itemCount - 1 : clampedSelectionIndex - 1
            case .next:
                return clampedSelectionIndex == itemCount - 1 ? 0 : clampedSelectionIndex + 1
        }
    }

    static func isScopeAvailable(_ scope: FocusSetScope,
                                 configuration: FocusSetsConfiguration,
                                 hasUnassignedCandidates: Bool) -> Bool {
        let candidateCounts: [FocusSetScope: Int] = [.unassigned: hasUnassignedCandidates ? 1 : 0]
        return makeItems(configuration.sets, candidateCounts: candidateCounts).contains { $0.scope == scope }
    }

    private static func makeItems(_ sets: [FocusSet],
                                  candidateCounts: [FocusSetScope: Int]) -> [FocusSetPickerItem] {
        let allWindowsScope = FocusSetScope.allWindows
        var items = [
            FocusSetPickerItem(
                identifier: .allWindows,
                scope: allWindowsScope,
                name: .allWindows,
                candidateCount: candidateCount(for: allWindowsScope, candidateCounts: candidateCounts))
        ]
        for focusSet in uniqueFocusSets(sets) {
            let scope = FocusSetScope.set(id: focusSet.id)
            items.append(
                FocusSetPickerItem(
                    identifier: .focusSet(focusSet.id),
                    scope: scope,
                    name: .savedFocusSet(focusSet.name),
                    candidateCount: candidateCount(for: scope, candidateCounts: candidateCounts)))
        }
        let unassignedScope = FocusSetScope.unassigned
        let unassignedCount = candidateCount(for: unassignedScope, candidateCounts: candidateCounts)
        guard unassignedCount > 0 else { return items }
        items.append(
            FocusSetPickerItem(
                identifier: .unassignedWindows,
                scope: unassignedScope,
                name: .unassignedWindows,
                candidateCount: unassignedCount))
        return items
    }

    private static func uniqueFocusSets(_ sets: [FocusSet]) -> [FocusSet] {
        var identifiers = Set<UUID>()
        var uniqueFocusSets = [FocusSet]()
        for focusSet in sets {
            guard identifiers.insert(focusSet.id).inserted else { continue }
            uniqueFocusSets.append(focusSet)
        }
        return uniqueFocusSets
    }

    private static func candidateCount(for scope: FocusSetScope,
                                       candidateCounts: [FocusSetScope: Int]) -> Int {
        max(candidateCounts[scope] ?? 0, 0)
    }

    private static func matches(_ item: FocusSetPickerItem,
                                query: String,
                                builtInNames: FocusSetPickerBuiltInNames) -> Bool {
        searchName(for: item, builtInNames: builtInNames).range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func searchName(for item: FocusSetPickerItem,
                                   builtInNames: FocusSetPickerBuiltInNames) -> String {
        switch item.name {
            case .allWindows:
                return builtInNames.allWindows
            case let .savedFocusSet(name):
                return name
            case .unassignedWindows:
                return builtInNames.unassignedWindows
        }
    }
}
