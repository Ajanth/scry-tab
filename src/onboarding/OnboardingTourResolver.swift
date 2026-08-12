import AppKit

enum OnboardingTourPage: Int, CaseIterable {
    case focusSets
    case appearance
    case controls
}

enum OnboardingTourNavigationAction: Equatable {
    case show(OnboardingTourPage)
    case finish
}

enum OnboardingTourResolver {
    static func back(from page: OnboardingTourPage) -> OnboardingTourPage {
        switch page {
        case .focusSets: return .focusSets
        case .appearance: return .focusSets
        case .controls: return .appearance
        }
    }

    static func next(from page: OnboardingTourPage) -> OnboardingTourNavigationAction {
        switch page {
        case .focusSets: return .show(.appearance)
        case .appearance: return .show(.controls)
        case .controls: return .finish
        }
    }

    static func shouldPresentAutomatically(initialExperienceShown: Bool) -> Bool {
        !initialExperienceShown
    }

    static func shouldAnimate(windowVisible: Bool, reduceMotion: Bool) -> Bool {
        windowVisible && !reduceMotion
    }

    static func nextAutoplayIndex(after currentIndex: Int, count: Int) -> Int? {
        guard count > 0, currentIndex >= 0, currentIndex < count - 1 else { return nil }
        return currentIndex + 1
    }

    static func settingsRoute(for completion: OnboardingTourCompletion) -> SettingsRoute? {
        switch completion {
        case .skip: return nil
        case .openAppearance: return .appearance
        case .exploreFocusSets: return .focusSets
        }
    }
}

protocol OnboardingTourScene: AnyObject {
    var view: NSView { get }
    func activate(animated: Bool)
    func deactivate()
}

enum OnboardingTourCompletion {
    case skip
    case openAppearance
    case exploreFocusSets
}
