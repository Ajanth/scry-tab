import XCTest

final class FeedbackGitHubComposerTests: XCTestCase {
    func testBugUsesBugReportTemplate() {
        XCTAssertEqual(FeedbackGitHubComposer.templateFileName(for: .bug), "bug-report.yml")
    }

    func testEnhancementUsesFeatureRequestTemplate() {
        XCTAssertEqual(FeedbackGitHubComposer.templateFileName(for: .enhancement), "feature-request.yml")
    }

    func testIssuesURLPointsAtPublicRepo() {
        XCTAssertEqual(
            FeedbackGitHubComposer.issuesURLString(),
            "https://github.com/Ajanth/scrytab-public/issues")
    }

    func testComposerURLPrefillsTitleAndDetails() {
        let url = FeedbackGitHubComposer.issueComposerURL(
            kind: .bug,
            title: " Window focus breaks ",
            details: " Steps:\n1. Open app\n2. Switch ")
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let items = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components?.path, "/Ajanth/scrytab-public/issues/new")
        XCTAssertEqual(items["template"], "bug-report.yml")
        XCTAssertEqual(items["title"], "Window focus breaks")
        XCTAssertEqual(items["details"], "Steps:\n1. Open app\n2. Switch")
    }

    func testComposerURLRejectsBlankFields() {
        XCTAssertNil(FeedbackGitHubComposer.issueComposerURL(kind: .bug, title: "  ", details: "body"))
        XCTAssertNil(FeedbackGitHubComposer.issueComposerURL(kind: .enhancement, title: "title", details: "\n\t"))
    }

    func testComposerURLOmitsDetailsWhenTooLong() {
        let longDetails = String(repeating: "x", count: 4000)
        let url = FeedbackGitHubComposer.issueComposerURL(
            kind: .enhancement,
            title: "Short title",
            details: longDetails,
            maxURLLength: 200)
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let items = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["template"], "feature-request.yml")
        XCTAssertEqual(items["title"], "Short title")
        XCTAssertNil(items["details"])
    }
}
