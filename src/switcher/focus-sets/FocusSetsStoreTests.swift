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
        let defaults = try testDefaults()
        let malformed = "{not JSON"
        defaults.set(malformed, forKey: key)

        let configuration = store.read(availableShortcutIdentifiers: ["profile-1"])

        XCTAssertEqual(configuration.version, FocusSetsConfiguration.currentVersion)
        XCTAssertEqual(configuration.presentationShortcutIdentifier, "profile-1")
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
            "presentationShortcutIdentifier": "profile-1",
            "sets": [firstSet, malformedSet, secondSet],
        ])

        let configuration = store.read(availableShortcutIdentifiers: ["profile-1"])

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
            "presentationShortcutIdentifier": "profile-1",
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

        let configuration = store.read(availableShortcutIdentifiers: ["profile-1"])
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
            "presentationShortcutIdentifier": "profile-1",
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

        XCTAssertTrue(store.read(availableShortcutIdentifiers: ["profile-1"]).sets.first?.rules.isEmpty == true)

        let configuration = FocusSetsConfiguration(
            presentationShortcutIdentifier: "profile-1",
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
        XCTAssertTrue(store.set(configuration, availableShortcutIdentifiers: ["profile-1"]))

        XCTAssertEqual(
            store.read(availableShortcutIdentifiers: ["profile-1"]).sets.first?.rules.map(\.applicationBundleIdentifier),
            ["com.apple.Terminal"]
        )
    }

    func testWriteDropsDuplicateSetIdentifiers() throws {
        let store = try makeStore()
        let identifier = UUID()
        let configuration = FocusSetsConfiguration(
            presentationShortcutIdentifier: "profile-1",
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

        XCTAssertTrue(store.set(configuration, availableShortcutIdentifiers: ["profile-1"]))
        XCTAssertEqual(store.read(availableShortcutIdentifiers: ["profile-1"]).sets.map(\.name), ["First"])
    }

    func testReadKeepsCachedNameForUnavailableApplication() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "presentationShortcutIdentifier": "profile-1",
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

        let configuration = store.read(availableShortcutIdentifiers: ["profile-1"])

        XCTAssertEqual(configuration.sets.first?.rules.first?.cachedApplicationName, "Cursor")
        XCTAssertEqual(configuration.sets.first?.rules.first?.applicationBundleIdentifier, "com.cursor.Cursor")
    }

    // MARK: - B. Forward compatibility

    func testWritePreservesUnknownFieldsAndOptionalTitle() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": 3,
            "presentationShortcutIdentifier": "profile-2",
            "futureRoot": ["enabled": true],
            "sets": [
                [
                    "id": identifier.uuidString,
                    "name": "Project",
                    "futureSet": ["alpha", "beta"],
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

        let configuration = store.read(availableShortcutIdentifiers: ["profile-1", "profile-2"])
        XCTAssertEqual(configuration.version, 3)
        XCTAssertEqual(configuration.sets.first?.rules.first?.titleContains, "scry-tab")
        XCTAssertTrue(store.set(configuration, availableShortcutIdentifiers: ["profile-1", "profile-2"]))

        let root = try storedRoot()
        let storedSet = try XCTUnwrap((root["sets"] as? [[String: Any]])?.first)
        let storedRule = try XCTUnwrap((storedSet["rules"] as? [[String: Any]])?.first)
        XCTAssertEqual((root["futureRoot"] as? [String: Any])?["enabled"] as? Bool, true)
        XCTAssertEqual(storedSet["futureSet"] as? [String], ["alpha", "beta"])
        XCTAssertEqual((storedRule["futureRule"] as? [String: Any])?["migrates"] as? Bool, true)
        XCTAssertEqual(storedRule["titleContains"] as? String, "scry-tab")
    }

    func testWritePreservesUnknownRuleFieldsWhenCachedNameChanges() throws {
        let store = try makeStore()
        let identifier = UUID()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "presentationShortcutIdentifier": "profile-1",
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
            presentationShortcutIdentifier: "profile-1",
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

        XCTAssertTrue(store.set(configuration, availableShortcutIdentifiers: ["profile-1"]))

        let root = try storedRoot()
        let storedSet = try XCTUnwrap((root["sets"] as? [[String: Any]])?.first)
        let storedRule = try XCTUnwrap((storedSet["rules"] as? [[String: Any]])?.first)
        XCTAssertEqual(storedRule["cachedApplicationName"] as? String, "Cursor Nightly")
        XCTAssertEqual((storedRule["futureRule"] as? [String: Any])?["migrates"] as? Bool, true)
    }

    // MARK: - C. Profile rebinding and serialization

    func testReadRebindsMissingProfileToFirstAvailableIdentifier() throws {
        let store = try makeStore()
        try seed([
            "version": FocusSetsConfiguration.currentVersion,
            "presentationShortcutIdentifier": "deleted-profile",
            "sets": [],
        ])

        let configuration = store.read(availableShortcutIdentifiers: ["", "profile-1", "profile-2"])

        XCTAssertEqual(configuration.presentationShortcutIdentifier, "profile-1")
        XCTAssertEqual(try storedRoot()["presentationShortcutIdentifier"] as? String, "profile-1")
    }

    /// An explicitly saved Focus Set with no applications survives a write/read cycle.
    func testWriteAndReadPreservesEmptyFocusSet() throws {
        let store = try makeStore()
        let configuration = FocusSetsConfiguration(
            presentationShortcutIdentifier: "profile-1",
            sets: [FocusSet(name: "Empty", rules: [])])

        XCTAssertTrue(store.set(configuration, availableShortcutIdentifiers: ["profile-1"]))
        XCTAssertEqual(store.read(availableShortcutIdentifiers: ["profile-1"]), configuration)
    }

    func testWriteAndReadRoundTrip() throws {
        let store = try makeStore()
        let configuration = FocusSetsConfiguration(
            presentationShortcutIdentifier: "profile-2",
            sets: [
                FocusSet(
                    name: "Project",
                    rules: [
                        FocusSetRule(applicationBundleIdentifier: "com.cursor.Cursor", cachedApplicationName: "Cursor"),
                        FocusSetRule(applicationBundleIdentifier: "com.apple.Terminal", cachedApplicationName: "Terminal"),
                    ]
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

        XCTAssertTrue(store.set(configuration, availableShortcutIdentifiers: ["profile-1", "profile-2"]))
        XCTAssertEqual(store.read(availableShortcutIdentifiers: ["profile-1", "profile-2"]), configuration)
    }

    private func makeStore() throws -> FocusSetsStore {
        FocusSetsStore(defaults: try testDefaults(), key: key)
    }

    private func testDefaults() throws -> UserDefaults {
        try XCTUnwrap(defaults)
    }

    private func seed(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))
        let defaults = try testDefaults()
        defaults.set(string, forKey: key)
    }

    private func storedRoot() throws -> [String: Any] {
        let defaults = try testDefaults()
        let string = try XCTUnwrap(defaults.string(forKey: key))
        let data = try XCTUnwrap(string.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
