import Foundation
import XCTest

final class FocusSetResolverTests: XCTestCase {

    // MARK: - A. Model persistence

    /// A new configuration starts at the current format version with no saved sets.
    func testConfigurationDefaultsToCurrentVersionAndEmptyValues() {
        let configuration = FocusSetsConfiguration()

        XCTAssertEqual(configuration.version, FocusSetsConfiguration.currentVersion)
        XCTAssertEqual(configuration.sets, [])
    }

    /// Every model field round-trips through JSON for a separate persistence store.
    func testConfigurationRoundTripsThroughJSONForPersistence() throws {
        let configuration = FocusSetsConfiguration(
            sets: [
                FocusSet(
                    name: "Coding",
                    rules: [
                        FocusSetRule(
                            applicationBundleIdentifier: "com.example.editor",
                            cachedApplicationName: "Example Editor",
                            titleContains: "scry-tab")
                    ],
                    shortcutKeyEquivalent: "⌃1")
            ])

        let decoded = try JSONDecoder().decode(
            FocusSetsConfiguration.self,
            from: JSONEncoder().encode(configuration))

        XCTAssertEqual(decoded, configuration)
    }

    /// Encoded configuration retains only stable Focus Set fields.
    func testConfigurationEncodingContainsOnlyStableFocusSetFields() throws {
        let configuration = FocusSetsConfiguration(
            sets: [
                FocusSet(
                    name: "Coding",
                    rules: [
                        FocusSetRule(
                            applicationBundleIdentifier: "com.example.editor",
                            cachedApplicationName: "Example Editor",
                            titleContains: "scry-tab")
                    ],
                    shortcutKeyEquivalent: "⌃1")
            ])

        let data = try JSONEncoder().encode(configuration)
        guard let configurationObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let setObject = (configurationObject["sets"] as? [[String: Any]])?.first,
              let ruleObject = (setObject["rules"] as? [[String: Any]])?.first else {
            return XCTFail("Expected encoded Focus Set fields")
        }

        XCTAssertEqual(
            Set(configurationObject.keys),
            Set(["version", "sets"]))
        XCTAssertEqual(Set(setObject.keys), Set(["id", "name", "rules", "shortcutKeyEquivalent"]))
        XCTAssertEqual(
            Set(ruleObject.keys),
            Set(["applicationBundleIdentifier", "cachedApplicationName", "titleContains"]))
    }

    // MARK: - B. Unconstrained scopes

