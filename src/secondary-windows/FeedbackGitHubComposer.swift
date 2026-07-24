import Foundation

enum FeedbackKind: Hashable {
    case bug
    case enhancement
}

/// Builds GitHub issue-composer URLs for the public feedback repository.
enum FeedbackGitHubComposer {
    static let repositoryURLString = "https://github.com/Ajanth/scrytab-public"
    static let detailsFieldID = "details"
    /// Keep prefills inside common browser URL limits; drop details before failing entirely.
    static let maxURLLength = 2048

    static func templateFileName(for kind: FeedbackKind) -> String {
        switch kind {
        case .bug: return "bug-report.yml"
        case .enhancement: return "feature-request.yml"
        }
    }

    static func issuesURLString(repositoryURLString: String = repositoryURLString) -> String {
        repositoryURLString + "/issues"
    }

    static func issueComposerURL(
        kind: FeedbackKind,
        title: String,
        details: String,
        repositoryURLString: String = repositoryURLString,
        maxURLLength: Int = maxURLLength
    ) -> URL? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedDetails.isEmpty else { return nil }
        guard let withDetails = makeURL(
            kind: kind,
            title: trimmedTitle,
            details: trimmedDetails,
            repositoryURLString: repositoryURLString
        ) else { return nil }
        if withDetails.absoluteString.utf8.count <= maxURLLength {
            return withDetails
        }
        return makeURL(
            kind: kind,
            title: trimmedTitle,
            details: nil,
            repositoryURLString: repositoryURLString)
    }

    private static func makeURL(
        kind: FeedbackKind,
        title: String,
        details: String?,
        repositoryURLString: String
    ) -> URL? {
        var components = URLComponents(string: repositoryURLString + "/issues/new")
        var items = [
            URLQueryItem(name: "template", value: templateFileName(for: kind)),
            URLQueryItem(name: "title", value: title),
        ]
        if let details {
            items.append(URLQueryItem(name: detailsFieldID, value: details))
        }
        components?.queryItems = items
        return components?.url
    }
}
