import Foundation

private typealias FocusSetsJSONObject = [String: Any]

private struct ParsedFocusSetsConfiguration {
    let configuration: FocusSetsConfiguration
    let rawRoot: FocusSetsJSONObject?
}

private struct FocusSetsRuleIdentity: Hashable {
    let applicationBundleIdentifier: String

    init(_ rule: FocusSetRule) {
        applicationBundleIdentifier = rule.applicationBundleIdentifier
    }
}

private struct FocusSetsStoreParser {
    static func parse(_ string: String?) -> ParsedFocusSetsConfiguration {
        guard let string, let data = string.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? FocusSetsJSONObject else {
            return ParsedFocusSetsConfiguration(configuration: FocusSetsConfiguration(), rawRoot: nil)
        }
        return ParsedFocusSetsConfiguration(configuration: configuration(from: root), rawRoot: root)
    }

    private static func configuration(from root: FocusSetsJSONObject) -> FocusSetsConfiguration {
        let version = validVersion(root["version"]) ?? FocusSetsConfiguration.currentVersion
        let presentationShortcutIdentifier = root["presentationShortcutIdentifier"] as? String ?? ""
        let sets = (root["sets"] as? [Any] ?? []).compactMap(focusSet)
        return FocusSetsConfiguration(
            version: version,
            presentationShortcutIdentifier: presentationShortcutIdentifier,
            sets: sets
        )
    }

    private static func focusSet(_ value: Any) -> FocusSet? {
        guard let object = value as? FocusSetsJSONObject,
              let identifierString = object["id"] as? String,
              let identifier = UUID(uuidString: identifierString),
              let name = object["name"] as? String,
              let rawRules = object["rules"] as? [Any] else { return nil }
        return FocusSet(id: identifier, name: name, rules: rawRules.compactMap(decodedRule))
    }

    static func decodedRule(_ value: Any) -> FocusSetRule? {
        guard let object = value as? FocusSetsJSONObject,
              let applicationBundleIdentifier = object["applicationBundleIdentifier"] as? String,
              !applicationBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let cachedApplicationName = object["cachedApplicationName"] as? String ?? applicationBundleIdentifier
        return FocusSetRule(
            applicationBundleIdentifier: applicationBundleIdentifier,
            cachedApplicationName: cachedApplicationName,
            titleContains: object["titleContains"] as? String
        )
    }

    private static func validVersion(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let version = number.intValue
        guard number.doubleValue == Double(version), version > 0 else { return nil }
        return version
    }
}

