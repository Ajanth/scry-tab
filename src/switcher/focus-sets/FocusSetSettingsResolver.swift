import Foundation

struct FocusSetApplicationIdentity: Hashable {
    fileprivate let bundleIdentifier: String

    fileprivate init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
    }

    fileprivate var isValid: Bool {
        !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct FocusSetApplicationOption: Equatable {
    let identity: FocusSetApplicationIdentity
    let presentationName: String

    init(bundleIdentifier: String, presentationName: String) {
        identity = FocusSetApplicationIdentity(bundleIdentifier: bundleIdentifier)
        self.presentationName = presentationName
    }
}

struct FocusSetApplicationPickerRow: Equatable {
    let identity: FocusSetApplicationIdentity
    let presentationName: String
    let isSelected: Bool
    let isAvailable: Bool
}

enum FocusSetSettingsResolver {
    private struct SavedApplication {
        let identity: FocusSetApplicationIdentity
        let presentationName: String
    }

    static func selectedFocusSetIdentifier(preferredIdentifier: UUID?,
                                           sets: [FocusSet]) -> UUID? {
        guard let preferredIdentifier,
              sets.contains(where: { $0.id == preferredIdentifier }) else {
            return sets.first?.id
        }
        return preferredIdentifier
    }

    static func applicationPickerRows(applications: [FocusSetApplicationOption],
                                      rules: [FocusSetRule]) -> [FocusSetApplicationPickerRow] {
        let availableApplications = uniqueApplications(applications)
        let savedApplications = uniqueSavedApplications(rules)
        let applicationsByIdentity = applicationsByIdentity(availableApplications)
        let selectedIdentities = Set(savedApplications.map(\.identity))
        let selectedRows = savedApplications.map { savedApplication -> FocusSetApplicationPickerRow in
            guard let application = applicationsByIdentity[savedApplication.identity] else {
                return FocusSetApplicationPickerRow(
                    identity: savedApplication.identity,
                    presentationName: savedApplication.presentationName,
                    isSelected: true,
                    isAvailable: false)
            }
            return FocusSetApplicationPickerRow(
                identity: application.identity,
                presentationName: application.presentationName,
                isSelected: true,
                isAvailable: true)
        }
        let availableRows = availableApplications.compactMap { application -> FocusSetApplicationPickerRow? in
            guard !selectedIdentities.contains(application.identity) else { return nil }
            return FocusSetApplicationPickerRow(
                identity: application.identity,
                presentationName: application.presentationName,
                isSelected: false,
                isAvailable: true)
        }
        return (selectedRows + availableRows).sorted { isOrderedBefore($0, $1) }
    }

    static func rules(selectedApplicationIdentities: Set<FocusSetApplicationIdentity>,
                      applications: [FocusSetApplicationOption],
                      existingRules: [FocusSetRule]) -> [FocusSetRule] {
        let availableApplications = uniqueApplications(applications)
        let savedApplications = uniqueSavedApplications(existingRules)
        let availableApplicationsByIdentity = applicationsByIdentity(availableApplications)
        let savedApplicationsByIdentity = savedApplicationsByIdentity(savedApplications)
        let selectedApplications = selectedApplicationIdentities.compactMap { identity -> SavedApplication? in
            guard identity.isValid else { return nil }
            if let application = availableApplicationsByIdentity[identity] {
                return SavedApplication(identity: identity, presentationName: application.presentationName)
            }
            return savedApplicationsByIdentity[identity]
        }
        return selectedApplications
            .sorted { isOrderedBefore($0, $1) }
            .map {
                FocusSetRule(
                    applicationBundleIdentifier: $0.identity.bundleIdentifier,
                    cachedApplicationName: $0.presentationName)
            }
    }

    private static func uniqueApplications(_ applications: [FocusSetApplicationOption]) -> [FocusSetApplicationOption] {
        var identities = Set<FocusSetApplicationIdentity>()
        var uniqueApplications = [FocusSetApplicationOption]()
        for application in applications {
            guard application.identity.isValid, identities.insert(application.identity).inserted else { continue }
            uniqueApplications.append(application)
        }
        return uniqueApplications
    }

    private static func uniqueSavedApplications(_ rules: [FocusSetRule]) -> [SavedApplication] {
        var identities = Set<FocusSetApplicationIdentity>()
        var savedApplications = [SavedApplication]()
        for rule in rules {
            let identity = FocusSetApplicationIdentity(bundleIdentifier: rule.applicationBundleIdentifier)
            guard identity.isValid, identities.insert(identity).inserted else { continue }
            savedApplications.append(
                SavedApplication(identity: identity, presentationName: savedPresentationName(rule)))
        }
        return savedApplications
    }

    private static func savedPresentationName(_ rule: FocusSetRule) -> String {
        let name = rule.cachedApplicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name == rule.applicationBundleIdentifier ? "" : name
    }

    private static func applicationsByIdentity(_ applications: [FocusSetApplicationOption])
        -> [FocusSetApplicationIdentity: FocusSetApplicationOption] {
        var applicationsByIdentity = [FocusSetApplicationIdentity: FocusSetApplicationOption]()
        for application in applications {
            applicationsByIdentity[application.identity] = application
        }
        return applicationsByIdentity
    }

    private static func savedApplicationsByIdentity(_ applications: [SavedApplication])
        -> [FocusSetApplicationIdentity: SavedApplication] {
        var applicationsByIdentity = [FocusSetApplicationIdentity: SavedApplication]()
        for application in applications {
            applicationsByIdentity[application.identity] = application
        }
        return applicationsByIdentity
    }

    private static func isOrderedBefore(_ lhs: FocusSetApplicationPickerRow,
                                        _ rhs: FocusSetApplicationPickerRow) -> Bool {
        guard lhs.isSelected == rhs.isSelected else { return lhs.isSelected }
        return isOrderedBefore(
            lhs.presentationName,
            lhs.identity,
            rhs.presentationName,
            rhs.identity)
    }

    private static func isOrderedBefore(_ lhs: SavedApplication,
                                        _ rhs: SavedApplication) -> Bool {
        isOrderedBefore(lhs.presentationName, lhs.identity, rhs.presentationName, rhs.identity)
    }

    private static func isOrderedBefore(_ lhsName: String,
                                        _ lhsIdentity: FocusSetApplicationIdentity,
                                        _ rhsName: String,
                                        _ rhsIdentity: FocusSetApplicationIdentity) -> Bool {
        let comparison = lhsName.localizedStandardCompare(rhsName)
        guard comparison == .orderedSame else { return comparison == .orderedAscending }
        return lhsIdentity.bundleIdentifier < rhsIdentity.bundleIdentifier
    }
}
