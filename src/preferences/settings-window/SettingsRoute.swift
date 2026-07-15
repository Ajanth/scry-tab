import Foundation

enum SettingsTopLevelPage: String, CaseIterable, Hashable {
    case appearance
    case controls
    case focusSets
    case general
    case exceptions
    case about
}

enum ControlsPaneDestination: Equatable {
    case trigger
    case filtering
    case appearance
    case ordering
}

enum ControlsDestination: Equatable {
    case shortcut(id: String, pane: ControlsPaneDestination?)
    case gesture
    case activeShortcuts
}

enum ExceptionDestination: Equatable {
    case bundleIdentifier(String)
}

enum SettingsRoute: Equatable {
    case appearance
    case controls(ControlsDestination?)
    case focusSets
    case general
    case exceptions(ExceptionDestination?)
    case about
    case search(query: String)

    var page: SettingsTopLevelPage? {
        switch self {
        case .appearance: return .appearance
        case .controls: return .controls
        case .focusSets: return .focusSets
        case .general: return .general
        case .exceptions: return .exceptions
        case .about: return .about
        case .search: return nil
        }
    }

    func normalizedDeletedShortcut(using shortcutExists: (String) -> Bool) -> SettingsRoute {
        guard case .controls(.shortcut(let id, let pane)) = self else { return self }
        guard shortcutExists(id) else { return .controls(nil) }
        return .controls(.shortcut(id: id, pane: pane))
    }
}

final class SettingsNavigationController {
    private(set) var selectedRoute: SettingsRoute
    private(set) var previousNonSearchRoute: SettingsRoute

    init(initialRoute: SettingsRoute = .appearance) {
        let route = initialRoute.normalizedNonSearchRoute
        selectedRoute = route
        previousNonSearchRoute = route
    }

    func navigate(to route: SettingsRoute) {
        selectedRoute = route
        if !route.isSearchRoute {
            previousNonSearchRoute = route
        }
    }

    func updateSearch(query: String) {
        guard !SettingsSearch.isQueryEmpty(query) else {
            restorePreviousNonSearchRoute()
            return
        }
        if !selectedRoute.isSearchRoute {
            previousNonSearchRoute = selectedRoute.normalizedNonSearchRoute
        }
        selectedRoute = .search(query: query)
    }

    func restorePreviousNonSearchRoute() {
        selectedRoute = previousNonSearchRoute
    }
}

private extension SettingsRoute {
    var isSearchRoute: Bool {
        if case .search = self { return true }
        return false
    }

    var normalizedNonSearchRoute: SettingsRoute {
        if case .search = self { return .appearance }
        return self
    }
}

enum SettingsAboutSearch {
    static let acknowledgmentKeywords = ["Acknowledgments", "ShortcutRecorder", "Sparkle", "Sentry Cocoa"]
}

struct SettingsSearchDescriptor {
    let id: String
    let route: SettingsRoute
    let sectionID: String
    let title: String
    let subtitle: String?
    let keywords: [String]
    let valueProvider: (() -> [String])?

    init(id: String,
         route: SettingsRoute,
         sectionID: String,
         title: String,
         subtitle: String? = nil,
         keywords: [String] = [],
         valueProvider: (() -> [String])? = nil) {
        self.id = id
        self.route = route
        self.sectionID = sectionID
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.valueProvider = valueProvider
    }

    var searchableStrings: [String] {
        var strings = [title]
        if let subtitle { strings.append(subtitle) }
        strings.append(contentsOf: keywords)
        strings.append(contentsOf: valueProvider?() ?? [])
        return strings
    }
}

struct SettingsSearchDescriptorMatch {
    let descriptor: SettingsSearchDescriptor
    let score: Double
}

struct SettingsSearchDescriptorMatchGroup {
    let page: SettingsTopLevelPage
    let matches: [SettingsSearchDescriptorMatch]
}

enum SettingsSearchDescriptorMatcher {
    static func matches(query: String, descriptors: [SettingsSearchDescriptor]) -> [SettingsSearchDescriptorMatch] {
        guard !SettingsSearch.isQueryEmpty(query) else { return [] }
        return descriptors.compactMap { descriptor in
            guard let score = score(query: query, descriptor: descriptor) else { return nil }
            return SettingsSearchDescriptorMatch(descriptor: descriptor, score: score)
        }.sorted(by: orderedBefore)
    }

    static func groupedMatches(query: String,
                               descriptors: [SettingsSearchDescriptor],
                               pageOrder: [SettingsTopLevelPage] = SettingsTopLevelPage.allCases) -> [SettingsSearchDescriptorMatchGroup] {
        let matchesByPage = Dictionary(grouping: matches(query: query, descriptors: descriptors).compactMap { match -> (SettingsTopLevelPage, SettingsSearchDescriptorMatch)? in
            guard let page = match.descriptor.route.page else { return nil }
            return (page, match)
        }) { $0.0 }
        return pageOrder.compactMap { page in
            guard let entries = matchesByPage[page], !entries.isEmpty else { return nil }
            return SettingsSearchDescriptorMatchGroup(page: page, matches: entries.map(\.1).sorted(by: orderedBefore))
        }
    }

    private static func orderedBefore(_ lhs: SettingsSearchDescriptorMatch, _ rhs: SettingsSearchDescriptorMatch) -> Bool {
        if lhs.score == rhs.score {
            let titleOrder = lhs.descriptor.title.localizedStandardCompare(rhs.descriptor.title)
            if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
            return lhs.descriptor.id.localizedStandardCompare(rhs.descriptor.id) == .orderedAscending
        }
        return lhs.score > rhs.score
    }

    private static func score(query: String, descriptor: SettingsSearchDescriptor) -> Double? {
        let scores = descriptor.searchableStrings.compactMap { SettingsSearch.match(query, in: $0)?.score }
        guard let best = scores.max() else { return nil }
        if SettingsSearch.match(query, in: descriptor.title) != nil { return best + 0.01 }
        return best
    }
}