final class FocusSetsStore {
    static var defaultKey: String { Preferences.focusSetsKey }

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = Preferences.focusSetsKey) {
        self.defaults = defaults
        self.key = key
    }

    func read(availableShortcutIdentifiers: [String]) -> FocusSetsConfiguration {
        let parsed = FocusSetsStoreParser.parse(defaults.string(forKey: key))
        let configuration = normalized(parsed.configuration, availableShortcutIdentifiers: availableShortcutIdentifiers)
        guard parsed.rawRoot != nil, configuration != parsed.configuration else { return configuration }
        _ = set(configuration, availableShortcutIdentifiers: availableShortcutIdentifiers)
        return configuration
    }

    @discardableResult
    func set(_ configuration: FocusSetsConfiguration, availableShortcutIdentifiers: [String]) -> Bool {
        let configuration = normalized(configuration, availableShortcutIdentifiers: availableShortcutIdentifiers)
        let parsed = FocusSetsStoreParser.parse(defaults.string(forKey: key))
        let object = encoded(configuration, preserving: parsed.rawRoot)
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return false }
        defaults.set(string, forKey: key)
        Preferences.invalidateAllCache()
        return true
    }

    private func normalized(_ configuration: FocusSetsConfiguration,
                            availableShortcutIdentifiers: [String]) -> FocusSetsConfiguration {
        let version = configuration.version > 0 ? configuration.version : FocusSetsConfiguration.currentVersion
        let presentationShortcutIdentifier = normalizedPresentationShortcutIdentifier(
            configuration.presentationShortcutIdentifier,
            availableShortcutIdentifiers: availableShortcutIdentifiers
        )
        var identifiers = Set<UUID>()
        let sets = configuration.sets.compactMap { focusSet -> FocusSet? in
            guard identifiers.insert(focusSet.id).inserted else { return nil }
            return FocusSet(
                id: focusSet.id,
                name: focusSet.name,
                rules: focusSet.rules.filter(valid)
            )
        }
        return FocusSetsConfiguration(
            version: version,
            presentationShortcutIdentifier: presentationShortcutIdentifier,
            sets: sets
        )
    }

    private func normalizedPresentationShortcutIdentifier(_ identifier: String,
                                                           availableShortcutIdentifiers: [String]) -> String {
        let identifiers = availableShortcutIdentifiers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let first = identifiers.first else { return identifier }
        return identifiers.contains(identifier) ? identifier : first
    }

    private func valid(_ rule: FocusSetRule) -> Bool {
        !rule.applicationBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func encoded(_ configuration: FocusSetsConfiguration,
                         preserving rawRoot: FocusSetsJSONObject?) -> FocusSetsJSONObject {
        var object = rawRoot ?? [:]
        object["version"] = configuration.version
        object["presentationShortcutIdentifier"] = configuration.presentationShortcutIdentifier
        object["sets"] = encodedSets(configuration.sets, preserving: rawRoot)
        return object
    }

    private func encodedSets(_ sets: [FocusSet],
                             preserving rawRoot: FocusSetsJSONObject?) -> [Any] {
        let rawSets = rawSetsByIdentifier(from: rawRoot)
        let setCounts = counts(sets.map(\.id))
        return sets.map { focusSet in
            let candidates = rawSets[focusSet.id] ?? []
            let rawSet = setCounts[focusSet.id] == 1 && candidates.count == 1 ? candidates.first : nil
            return encoded(focusSet, preserving: rawSet)
        }
    }

    private func encoded(_ focusSet: FocusSet,
                         preserving rawSet: FocusSetsJSONObject?) -> FocusSetsJSONObject {
        var object = rawSet ?? [:]
        object["id"] = focusSet.id.uuidString
        object["name"] = focusSet.name
        object["rules"] = encodedRules(focusSet.rules, preserving: rawSet)
        return object
    }

    private func encodedRules(_ rules: [FocusSetRule],
                              preserving rawSet: FocusSetsJSONObject?) -> [Any] {
        let rawRules = rawRulesByIdentity(from: rawSet)
        let ruleCounts = counts(rules.map(FocusSetsRuleIdentity.init))
        return rules.map { rule in
            let identity = FocusSetsRuleIdentity(rule)
            let candidates = rawRules[identity] ?? []
            let rawRule = ruleCounts[identity] == 1 && candidates.count == 1 ? candidates.first : nil
            return encoded(rule, preserving: rawRule)
        }
    }

    private func encoded(_ rule: FocusSetRule,
                         preserving rawRule: FocusSetsJSONObject?) -> FocusSetsJSONObject {
        var object = rawRule ?? [:]
        object["applicationBundleIdentifier"] = rule.applicationBundleIdentifier
        object["cachedApplicationName"] = rule.cachedApplicationName
        if let titleContains = rule.titleContains {
            object["titleContains"] = titleContains
        } else {
            object.removeValue(forKey: "titleContains")
        }
        return object
    }

    private func rawSetsByIdentifier(from root: FocusSetsJSONObject?) -> [UUID: [FocusSetsJSONObject]] {
        guard let rawSets = root?["sets"] as? [Any] else { return [:] }
        var sets = [UUID: [FocusSetsJSONObject]]()
        for rawSet in rawSets {
            guard let object = rawSet as? FocusSetsJSONObject,
                  let identifierString = object["id"] as? String,
                  let identifier = UUID(uuidString: identifierString) else { continue }
            sets[identifier, default: []].append(object)
        }
        return sets
    }

    private func rawRulesByIdentity(from rawSet: FocusSetsJSONObject?) -> [FocusSetsRuleIdentity: [FocusSetsJSONObject]] {
        guard let rawRules = rawSet?["rules"] as? [Any] else { return [:] }
        var rules = [FocusSetsRuleIdentity: [FocusSetsJSONObject]]()
        for rawRule in rawRules {
            guard let object = rawRule as? FocusSetsJSONObject,
                  let rule = FocusSetsStoreParser.decodedRule(object) else { continue }
            rules[FocusSetsRuleIdentity(rule), default: []].append(object)
        }
        return rules
    }

    private func counts<T: Hashable>(_ values: [T]) -> [T: Int] {
        var counts = [T: Int]()
        for value in values {
            counts[value, default: 0] += 1
        }
        return counts
    }
}