    /// No Focus Set scope preserves every app, even when it lacks a stable bundle identifier.
    func testNoScopeIncludesAppsWithAndWithoutBundleIdentifiers() {
        let resolver = makeResolver()

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .none))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: nil, scope: .none))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "", scope: .none))
    }

    /// All Windows preserves every app, even when it lacks a stable bundle identifier.
    func testAllWindowsIncludesAppsWithAndWithoutBundleIdentifiers() {
        let resolver = makeResolver()

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .allWindows))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: nil, scope: .allWindows))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "", scope: .allWindows))
    }

    // MARK: - C. Selected Focus Set membership

    /// A selected app includes each of its current and future windows by exact bundle identifier.
    func testSetScopeIncludesAllWindowsFromSelectedApp() {
        let setID = UUID()
        let resolver = makeResolver(sets: [makeSet(id: setID, rules: [makeRule("com.example.editor")])])

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
    }

    /// Selected-set membership is case-sensitive and does not use prefix or suffix matching.
    func testSetScopeMatchesOnlyExactBundleIdentifiers() {
        let setID = UUID()
        let resolver = makeResolver(sets: [makeSet(id: setID, rules: [makeRule("com.example.editor")])])

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.editor.beta", scope: .set(id: setID)))
        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.Editor", scope: .set(id: setID)))
    }

    /// A selected Focus Set cannot match an app without a non-empty stable bundle identifier.
    func testSetScopeRejectsMissingBundleIdentifiers() {
        let setID = UUID()
        let resolver = makeResolver(sets: [makeSet(id: setID, rules: [makeRule("com.example.editor")])])

        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: nil, scope: .set(id: setID)))
        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "", scope: .set(id: setID)))
    }

    /// Multiple rules in one Focus Set are alternatives rather than cumulative requirements.
    func testRulesWithinASetUseOrSemantics() {
        let setID = UUID()
        let resolver = makeResolver(
            sets: [
                makeSet(
                    id: setID,
                    rules: [
                        makeRule("com.example.editor"),
                        makeRule("com.example.terminal")
                    ])
            ])

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.terminal", scope: .set(id: setID)))
        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.browser", scope: .set(id: setID)))
    }

    /// A saved display name is presentation-only and cannot stand in for app identity.
    func testCachedApplicationNameDoesNotAffectMembership() {
        let setID = UUID()
        let resolver = makeResolver(
            sets: [
                makeSet(
                    id: setID,
                    rules: [
                        FocusSetRule(
                            applicationBundleIdentifier: "com.example.editor",
                            cachedApplicationName: "Unavailable Example Editor")
                    ])
            ])

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
        XCTAssertFalse(
            resolver.matchesApp(
                bundleIdentifier: "Unavailable Example Editor",
                scope: .set(id: setID)))
    }

    /// Title narrowing remains inert until a later Focus Sets release adds it deliberately.
    func testTitleContainsDoesNotNarrowV1AppMembership() {
        let setID = UUID()
        let resolver = makeResolver(
            sets: [
                makeSet(
                    id: setID,
                    rules: [
                        FocusSetRule(
                            applicationBundleIdentifier: "com.example.editor",
                            cachedApplicationName: "Example Editor",
                            titleContains: "different project")
                    ])
            ])

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
    }

    // MARK: - D. Unassigned and overlap

    /// Unassigned excludes an app present in any saved Focus Set and includes other identified apps.
    func testUnassignedExcludesAppsInEverySavedFocusSet() {
        let resolver = makeResolver(
            sets: [
                makeSet(id: UUID(), rules: [makeRule("com.example.editor")]),
                makeSet(id: UUID(), rules: [makeRule("com.example.terminal")])
            ])

        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .unassigned))
        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.terminal", scope: .unassigned))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.browser", scope: .unassigned))
    }

    /// Apps without stable identity cannot be assigned to a saved set and are therefore unassigned.
    func testUnassignedIncludesAppsWithoutBundleIdentifiers() {
        let resolver = makeResolver(sets: [makeSet(id: UUID(), rules: [makeRule("com.example.editor")])])

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: nil, scope: .unassigned))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "", scope: .unassigned))
    }

    /// Overlapping Focus Sets intentionally include a shared app in each selected scope.
    func testOverlappingSetsIncludeSharedAppsInEachScope() {
        let firstSetID = UUID()
        let secondSetID = UUID()
        let resolver = makeResolver(
            sets: [
                makeSet(id: firstSetID, rules: [makeRule("com.example.editor")]),
                makeSet(
                    id: secondSetID,
                    rules: [
                        makeRule("com.example.editor"),
                        makeRule("com.example.terminal")
                    ])
            ])

        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: firstSetID)))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: secondSetID)))
        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .unassigned))
    }

    // MARK: - E. Invalid and empty membership

    /// An empty selected Focus Set has no matching apps while identified apps remain unassigned.
    func testEmptySetProducesNoSelectedMembership() {
        let setID = UUID()
        let resolver = makeResolver(sets: [makeSet(id: setID, rules: [])])

        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .unassigned))
    }

    /// A stale selected-set identifier has no membership instead of falling back to another set.
    func testUnknownSetProducesNoMembership() {
        let resolver = makeResolver(sets: [makeSet(id: UUID(), rules: [makeRule("com.example.editor")])])

        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: UUID())))
    }

    /// Blank persisted rule identifiers do not create selected or assigned membership.
    func testBlankRuleBundleIdentifierIsIgnored() {
        let setID = UUID()
        let resolver = makeResolver(sets: [makeSet(id: setID, rules: [makeRule("")])])

        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.example.editor", scope: .unassigned))
    }

    /// A resolver keeps compiled facts after another configuration snapshot is built.
    func testResolverRetainsItsCompiledSnapshot() {
        let setID = UUID()
        let original = makeResolver(sets: [makeSet(id: setID, rules: [makeRule("com.example.editor")])])
        let replacement = makeResolver()

        XCTAssertTrue(original.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
        XCTAssertFalse(replacement.matchesApp(bundleIdentifier: "com.example.editor", scope: .set(id: setID)))
    }

    // MARK: - F. Direct shortcut bindings

    /// Binding resolution emits only saved sets with non-empty direct shortcuts and stable UUID action identifiers.
    func testShortcutBindingsResolveSavedIdentifiersAndSkipMissingValues() {
        let bound = FocusSet(id: UUID(), name: "Coding", rules: [], shortcutKeyEquivalent: "⌃1")
        let unbound = FocusSet(id: UUID(), name: "Writing", rules: [])

        let bindings = FocusSetShortcutBindingResolver.bindings(
            in: FocusSetsConfiguration(sets: [bound, unbound]))

        XCTAssertEqual(bindings, [
            FocusSetShortcutBinding(
                focusSetIdentifier: bound.id,
                actionIdentifier: FocusSetShortcutBindingResolver.actionIdentifier(for: bound.id),
                keyEquivalent: "⌃1",
                name: "Coding")
        ])
        XCTAssertEqual(
            FocusSetShortcutBindingResolver.focusSetIdentifier(from: bindings[0].actionIdentifier),
            bound.id)
    }

    /// A deleted action identifier cannot decode as another Focus Set identifier.
    func testShortcutActionIdentifierPreservesExactStableIdentifier() {
        let deletedIdentifier = UUID()
        let retainedIdentifier = UUID()
        let deletedAction = FocusSetShortcutBindingResolver.actionIdentifier(for: deletedIdentifier)

        XCTAssertEqual(
            FocusSetShortcutBindingResolver.focusSetIdentifier(from: deletedAction),
            deletedIdentifier)
        XCTAssertNotEqual(
            FocusSetShortcutBindingResolver.focusSetIdentifier(from: deletedAction),
            retainedIdentifier)
        XCTAssertNil(FocusSetShortcutBindingResolver.focusSetIdentifier(from: "focusSetShortcut:not-a-uuid"))
    }

    private func makeResolver(sets: [FocusSet] = []) -> FocusSetResolver {
        FocusSetResolver(configuration: FocusSetsConfiguration(sets: sets))
    }

    private func makeSet(id: UUID, rules: [FocusSetRule]) -> FocusSet {
        FocusSet(id: id, name: "Example", rules: rules)
    }

    private func makeRule(_ applicationBundleIdentifier: String) -> FocusSetRule {
        FocusSetRule(
            applicationBundleIdentifier: applicationBundleIdentifier,
            cachedApplicationName: "Example App")
    }
}
