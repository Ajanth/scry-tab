import Cocoa

class CustomizeStyleSheet: SheetWindow {
    // Local labels (rows owned by this sheet). The Show/Hide rows below are sourced from
    // `ShowHideIllustratedView`'s static constants so each NSLocalizedString call lives in
    // exactly one place across the codebase.
    private static let labelAppearance = NSLocalizedString("Appearance", comment: "")
    private static let labelTitles = NSLocalizedString("Titles", comment: "")
    private static let labelShowTitles = NSLocalizedString("Show titles", comment: "")
    private static let labelTitleTruncation = NSLocalizedString("Title truncation", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        labelAppearance,
        labelTitles,
        labelShowTitles,
        labelTitleTruncation,
        ShowHideIllustratedView.hideStatusIconsLabel,
        ShowHideIllustratedView.hideStatusIconsSubtitle,
        ShowHideIllustratedView.hideSpaceNumberLabelsLabel,
        IllustratedImageThemeView.placeholderLabelText,
    ] + ShowTitlesPreference.allCases.map { $0.localizedString }
      + TitleTruncationPreference.allCases.map { $0.localizedString }

    private static let sheetWidth = CGFloat(520)
    private static let illustratedImageWidth = sheetWidth

    let style = Preferences.appearanceStyle
    var illustratedImageView: IllustratedImageThemeView!
    var showHideIllustratedView: ShowHideIllustratedView!

    override var contentWidth: CGFloat { Self.sheetWidth }

    override func makeContentView() -> NSView {
        illustratedImageView = IllustratedImageThemeView(style, CustomizeStyleSheet.illustratedImageWidth)
        showHideIllustratedView = ShowHideIllustratedView(style, illustratedImageView)
        let showHideView = showHideIllustratedView.makeView(width: Self.sheetWidth, title: Self.labelAppearance)
        let titlesTable = makeTitlesTable()
        return TableGroupSetView(originalViews: [illustratedImageView, showHideView, titlesTable],
                                 padding: 0,
                                 topPadding: 0,
                                 bottomPadding: 0)
    }

    private func makeTitlesTable() -> TableGroupView {
        let table = TableGroupView(title: Self.labelTitles, width: Self.sheetWidth)
        let showTitles = TableGroupView.Row(leftTitle: Self.labelShowTitles,
            rightViews: [LabelAndControl.makeDropdown(
                "showTitles", ShowTitlesPreference.allCases, extraAction: { [weak self] _ in
                    self?.showTitlesIllustratedImage()
                })])
        table.addRow(showTitles, onMouseEntered: { [weak self] _, _ in
            self?.showTitlesIllustratedImage()
        })
        let titleTruncation = TableGroupView.Row(leftTitle: Self.labelTitleTruncation,
            rightViews: [LabelAndControl.makeChipSelect("titleTruncation",
                                                        TitleTruncationPreference.allCases,
                                                        chipWidth: 72,
                                                        equalWidth: true)])
        table.addRow(titleTruncation)
        table.onMouseExited = { [weak self] event, view in
            guard let self else { return }
            IllustratedImageThemeView.resetImage(self.illustratedImageView, event, view)
        }
        return table
    }

    private func showTitlesIllustratedImage() {
        illustratedImageView.highlight(true, Preferences.showTitles.image.name)
    }
}
