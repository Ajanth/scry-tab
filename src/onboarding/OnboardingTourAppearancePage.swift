import AppKit

final class OnboardingTourAppearancePage: NSObject, OnboardingTourScene {
    private static let titleText = NSLocalizedString("Choose how the switcher looks", comment: "Onboarding Appearance page heading")
    private static let bodyText = NSLocalizedString("Preview App Icons or Titles here. In Settings, you can also choose the switcher size and follow System, Light, or Dark appearance.", comment: "Onboarding Appearance page description")
    private static let selectorAccessibilityLabel = NSLocalizedString("Switcher appearance", comment: "Onboarding Appearance selector accessibility label")
    private static let iconsTitle = NSLocalizedString("App Icons", comment: "Onboarding Appearance icon layout choice")
    private static let titlesTitle = NSLocalizedString("Titles", comment: "Onboarding Appearance title layout choice")
    private static let iconSummary = NSLocalizedString("App Icons preview. Cursor, Safari, and VS Code. Safari is selected.", comment: "Onboarding Appearance icon preview accessibility summary")
    private static let titleSummary = NSLocalizedString("Titles preview. Cursor, Safari, and VS Code. Safari is selected.", comment: "Onboarding Appearance title preview accessibility summary")

    let view: NSView
    private let selector: DesignSystemChipSelectControl
    private let preview = OnboardingSwitcherPreviewView()
    private let focusSet = OnboardingTourDemoContent.focusSets[1]
    private var previewLayout = OnboardingSwitcherPreviewLayout.iconGrid
    private var hasActivated = false

    override init() {
        selector = DesignSystemChipSelectControl(labels: [Self.iconsTitle, Self.titlesTitle], selectedIndex: 0, equalWidth: true)
        let stack = NSStackView()
        view = stack
        super.init()
        setup(stack)
        applySelection(animated: false)
    }

    func activate(animated: Bool) {
        let shouldAnimate = animated && !hasActivated
        hasActivated = true
        applySelection(animated: shouldAnimate)
    }

    func deactivate() {
        removeAnimations(from: view)
        applySelection(animated: false)
    }

    @objc private func selectLayout(_ sender: DesignSystemChipSelectControl) {
        guard sender.selectedIndex == 0 || sender.selectedIndex == 1 else { return }
        let selectedLayout: OnboardingSwitcherPreviewLayout = sender.selectedIndex == 0 ? .iconGrid : .titleList
        guard selectedLayout != previewLayout else { return }
        previewLayout = selectedLayout
        applySelection(animated: shouldAnimate())
    }

    private func setup(_ stack: NSStackView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = DesignSystem.Metrics.sectionGap
        let heading = makeLabel(Self.titleText, font: NSFont.systemFont(ofSize: 17, weight: .medium), color: .textPrimary)
        let body = makeLabel(Self.bodyText, font: NSFont.systemFont(ofSize: 13), color: .textSecondary)
        let header = NSStackView(views: [heading, body])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.orientation = .vertical
        header.alignment = .centerX
        header.spacing = DesignSystem.Metrics.headerFooterGap
        configureSelector()
        [header, selector, preview].forEach { stack.addArrangedSubview($0) }
        heading.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true
        body.widthAnchor.constraint(equalTo: preview.widthAnchor).isActive = true
    }

    private func configureSelector() {
        selector.target = self
        selector.action = #selector(selectLayout(_:))
        selector.setAccessibilityLabel(Self.selectorAccessibilityLabel)
    }

    private func makeLabel(_ text: String, font: NSFont, color: DesignSystem.ColorRole) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.textColor = DesignSystem.color(color)
        label.alignment = .center
        label.maximumNumberOfLines = 0
        return label
    }

    private func applySelection(animated: Bool) {
        selector.selectedIndex = previewLayout == .iconGrid ? 0 : 1
        preview.apply(apps: focusSet.apps, layout: previewLayout, selectedIndex: focusSet.selectedIndex, summary: previewLayout == .iconGrid ? Self.iconSummary : Self.titleSummary, animated: animated)
    }

    private func shouldAnimate() -> Bool {
        OnboardingTourResolver.shouldAnimate(windowVisible: view.window?.isVisible ?? false, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private func removeAnimations(from view: NSView) {
        view.layer?.removeAllAnimations()
        view.layer?.sublayers?.forEach { $0.removeAllAnimations() }
        view.subviews.forEach { removeAnimations(from: $0) }
    }
}
