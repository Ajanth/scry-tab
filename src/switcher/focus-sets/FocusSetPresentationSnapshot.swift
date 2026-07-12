import Foundation

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
