import Foundation
import XCTest

final class FocusSetSettingsResolverTests: XCTestCase {

    // MARK: - A. Application picker rows

    /// Selected applications precede other available applications while both groups remain alphabetical.
    func testPickerRowsPlaceSelectedAppsBeforeOtherAvailableApps() {
        let applications = [
            application("com.example.safari", "Safari"),
            application("com.example.terminal", "Terminal"),
            application("com.example.cursor", "Cursor"),
        ]

        let rows = FocusSetSettingsResolver.applicationPickerRows(
            applications: applications,
            rules: [
                rule("com.example.terminal", "Terminal"),
                rule("com.example.cursor", "Cursor"),
            ])

        XCTAssertEqual(rows.map(\.presentationName), ["Cursor", "Terminal", "Safari"])
        XCTAssertEqual(rows.map(\.isSelected), [true, true, false])
        XCTAssertEqual(rows.map(\.isAvailable), [true, true, true])
    }

    /// A selected saved application remains editable when it is no longer available live.
    func testPickerRowsKeepUnavailableSavedApplicationsSelected() {
        let rows = FocusSetSettingsResolver.applicationPickerRows(
            applications: [application("com.example.terminal", "Terminal")],
            rules: [rule("com.example.cursor", "Saved Cursor")])

        XCTAssertEqual(rows.map(\.presentationName), ["Saved Cursor", "Terminal"])
        XCTAssertEqual(rows.map(\.isSelected), [true, false])
        XCTAssertEqual(rows.map(\.isAvailable), [false, true])
    }

    /// Duplicate identities retain the first live name while blank live and saved identities disappear.
    func testPickerRowsDeduplicateIdentitiesAndIgnoreBlankIdentifiers() {
        let applications = [
            application("com.example.terminal", "Terminal"),
            application("com.example.terminal", "Renamed Terminal"),
            application(" \n", "Ignored Live Application"),
            application("com.example.browser", "Browser"),
        ]
        let rows = FocusSetSettingsResolver.applicationPickerRows(
            applications: applications,
            rules: [
                rule("com.example.terminal", "Old Terminal"),
                rule("com.example.terminal", "Older Terminal"),
                rule("\t", "Ignored Saved Application"),
            ])
        let convertedRules = FocusSetSettingsResolver.rules(
            selectedApplicationIdentities: Set([applications[0].identity, applications[2].identity]),
            applications: applications,
            existingRules: [
                rule("com.example.terminal", "Old Terminal"),
                rule("\t", "Ignored Saved Application"),
            ])

        XCTAssertEqual(rows.map(\.presentationName), ["Terminal", "Browser"])
        XCTAssertEqual(rows.map(\.isSelected), [true, false])
        XCTAssertEqual(convertedRules.map(\.applicationBundleIdentifier), ["com.example.terminal"])
    }

    /// Merging running and installed catalogs keeps the first presentation for a bundle and retains unique installed apps.
    func testMergedApplicationOptionsKeepFirstCatalogEntryPerIdentity() {
        let runningApplications = [application("com.example.antigravity", "Antigravity")]
        let installedApplications = [
            application("com.example.antigravity", "Antigravity Installed"),
            application("com.example.terminal", "Terminal"),
        ]

        let merged = FocusSetSettingsResolver.mergedApplicationOptions([
            runningApplications,
            installedApplications,
        ])

        XCTAssertEqual(merged.map(\.presentationName), ["Antigravity", "Terminal"])
    }

    /// A legacy cached fallback that equals its stable identity remains unavailable without becoming a picker name.
    func testPickerRowsOmitFallbackBundleIdentifierAsPresentationName() {
        let rows = FocusSetSettingsResolver.applicationPickerRows(
            applications: [],
            rules: [rule("com.example.cursor", "com.example.cursor")])

        XCTAssertEqual(rows.map(\.presentationName), [""])
        XCTAssertEqual(rows.map(\.isAvailable), [false])
    }

