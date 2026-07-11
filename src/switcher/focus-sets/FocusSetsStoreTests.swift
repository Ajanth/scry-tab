import Foundation
import XCTest

final class FocusSetsStoreTests: XCTestCase {
    private let key = "FocusSetsStoreTests.configuration"
    private var suiteName = ""
    private var defaults: UserDefaults?

    override func setUp() {
        super.setUp()
        suiteName = "FocusSetsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if !suiteName.isEmpty {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        super.tearDown()
    }

    // MARK: - A. Tolerant parsing

    func testMalformedRootKeepsStoredStringAndReturnsFallback() throws {
        let store = try makeStore()
        let defaults = try isolatedDefaults()
        let malformed = "{not JSON"
        defaults.set(malformed, forKey: key)

        let configuration = store.read()

        XCTAssertEqual(configuration.version, FocusSetsConfiguration.currentVersion)
        XCTAssertTrue(configuration.sets.isEmpty)
        XCTAssertEqual(defaults.string(forKey: key), malformed)
    }

    func testMalformedSetAndRulesKeepValidSiblingSets() throws {
        let store = try makeStore()
        let firstIdentifier = UUID()
        let secondIdentifier = UUID()
        let firstSet: [String: Any] = [
            "id": firstIdentifier.uuidString,
            "name": "First",
            "rules": [
                [
                    "applicationBundleIdentifier": "com.cursor.Cursor",
                    "cachedApplicationName": "Cursor",
                ],
                [
                    "applicationBundleIdentifier": "   ",
                    "cachedApplicationName": "Invalid",
                ],
                "not a rule",
            ],
        ]
        let malformedSet: [String: Any] = [
            "id": UUID().uuidString,
            "rules": [],
        ]
        let secondSet: [String: Any] = [
            "id": secondIdentifier.uuidString,
            "name": "Second",
            "rules": [
                [
                    "applicationBundleIdentifier": "com.apple.Terminal",
                    "cachedApplicationName": "Terminal",
                ],
            ],
        ]
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "sets": [firstSet, malformedSet, secondSet],
        ])

        let configuration = store.read()

        XCTAssertEqual(configuration.sets.map(\.name), ["First", "Second"])
        XCTAssertEqual(configuration.sets.map { $0.rules.map(\.applicationBundleIdentifier) }, [
            ["com.cursor.Cursor"],
            ["com.apple.Terminal"],
        ])
    }

    func testReadDropsDuplicateSetIdentifiers() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "First",
                    "rules": [
                        [
                            "applicationBundleIdentifier": "com.cursor.Cursor",
                            "cachedApplicationName": "Cursor",
                        ],
                    ],
                ],
                [
                    "id": identifier.uuidString,
                    "name": "Duplicate",
                    "rules": [
                        [
                            "applicationBundleIdentifier": "com.apple.Terminal",
                            "cachedApplicationName": "Terminal",
                        ],
                    ],
                ],
            ],
        ])

        let configuration = store.read()
        let resolver = FocusSetResolver(configuration: configuration)
        let root = try storedRoot()

        XCTAssertEqual(configuration.sets.map(\.name), ["First"])
        XCTAssertTrue(resolver.matchesApp(bundleIdentifier: "com.cursor.Cursor", scope: .set(id: identifier)))
        XCTAssertFalse(resolver.matchesApp(bundleIdentifier: "com.apple.Terminal", scope: .set(id: identifier)))
        XCTAssertEqual((root["sets"] as? [[String: Any]])?.count, 1)
    }

    func testBlankBundleIdentifiersAreRejectedOnReadAndWrite() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "Invalid rules",
                    "rules": [
                        [
                            "applicationBundleIdentifier": "",
                            "cachedApplicationName": "Empty",
                        ],
                        [
                            "applicationBundleIdentifier": "\n\t",
                            "cachedApplicationName": "Whitespace",
                        ],
                    ],
                ],
            ],
        ])

        XCTAssertTrue(store.read().sets.first?.rules.isEmpty == true)

        let configuration = FocusSetsConfiguration(
            sets: [
                FocusSet(
                    id: identifier,
                    name: "Normalized",
                    rules: [
                        FocusSetRule(applicationBundleIdentifier: " ", cachedApplicationName: "Invalid"),
                        FocusSetRule(applicationBundleIdentifier: "com.apple.Terminal", cachedApplicationName: "Terminal"),
                    ]
                ),
            ]
        )
        XCTAssertTrue(store.set(configuration))

        XCTAssertEqual(
            store.read().sets.first?.rules.map(\.applicationBundleIdentifier),
            ["com.apple.Terminal"]
        )
    }

    func testWriteDropsDuplicateSetIdentifiers() throws {
        let store = try makeStore()
        let identifier = UUID()
        let configuration = FocusSetsConfiguration(
            sets: [
                FocusSet(
                    id: identifier,
                    name: "First",
                    rules: [
                        FocusSetRule(applicationBundleIdentifier: "com.cursor.Cursor", cachedApplicationName: "Cursor"),
                    ]
                ),
                FocusSet(
                    id: identifier,
                    name: "Duplicate",
                    rules: [
                        FocusSetRule(applicationBundleIdentifier: "com.apple.Terminal", cachedApplicationName: "Terminal"),
                    ]
                ),
            ]
        )

        XCTAssertTrue(store.set(configuration))
        XCTAssertEqual(store.read().sets.map(\.name), ["First"])
    }

    func testReadKeepsCachedNameForUnavailableApplication() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "Editor",
                    "rules": [
                        [
                            "applicationBundleIdentifier": "com.cursor.Cursor",
                            "cachedApplicationName": "Cursor",
                        ],
                    ],
                ],
            ],
        ])

        let configuration = store.read()

        XCTAssertEqual(configuration.sets.first?.rules.first?.cachedApplicationName, "Cursor")
        XCTAssertEqual(configuration.sets.first?.rules.first?.applicationBundleIdentifier, "com.cursor.Cursor")
    }

    func testMalformedShortcutValueIsIgnoredWithoutDroppingSet() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "Project",
                    "rules": [],
                    "shortcutKeyEquivalent": ["not", "a", "shortcut"],
                ],
            ],
        ])

        let configuration = store.read()

        XCTAssertEqual(configuration.sets.map(\.id), [identifier])
        XCTAssertNil(configuration.sets.first?.shortcutKeyEquivalent)
    }

    // MARK: - B. Forward compatibility

    func testReadMigratesV1WhilePreservingUnknownFields() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": 1,
            "futureRoot": ["enabled": true],
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "Legacy",
                    "futureSet": "retained",
                    "rules": [],
                ],
            ],
        ])

        let configuration = store.read()
        let root = try storedRoot()
        let storedSet = try XCTUnwrap((root["sets"] as? [[String: Any]])?.first)

        XCTAssertEqual(configuration.version, FocusSetsConfiguration.currentVersion)
        XCTAssertEqual(root["version"] as? Int, FocusSetsConfiguration.currentVersion)
        XCTAssertEqual((root["futureRoot"] as? [String: Any])?["enabled"] as? Bool, true)
        XCTAssertNil(root["presentationShortcutIdentifier"])
        XCTAssertEqual(storedSet["futureSet"] as? String, "retained")
    }

    func testWritePreservesUnknownFieldsAndOptionalTitle() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": 3,
            "presentationShortcutIdentifier": "shortcut-2",
            "futureRoot": ["enabled": true],
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "Project",
                    "futureSet": ["alpha", "beta"],
                    "shortcutKeyEquivalent": "⌃1",
                    "rules": [
                        [
                            "applicationBundleIdentifier": "com.cursor.Cursor",
                            "cachedApplicationName": "Cursor",
                            "titleContains": "scry-tab",
                            "futureRule": ["migrates": true],
                        ],
                    ],
                ],
            ],
        ])

        let configuration = store.read()
        XCTAssertEqual(configuration.version, 3)
        XCTAssertEqual(configuration.sets.first?.shortcutKeyEquivalent, "⌃1")
        XCTAssertEqual(configuration.sets.first?.rules.first?.titleContains, "scry-tab")
        XCTAssertTrue(store.set(configuration))

        let root = try storedRoot()
        let storedSet = try XCTUnwrap((root["sets"] as? [[String: Any]])?.first)
        let storedRule = try XCTUnwrap((storedSet["rules"] as? [[String: Any]])?.first)
        XCTAssertEqual((root["futureRoot"] as? [String: Any])?["enabled"] as? Bool, true)
        XCTAssertNil(root["presentationShortcutIdentifier"])
        XCTAssertEqual(storedSet["futureSet"] as? [String], ["alpha", "beta"])
        XCTAssertEqual((storedRule["futureRule"] as? [String: Any])?["migrates"] as? Bool, true)
        XCTAssertEqual(storedRule["titleContains"] as? String, "scry-tab")
    }

    func testWritePreservesUnknownRuleFieldsWhenCachedNameChanges() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "Project",
                    "rules": [
                        [
                            "applicationBundleIdentifier": "com.cursor.Cursor",
                            "cachedApplicationName": "Cursor",
                            "futureRule": ["migrates": true],
                        ],
                    ],
                ],
            ],
        ])
        let configuration = FocusSetsConfiguration(
            sets: [
                FocusSet(
                    id: identifier,
                    name: "Project",
                    rules: [
                        FocusSetRule(
                            applicationBundleIdentifier: "com.cursor.Cursor",
                            cachedApplicationName: "Cursor Nightly"),
                    ])
            ])

        XCTAssertTrue(store.set(configuration))

        let root = try storedRoot()
        let storedSet = try XCTUnwrap((root["sets"] as? [[String: Any]])?.first)
        let storedRule = try XCTUnwrap((storedSet["rules"] as? [[String: Any]])?.first)
        XCTAssertEqual(storedRule["cachedApplicationName"] as? String, "Cursor Nightly")
        XCTAssertEqual((storedRule["futureRule"] as? [String: Any])?["migrates"] as? Bool, true)
    }

    // MARK: - C. Retired presentation-owner field and serialization

    /// A normalized V1/V2 read removes the known retired presentation-owner field without touching other data.
    func testReadRemovesRetiredPresentationOwnerField() throws {
        let store = try makeStore()
        try seed([
            "version": 2,
            "presentationShortcutIdentifier": "deleted-shortcut",
            "sets": [],
        ])

        let configuration = store.read()

        XCTAssertEqual(configuration.version, FocusSetsConfiguration.currentVersion)
        XCTAssertNil(try storedRoot()["presentationShortcutIdentifier"])
    }

    /// An explicitly saved Focus Set with no applications survives a write/read cycle.
    func testWriteAndReadPreservesEmptyFocusSet() throws {
        let store = try makeStore()
        let configuration = FocusSetsConfiguration(sets: [FocusSet(name: "Empty", rules: [])])

        XCTAssertTrue(store.set(configuration))
        XCTAssertEqual(store.read(), configuration)
    }

    func testWriteAndReadRoundTrip() throws {
        let store = try makeStore()
        let configuration = FocusSetsConfiguration(
            sets: [
                FocusSet(
                    name: "Project",
                    rules: [
                        FocusSetRule(applicationBundleIdentifier: "com.cursor.Cursor", cachedApplicationName: "Cursor"),
                        FocusSetRule(applicationBundleIdentifier: "com.apple.Terminal", cachedApplicationName: "Terminal"),
                    ],
                    shortcutKeyEquivalent: "⌃1"
                ),
                FocusSet(
                    name: "Browser",
                    rules: [
                        FocusSetRule(
                            applicationBundleIdentifier: "com.google.Chrome",
                            cachedApplicationName: "Google Chrome",
                            titleContains: "ScryTab"
                        ),
                    ]
                ),
            ]
        )

        XCTAssertTrue(store.set(configuration))
        XCTAssertEqual(store.read(), configuration)
    }

    private func makeStore() throws -> FocusSetsStore {
        FocusSetsStore(defaults: try isolatedDefaults(), key: key)
    }

    private func isolatedDefaults() throws -> UserDefaults {
        try XCTUnwrap(defaults)
    }

    private func seed(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))
        let defaults = try isolatedDefaults()
        defaults.set(string, forKey: key)
    }

    private func storedRoot() throws -> [String: Any] {
        let defaults = try isolatedDefaults()
        let string = try XCTUnwrap(defaults.string(forKey: key))
        let data = try XCTUnwrap(string.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