    /// Localized-standard names and stable identities make the picker order reproducible.
    func testPickerRowsUseDeterministicLocalizedStandardOrder() {
        let applications = [
            application("com.example.same-z", "Same"),
            application("com.example.same-a", "Same"),
            application("com.example.app-10", "App 10"),
            application("com.example.app-2", "App 2"),
        ]

        let rows = FocusSetSettingsResolver.applicationPickerRows(applications: applications, rules: [])

        XCTAssertEqual(rows.map(\.presentationName), ["App 2", "App 10", "Same", "Same"])
        XCTAssertEqual(Array(rows.suffix(2).map(\.identity)), [applications[1].identity, applications[0].identity])
    }

    /// Picker search trims its query and matches application names regardless of case or diacritics.
    func testPickerRowsFilterNamesCaseAndDiacriticInsensitively() {
        let rows = FocusSetSettingsResolver.filteredApplicationPickerRows(
            applications: [
                application("com.example.cursor", "Cúrsor"),
                application("com.example.terminal", "Terminal"),
            ],
            rules: [],
            matching: " CURSOR \n")

        XCTAssertEqual(rows.map(\.presentationName), ["Cúrsor"])
    }

    /// Included-app totals count each valid stable identity once.
    func testIncludedApplicationCountDeduplicatesRulesAndIgnoresBlankIdentifiers() {
        let count = FocusSetSettingsResolver.includedApplicationCount([
            rule("com.example.cursor", "Cursor"),
            rule("com.example.cursor", "Cursor project", titleContains: "project"),
            rule(" \n", "Ignored"),
            rule("com.example.terminal", "Terminal"),
        ])

        XCTAssertEqual(count, 2)
    }

    // MARK: - B. Rule conversion

    /// A live presentation-name change refreshes the cached name and emits an app-only rule.
    func testRulesUseLiveNameAndRemainAppOnly() {
        let applications = [application("com.example.cursor", "Cursor Nightly")]
        let rules = FocusSetSettingsResolver.rules(
            selectedApplicationIdentities: Set([applications[0].identity]),
            applications: applications,
            existingRules: [
                rule(
                    "com.example.cursor",
                    "Cursor",
                    titleContains: "project")
            ])

        XCTAssertEqual(
            rules,
            [FocusSetRule(
                applicationBundleIdentifier: "com.example.cursor",
                cachedApplicationName: "Cursor Nightly")])
    }

    /// A selected unavailable application retains its previously saved presentation name.
    func testRulesRetainSavedNameForSelectedUnavailableApplication() {
        let existingRules = [rule("com.example.terminal", "Saved Terminal")]
        let rows = FocusSetSettingsResolver.applicationPickerRows(
            applications: [],
            rules: existingRules)
        let rules = FocusSetSettingsResolver.rules(
            selectedApplicationIdentities: Set(rows.map(\.identity)),
            applications: [],
            existingRules: existingRules)

        XCTAssertEqual(rules, existingRules)
    }

    /// Deselecting an existing application removes only that app from the rewritten rules.
    func testRulesDropDeselectedApplications() {
        let applications = [
            application("com.example.cursor", "Cursor"),
            application("com.example.terminal", "Terminal"),
        ]
        let rules = FocusSetSettingsResolver.rules(
            selectedApplicationIdentities: Set([applications[0].identity]),
            applications: applications,
            existingRules: [
                rule("com.example.cursor", "Old Cursor"),
                rule("com.example.terminal", "Old Terminal"),
            ])

        XCTAssertEqual(
            rules,
            [FocusSetRule(
                applicationBundleIdentifier: "com.example.cursor",
                cachedApplicationName: "Cursor")])
    }

    // MARK: - C. Focus Set deletion

    /// Deletion removes only the requested stable UUID and leaves no direct shortcut binding for it.
    func testDeletingFocusSetRemovesOnlyRequestedStableIdentifier() throws {
        let retained = focusSet("Same name")
        let deleted = focusSet("Same name", shortcutKeyEquivalent: "⌃1")
        let trailing = focusSet("Trailing")
        let configuration = FocusSetsConfiguration(
            version: 3,
            sets: [retained, deleted, trailing])

        let next = try XCTUnwrap(FocusSetSettingsResolver.configurationByDeletingFocusSet(deleted.id, from: configuration))

        XCTAssertEqual(next.version, configuration.version)
        XCTAssertEqual(next.sets.map(\.id), [retained.id, trailing.id])
        XCTAssertFalse(FocusSetShortcutBindingResolver.bindings(in: next).contains { $0.focusSetIdentifier == deleted.id })
    }

    /// An unknown stable UUID cannot produce a deletion configuration.
    func testDeletingFocusSetRejectsUnknownStableIdentifier() {
        let configuration = FocusSetsConfiguration(sets: [focusSet("Retained")])

        XCTAssertNil(FocusSetSettingsResolver.configurationByDeletingFocusSet(UUID(), from: configuration))
    }

    // MARK: - D. Focus Set reordering

    /// Moving a saved Focus Set swaps it with its adjacent destination.
    func testMovedFocusSetsSwapsAdjacentSets() {
        let first = focusSet("First")
        let second = focusSet("Second")
        let third = focusSet("Third")

        let movedDown = FocusSetSettingsResolver.movedFocusSets(
            moving: second.id,
            by: 1,
            in: [first, second, third])
        let movedUp = FocusSetSettingsResolver.movedFocusSets(
            moving: second.id,
            by: -1,
            in: [first, second, third])

        XCTAssertEqual(movedDown?.map(\.id), [first.id, third.id, second.id])
        XCTAssertEqual(movedUp?.map(\.id), [second.id, first.id, third.id])
    }

    /// Unknown, zero-offset, and out-of-range moves preserve the saved order.
    func testMovedFocusSetsRejectsMissingOrInvalidDestinations() {
        let first = focusSet("First")
        let second = focusSet("Second")
        let sets = [first, second]

        XCTAssertNil(FocusSetSettingsResolver.movedFocusSets(moving: UUID(), by: 1, in: sets))
        XCTAssertNil(FocusSetSettingsResolver.movedFocusSets(moving: first.id, by: 0, in: sets))
        XCTAssertNil(FocusSetSettingsResolver.movedFocusSets(moving: first.id, by: -1, in: sets))
        XCTAssertNil(FocusSetSettingsResolver.movedFocusSets(moving: second.id, by: 1, in: sets))
    }

    // MARK: - E. Focus Set selection

    /// A selected focus set remains selected when another set is removed.
    func testSelectedFocusSetIdentifierKeepsExistingSet() {
        let first = focusSet("First")
        let selected = focusSet("Selected")

        let identifier = FocusSetSettingsResolver.selectedFocusSetIdentifier(
            preferredIdentifier: selected.id,
            sets: [first, selected])

        XCTAssertEqual(identifier, selected.id)
    }

    /// Deleting the selected focus set chooses the first remaining set.
    func testSelectedFocusSetIdentifierFallsBackToFirstRemainingSet() {
        let deleted = focusSet("Deleted")
        let remaining = focusSet("Remaining")

        let identifier = FocusSetSettingsResolver.selectedFocusSetIdentifier(
            preferredIdentifier: deleted.id,
            sets: [remaining])

        XCTAssertEqual(identifier, remaining.id)
    }

    /// Deleting the last focus set clears selection instead of retaining a stale identifier.
    func testSelectedFocusSetIdentifierClearsAfterDeletingLastSet() {
        let deleted = focusSet("Deleted")

        let identifier = FocusSetSettingsResolver.selectedFocusSetIdentifier(
            preferredIdentifier: deleted.id,
            sets: [])

        XCTAssertNil(identifier)
    }

    // MARK: - F. Transactional editor decisions

    /// Applying an edit replaces name, applications, and shortcut together while preserving configuration metadata and order.
    func testSavingFocusSetCommitsCompleteDraftAtomically() {
        let original = FocusSet(
            name: "Original",
            rules: [rule("com.example.old", "Old")],
            shortcutKeyEquivalent: "⌃1")
        let trailing = focusSet("Trailing")
        let draft = FocusSet(
            id: original.id,
            name: "Updated",
            rules: [rule("com.example.new", "New")],
            shortcutKeyEquivalent: "⌃2")
        let configuration = FocusSetsConfiguration(
            version: 4,
            sets: [original, trailing])

        let next = FocusSetSettingsResolver.configurationBySavingFocusSet(
            draft,
            unassigningShortcutActionIdentifier: nil,
            in: configuration)

        XCTAssertEqual(next.version, 4)
        XCTAssertEqual(next.sets, [draft, trailing])
    }

    /// Applying a conflicting direct shortcut clears only the other set's binding in the same configuration decision.
    func testSavingFocusSetUnassignsConflictingDirectBindingWithoutChangingMembership() {
        let conflicting = FocusSet(
            name: "Existing",
            rules: [rule("com.example.existing", "Existing")],
            shortcutKeyEquivalent: "⌃1")
        let draft = FocusSet(name: "New", rules: [], shortcutKeyEquivalent: "⌃1")
        let configuration = FocusSetsConfiguration(sets: [conflicting])

        let next = FocusSetSettingsResolver.configurationBySavingFocusSet(
            draft,
            unassigningShortcutActionIdentifier: FocusSetShortcutBindingResolver.actionIdentifier(for: conflicting.id),
            in: configuration)

        XCTAssertEqual(next.sets[0].rules, conflicting.rules)
        XCTAssertNil(next.sets[0].shortcutKeyEquivalent)
        XCTAssertEqual(next.sets[1], draft)
    }

    // MARK: - G. Category search registration

    /// Category content maps behavior and Focus Sets queries to their own segments, then clears on teardown.
    func testCategorySearchRegistrationHighlightsMatchingSegmentAndClearsOnCleanup() throws {
        let marker = NSObject()
        let identifier = ObjectIdentifier(marker)
        let labels = ["Focus Sets", "Behavior"]
        var registrations = [ObjectIdentifier: [[String]]]()
        FocusSetSettingsResolver.registerCategorySearchContent(
            for: identifier,
            focusSetManagerStrings: ["Focus Sets", "Included Applications"],
            behaviorStrings: ["Behavior", "After keys are released"],
            in: &registrations)

        let content = try XCTUnwrap(registrations[identifier])
        XCTAssertEqual(SettingsSearch.matchingSegmentIndexes(
            query: "After keys are released",
            segmentLabels: labels,
            perSegmentStrings: content), [1])
        XCTAssertEqual(SettingsSearch.matchingSegmentIndexes(
            query: "Included Applications",
            segmentLabels: labels,
            perSegmentStrings: content), [0])
        FocusSetSettingsResolver.clearCategorySearchContent(&registrations)
        XCTAssertTrue(registrations.isEmpty)
        XCTAssertTrue(SettingsSearch.matchingSegmentIndexes(
            query: "After keys are released",
            segmentLabels: labels,
            perSegmentStrings: registrations[identifier]).isEmpty)
    }

    private func application(_ bundleIdentifier: String,
                             _ presentationName: String) -> FocusSetApplicationOption {
        FocusSetApplicationOption(
            bundleIdentifier: bundleIdentifier,
            presentationName: presentationName)
    }

    private func focusSet(_ name: String,
                          id: UUID = UUID(),
                          shortcutKeyEquivalent: String? = nil) -> FocusSet {
        FocusSet(id: id, name: name, rules: [], shortcutKeyEquivalent: shortcutKeyEquivalent)
    }

    private func rule(_ bundleIdentifier: String,
                      _ cachedApplicationName: String,
                      titleContains: String? = nil) -> FocusSetRule {
        FocusSetRule(
            applicationBundleIdentifier: bundleIdentifier,
            cachedApplicationName: cachedApplicationName,
            titleContains: titleContains)
    }
}
