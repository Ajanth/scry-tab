import Cocoa

class TileView: FlippedView {
    static let noOpenWindowToolTip = NSLocalizedString("App is running but has no open window", comment: "")
    // when calculating the width of a nstextfield, somehow we need to add this suffix to get the correct width
    static let extraTextForPadding = "lmnopqrstuvw"

    var window_: Window?
    var appIcon = LightImageLayer()
    var appIconHighlight = noAnimation { CALayer() }
    var label = TileTitleView(font: Appearance.font)
    var statusIcons = StatusIconsView()
    var dockLabelIcon = TileFontIconView(badgeSize: TileFontIconView.badgeBaseSize(forIconSize: TileView.iconSize().width))
    var windowlessAppIndicator = WindowlessAppIndicator(tooltip: TileView.noOpenWindowToolTip)
    private var fullTitle = ""
    private var fullTitleWidth = CGFloat(0)
    private var presentationRowWidth: CGFloat?
    private var presentationStyle: AppearanceStylePreference?
    private(set) var presentationScale = CGFloat(1)

    private var profileStyle: AppearanceStylePreference {
        Preferences.appearanceStyle(SwitcherSession.current?.presentationSource ?? .shortcut(0))
    }

    private var resolvedStyle: AppearanceStylePreference {
        let usesAppIcons = TilePresentationResolver.usesAppIconLayout(
            profileUsesAppIcons: profileStyle == .appIcons,
            presentationUsesAppIcons: presentationStyle.map { $0 == .appIcons })
        return usesAppIcons ? .appIcons : .titles
    }

    var mouseUpCallback: (() -> Void)!
    var mouseMovedCallback: (() -> Void)!
    var indexInRecycledViews: Int!

    var isFirstInRow = false
    var isLastInRow = false
    var indexInRow = 0
    var numberOfViewsInRow = 0

    // for VoiceOver cursor; gate on window != nil so recycled TileViews not in the
    // current hierarchy are skipped by AppKit's key-view loop walker (called e.g.
    // from _selectFirstKeyView during makeKeyAndOrderFront), avoiding a
    // "different window" error on _validateFirstResponder.
    override var canBecomeKeyView: Bool { window != nil }
    override var acceptsFirstResponder: Bool { window != nil }

    // AppKit recursively walks every view in our subtree during makeKeyAndOrderFront and resize:
    // _windowChangedKeyState marks NSControl subviews needsDisplay; _layoutSubtreeWithOldSize: drives
    // the autoresize layout pass. The switcher positions its tile views explicitly in
    // TilesView.updateItemsAndLayout, so both walks are pure overhead on this subtree. Override as
    // no-ops to stop the recursion at the tile boundary. AppKit-native subviews (NSSearchField,
    // NSTextField labels) that live outside the tile subtree still get their normal passes.
    @objc func _windowChangedKeyState() {}
    @objc func _layoutSubtreeWithOldSize(_ oldSize: NSSize) {}

    override func isAccessibilityElement() -> Bool { true }

    func mouseMoved() {
        updateLabelTooltipIfNeeded()
        mouseMovedCallback()
    }

    private func updateLabelTooltipIfNeeded() {
        guard resolvedStyle != .appIcons else { return }
        label.toolTip = fullTitleWidth >= label.frame.size.width ? fullTitle : nil
    }

    convenience init() {
        self.init(frame: .zero)
        setupView()
    }

    /// The frame used by TileUnderLayer to position the highlight rectangle.
    /// In appIcons style, it covers appIcon + edge insets. Otherwise, it covers the full cell.
    var highlightFrame: CGRect {
        TilePresentationResolver.highlightFrame(
            usesAppIconLayout: resolvedStyle == .appIcons,
            frameSize: frame.size,
            iconHeight: appIcon.frame.height,
            edgeInsets: Appearance.edgeInsetsSize,
            scale: presentationScale)
    }

    func updateRecycledCellWithNewContent(_ element: Window, _ index: Int, _ newHeight: CGFloat) {
        presentationRowWidth = nil
        presentationStyle = nil
        presentationScale = 1
        window_ = element
        label.toolTip = nil
        let style = profileStyle
        applyCurrentStyle(style)
        updateValues(element, index, newHeight, style)
        updateSizes(newHeight, style)
        updatePositions(newHeight, style)
        applySearchHighlight(style)
    }

    func updatePresentationCell(title: String,
                                icon: NSImage,
                                frameSize: NSSize,
                                rowWidth: CGFloat,
                                isFullscreen: Bool,
                                spaceNumber: Int,
                                scale: CGFloat = 1) {
        updatePresentationCell(
            title: title,
            icon: icon,
            frameSize: frameSize,
            rowWidth: rowWidth,
            isFullscreen: isFullscreen,
            spaceNumber: spaceNumber,
            scale: scale,
            style: Preferences.appearanceStyle(SwitcherSession.current?.presentationSource ?? .shortcut(0)),
            showsStatus: true)
    }

    private func updatePresentationCell(title: String,
                                        icon: NSImage,
                                        frameSize: NSSize,
                                        rowWidth: CGFloat,
                                        isFullscreen: Bool,
                                        spaceNumber: Int,
                                        scale: CGFloat,
                                        style: AppearanceStylePreference,
                                        showsStatus: Bool) {
        window_ = nil
        presentationRowWidth = rowWidth
        presentationStyle = style
        presentationScale = scale
        statusIcons.isHidden = style == .appIcons || !showsStatus
        label.alignment = style == .appIcons ? .center : .natural
        label.isHidden = style == .appIcons
        frame.size = frameSize
        label.font = NSFontManager.shared.convert(Appearance.font, toSize: Appearance.font.pointSize * scale)
        label.fixHeight()
        label.stringValue = title
        fullTitle = title
        fullTitleWidth = label.cell?.cellSize.width ?? 0
        let baseIconSize = TileView.iconSize(style: style)
        let iconSize = pixelAligned(baseIconSize.scaled(by: scale))
        let iconImage = Application.appIconWithoutPadding(icon) ?? presentationIcon(icon, size: iconSize)
        appIcon.updateContents(.cgImage(iconImage), iconSize)
        statusIcons.update(
            isHidden: !showsStatus,
            isFullscreen: isFullscreen,
            isMinimized: false,
            showSpace: showsStatus)
        statusIcons.setSpaceNumber(spaceNumber)
        dockLabelIcon.isHidden = true
        windowlessAppIndicator.isHidden = true
        appIconHighlight.isHidden = true
        updatePresentationPositions(frameSize.height, style: style)
    }

    func setPresentationFocused(_ focused: Bool) {
        guard resolvedStyle == .appIcons else {
            label.isHidden = false
            return
        }
        label.isHidden = !focused
        guard focused else { return }
        updateAppIconsLabelFrame()
    }

    private func updatePresentationPositions(_ height: CGFloat, style: AppearanceStylePreference) {
        let edgeInsets = pixelAligned(Appearance.edgeInsetsSize * presentationScale)
        assignIfDifferent(&appIcon.frame.origin, NSPoint(x: edgeInsets, y: edgeInsets))
        if style != .appIcons {
            let contentWidth = frame.width - edgeInsets * 2
            let labelWidth = contentWidth - appIcon.frame.width - Appearance.appIconLabelSpacing * presentationScale - statusIcons.totalWidth
            label.setWidth(labelWidth)
            updatePositions(height, style)
        }
    }

    private func presentationIcon(_ icon: NSImage, size: NSSize) -> CGImage? {
        var proposedRect = NSRect(origin: .zero, size: size)
        let hints: [NSImageRep.HintKey: NSNumber] = [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
        return icon.cgImage(forProposedRect: &proposedRect, context: nil, hints: hints)
    }

    private func pixelAligned(_ value: CGFloat) -> CGFloat {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        return (value * scale).rounded() / scale
    }

    private func pixelAligned(_ size: NSSize) -> NSSize {
        NSSize(width: pixelAligned(size.width), height: pixelAligned(size.height))
    }

    func drawHighlight() {
        if resolvedStyle == .appIcons {
            let session = SwitcherSession.current
            let isFocused = indexInRecycledViews == (session?.selectedIndex ?? 0)
            let isHovered = indexInRecycledViews == session?.hoveredIndex
            let shouldBeVisible = isFocused || isHovered
            // Update the frame BEFORE unhiding. `applyCurrentStyle()` already set
            // `label.isHidden = true` in `updateRecycledCellWithNewContent`; the label's frame is
            // still at its previous-style position (e.g. right-of-icon from titles). Setting
            // `isHidden = false` first would briefly reveal the label at the stale position before
            // `updateAppIconsLabelFrame()` moves it under the icon — that's the "title slides from
            // right of icon to under the icon" frame the user reported during cross-style summons.
            if shouldBeVisible {
                updateAppIconsLabelFrame()
            }
            label.isHidden = !shouldBeVisible
            updateAppIconsLabel(isFocused: isFocused, isHovered: isHovered)
        }
    }

    func updateDockLabelIcon(_ dockLabel: String?) {
        assignIfDifferent(&dockLabelIcon.isHidden, dockLabel == nil || Appearance.iconSize == 0)
        if !dockLabelIcon.isHidden, let dockLabel {
            dockLabelIcon.setText(dockLabel)
            dockLabelIcon.setAccessibilityLabel(getAccessibilityTextForBadge(dockLabel))
        }
    }

    private func setupView() {
        setAccessibilityChildren([])
        wantsLayer = true
        layer!.masksToBounds = false // without this, label will be clipped in app-icons style since its larger than its parentView
        setupSharedSubviews()
        applyCurrentStyle()
    }

    private func setupSharedSubviews() {
        let shadow = TileView.makeShadow(Appearance.imagesShadowColor)
        let appIconShadow = TileView.makeAppIconShadow(Appearance.imagesShadowColor)
        appIcon.applyShadow(appIconShadow)
        dockLabelIcon.shadow = shadow
        appIconHighlight.isHidden = true
        layer!.addSublayer(appIconHighlight)
        layer!.addSublayer(appIcon)
        addSubviews([label, statusIcons])
        setSubviewAbove(windowlessAppIndicator)
        addSubview(dockLabelIcon)
        label.fixHeight()
        // Disable implicit CALayer animations on every subview that moves between styles. The
        // `caTransaction { setDisableActions(true) }` in `TilesPanel.updateContents` covers the
        // bulk of the relayout, but `NSWindow.setContentSize` triggers a follow-up layout pass
        // that adjusts subview frames *outside* that transaction — and at that point the layer's
        // default action dictionary fires a position/bounds animation, producing the visible
        // "title slides from right of icon to under icon" frames during a cross-style summon.
        // Permanently nulling these actions makes every frame change instant, which is what we
        // want for a switcher (no animations are ever desired here).
        TileView.disableImplicitLayerAnimations(on: label)
        TileView.disableImplicitLayerAnimations(on: statusIcons)
        TileView.disableImplicitLayerAnimations(on: windowlessAppIndicator)
        TileView.disableImplicitLayerAnimations(on: dockLabelIcon)
    }

    /// Set `wantsLayer = true` and null out the implicit-animation entries in the layer's actions
    /// dictionary, so subsequent `frame` / `position` / `bounds` / `hidden` / `opacity` changes
    /// commit without a transition — even when triggered from an AppKit layout pass running
    /// outside our `caTransaction`. NSNull conforms to `CAAction` and is the documented sentinel
    /// for "no animation for this key".
    private static let nullActions: [String: any CAAction] = [
        "position": NSNull(),
        "bounds": NSNull(),
        "frame": NSNull(),
        "hidden": NSNull(),
        "opacity": NSNull(),
        "transform": NSNull(),
    ]
    private static func disableImplicitLayerAnimations(on view: NSView) {
        view.wantsLayer = true
        view.layer?.actions = nullActions
    }

    /// Apply visibility / alignment rules for the current effective appearance style. Called from
    /// `updateRecycledCellWithNewContent` so each summon picks up the active shortcut's override
    /// without forcing a full `TilesView.reset()` (which would recreate all 20 recycled tiles).
    func applyCurrentStyle() {
        applyCurrentStyle(profileStyle)
    }

    private func applyCurrentStyle(_ style: AppearanceStylePreference) {
        statusIcons.isHidden = style == .appIcons
        label.alignment = style == .appIcons ? .center : .natural
        label.isHidden = style == .appIcons
    }

    private func updateAppIconsLabel(isFocused: Bool, isHovered: Bool) {
        let selectedIndex = SwitcherSession.current?.selectedIndex ?? 0
        let focusedView = TilesView.recycledViews[selectedIndex]
        var hoveredView: TileView? = nil
        if let hovered = SwitcherSession.current?.hoveredIndex {
            hoveredView = TilesView.recycledViews[hovered]
        }
        // Always move the frame BEFORE unhiding (see comment in `drawHighlight`). Hide-before-show
        // is fine in either order because hiding doesn't reveal a stale position.
        if isFocused || (!isFocused && !isHovered) {
            hoveredView?.label.isHidden = true
            focusedView.updateAppIconsLabelFrame()
            focusedView.label.isHidden = false
        } else if isHovered {
            focusedView.label.isHidden = true
            if let hoveredView {
                hoveredView.updateAppIconsLabelFrame()
                hoveredView.label.isHidden = false
            }
        }
    }

    private func getMaxAllowedLabelWidth() -> CGFloat {
        let viewWidth = frame.width
        let maxAllowedWidth = min(viewWidth * 2, presentationRowWidth ?? TilesView.rowWidth)
        let availableLeftWidth = isFirstInRow ? 0 : CGFloat(indexInRow) * viewWidth
        let availableRightWidth = isLastInRow ? 0 : CGFloat(numberOfViewsInRow - 1 - indexInRow) * viewWidth
        let totalWidth = availableLeftWidth + availableRightWidth + viewWidth
        let maxLabelWidth = min(totalWidth, maxAllowedWidth)
        return maxLabelWidth - Appearance.intraCellPadding * 2
    }

    private func updateAppIconsLabelFrame() {
        let viewWidth = frame.width
        let labelWidth = fullTitleWidth
        let intraCellPadding = Appearance.intraCellPadding * presentationScale
        let padding = (Appearance.resolvedSize == .small ? 0 : (Appearance.resolvedSize == .medium ? 1 : 2)) * intraCellPadding
        let maxAllowedLabelWidth = getMaxAllowedLabelWidth()
        let sidesToOffset: CGFloat = (isFirstInRow ? 1 : 0) + (isLastInRow ? 1 : 0)
        let paddingForOffset = sidesToOffset * padding
        var effectiveLabelWidth = max(min(labelWidth, maxAllowedLabelWidth), viewWidth) - paddingForOffset
        // if the label is small, and with an offset only on one side, we reduce its width to center its text
        if sidesToOffset == 1 && labelWidth <= (effectiveLabelWidth - paddingForOffset) {
            effectiveLabelWidth -= paddingForOffset
        }
        var leftOffset = CGFloat(0)
        if isFirstInRow {
            leftOffset = -padding
        } else if isLastInRow {
            leftOffset = effectiveLabelWidth - viewWidth + padding
        } else {
            let halfNeededOffset = max(0, (effectiveLabelWidth - viewWidth) / 2)
            let availableLeftWidth = isFirstInRow ? 0 : CGFloat(indexInRow) * viewWidth
            let availableRightWidth = isLastInRow ? 0 : CGFloat(numberOfViewsInRow - 1 - indexInRow) * viewWidth
            if availableLeftWidth >= halfNeededOffset && availableRightWidth >= halfNeededOffset {
                leftOffset = halfNeededOffset
            } else if availableLeftWidth <= halfNeededOffset && availableRightWidth <= halfNeededOffset {
                leftOffset = availableLeftWidth
            } else if availableRightWidth <= halfNeededOffset {
                leftOffset = min(effectiveLabelWidth - viewWidth - availableRightWidth, availableLeftWidth)
            } else if availableLeftWidth <= halfNeededOffset {
                leftOffset = availableLeftWidth
            }
        }
        let xPosition = -leftOffset
        let height = presentationScale == 1 ? TilesView.layoutCache.labelHeight : label.cell?.cellSize.height ?? Appearance.fontHeight * presentationScale
        let yPosition = appIcon.frame.maxY + intraCellPadding * 2
        label.frame = NSRect(x: xPosition, y: yPosition, width: effectiveLabelWidth, height: height)
        label.setWidth(effectiveLabelWidth)
        label.toolTip = labelWidth >= label.frame.size.width ? fullTitle : nil
        applySearchHighlight(resolvedStyle)
    }

    private func updateAppIcon(_ element: Window, _ title: String, _ style: AppearanceStylePreference) {
        let appIconSize = TileView.iconSize(style: style)
        appIcon.updateContents(.cgImage(element.icon), appIconSize)
    }

    private func updateValues(_ element: Window,
                              _ index: Int,
                              _ newHeight: CGFloat,
                              _ style: AppearanceStylePreference) {
        assignIfDifferent(&windowlessAppIndicator.isHidden, !element.isWindowlessApp)
        statusIcons.update(
            isHidden: element.isHidden && !Preferences.hideStatusIcons,
            isFullscreen: element.isFullscreen && !Preferences.hideStatusIcons,
            isMinimized: element.isMinimized && !Preferences.hideStatusIcons,
            showSpace: !(element.isWindowlessApp || Spaces.isSingleSpace() || Preferences.hideSpaceNumberLabels || {
                guard let shortcutIndex = SwitcherSession.current?.presentationSource.shortcutIndex else { return false }
                return Preferences.spacesToShow[shortcutIndex] == .visible && (
                    NSScreen.screens.count < 2 || Preferences.screensToShow[shortcutIndex] == .showingScryTab
                )
            }())
        )
        let title = getAppOrAndWindowTitle()
        let labelChanged = label.stringValue != title
        if labelChanged {
            label.stringValue = title
            setAccessibilityLabel(title)
        }
        fullTitle = title
        fullTitleWidth = label.cell!.cellSize.width
        label.updateTruncationModeIfNeeded()
        if statusIcons.spaceVisible {
            let spaceIndex = element.spaceIndexes.first
            if element.isOnAllSpaces || (spaceIndex != nil && spaceIndex! > 30) {
                statusIcons.setSpaceStar()
            } else if let spaceIndex {
                statusIcons.setSpaceNumber(spaceIndex)
            }
        }
        updateAppIcon(element, title, style)
        updateDockLabelIcon(element.dockLabel)
        setAccessibilityHelp(getAccessibilityHelp(element.application.localizedName, element.dockLabel))
        mouseUpCallback = { () -> Void in App.focusSelectedWindow(element) }
        mouseMovedCallback = { () -> Void in Windows.updateSelectedAndHoveredWindowIndex(index, true) }
    }

    private func applySearchHighlight(_ style: AppearanceStylePreference) {
        let attributes = baseTitleAttributes()
        let query = Search.normalizedQuery(SwitcherSession.current?.searchQuery ?? "")
        let hasAppMatch = !(window_?.swAppResults.isEmpty ?? true)
        appIconHighlight.isHidden = query.isEmpty || !hasAppMatch
        if !appIconHighlight.isHidden {
            if style == .appIcons {
                // match the blue focus outline's visual curvature: same cornerRadius/height ratio,
                // applied to our smaller rect (the blue outline uses highlightFrame, which is taller).
                let rect = appIcon.frame.insetBy(dx: -2, dy: -2)
                appIconHighlight.frame = rect
                let blueRatio = Appearance.cellCornerRadius / max(highlightFrame.height, 1)
                appIconHighlight.cornerRadius = rect.height * blueRatio
            } else {
                // icons can be small (titles style) — scale to icon size and use the
                // squircle curve so the halo matches the macOS app-icon shape at every size.
                let inset = max(2, appIcon.frame.height * 0.06)
                let rect = appIcon.frame.insetBy(dx: -inset, dy: -inset)
                appIconHighlight.frame = rect
                appIconHighlight.cornerRadius = rect.height * 0.3237
            }
            appIconHighlight.backgroundColor = Appearance.searchMatchHighlightColor.cgColor
        }
        if query.isEmpty {
            label.attributedStringValue = NSAttributedString(string: fullTitle, attributes: attributes)
            return
        }
        let clippingAttributes = baseTitleAttributes(true)
        let spanRanges = searchSpanRanges()
        let titleLength = Array(fullTitle).count
        let highlightedIndexes = highlightedIndexes(spanRanges, titleLength)
        let truncation = truncatedDisplay(fullTitle, maxWidth: label.frame.size.width, mode: label.lineBreakMode, attributes: clippingAttributes)
        let attributed = NSMutableAttributedString(string: truncation.text, attributes: clippingAttributes)
        for range in visibleHighlightRanges(truncation.visibleToOriginal, highlightedIndexes) {
            attributed.addAttribute(TileTitleView.searchHighlightBackgroundKey, value: Appearance.searchMatchHighlightColor, range: range)
            attributed.addAttribute(.foregroundColor, value: Appearance.searchMatchForegroundColor, range: range)
        }
        let visibleOriginalIndexes = Set(truncation.visibleToOriginal.compactMap { $0 })
        let hasHiddenHighlights = highlightedIndexes.contains { !visibleOriginalIndexes.contains($0) }
        if hasHiddenHighlights, let ellipsisIndex = truncation.ellipsisIndex {
            let range = NSRange(location: ellipsisIndex, length: 1)
            attributed.addAttribute(TileTitleView.searchHighlightBackgroundKey, value: Appearance.searchMatchHighlightColor, range: range)
            attributed.addAttribute(.foregroundColor, value: Appearance.searchMatchForegroundColor, range: range)
        }
        label.attributedStringValue = attributed
    }

    static func invalidateTitleAttributesCache() {
        // Kept as a no-op for callers — attributes are no longer cached. They depend on per-tile
        // `label.alignment` (which varies by effective appearance style: `.center` for appIcons,
        // `.natural` for the others) and on `label.lineBreakMode` (per-title truncation pref).
        // With per-shortcut style overrides, those can differ across tiles in the same panel,
        // so a shared static cache was returning stale alignment to whichever tile rendered second.
    }

    private func baseTitleAttributes(_ forceClipping: Bool = false) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = label.alignment
        paragraphStyle.baseWritingDirection = .leftToRight
        paragraphStyle.lineBreakMode = forceClipping ? .byClipping : label.lineBreakMode
        return [.foregroundColor: Appearance.fontColor, .font: Appearance.font, .paragraphStyle: paragraphStyle]
    }

    private func searchSpanRanges() -> [NSRange] {
        var spanRanges = [NSRange]()
        if Preferences.showTitles == .appName {
            for result in window_?.swAppResults ?? [] {
                spanRanges.append(NSRange(location: result.span.lowerBound, length: result.span.count))
            }
            return spanRanges
        }
        if Preferences.showTitles == .appNameAndWindowTitle {
            let appName = window_?.application.localizedName ?? ""
            let windowTitle = window_?.title ?? ""
            let offset = (appName.isEmpty || appName == windowTitle) ? 0 : (appName + " - ").count
            for result in window_?.swAppResults ?? [] {
                spanRanges.append(NSRange(location: result.span.lowerBound, length: result.span.count))
            }
            for result in window_?.swTitleResults ?? [] {
                spanRanges.append(NSRange(location: offset + result.span.lowerBound, length: result.span.count))
            }
            return spanRanges
        }
        for result in window_?.swTitleResults ?? [] {
            spanRanges.append(NSRange(location: result.span.lowerBound, length: result.span.count))
        }
        return spanRanges
    }

    private func highlightedIndexes(_ ranges: [NSRange], _ titleLength: Int) -> Set<Int> {
        var indexes = Set<Int>()
        for range in ranges {
            if range.length <= 0 { continue }
            let start = max(0, range.location)
            let end = min(titleLength, start + range.length)
            if start >= end { continue }
            for index in start..<end {
                indexes.insert(index)
            }
        }
        return indexes
    }

    private func visibleHighlightRanges(_ visibleToOriginal: [Int?], _ highlightedIndexes: Set<Int>) -> [NSRange] {
        var ranges = [NSRange]()
        var runStart: Int?
        for (displayIndex, originalIndex) in visibleToOriginal.enumerated() {
            let highlighted = originalIndex.flatMap { highlightedIndexes.contains($0) } ?? false
            if highlighted {
                if runStart == nil {
                    runStart = displayIndex
                }
            } else if let runStartValue = runStart {
                ranges.append(NSRange(location: runStartValue, length: displayIndex - runStartValue))
                runStart = nil
            }
        }
        if let runStart {
            ranges.append(NSRange(location: runStart, length: visibleToOriginal.count - runStart))
        }
        return ranges
    }

    private func truncatedDisplay(_ title: String, maxWidth: CGFloat, mode: NSLineBreakMode, attributes: [NSAttributedString.Key: Any]) -> (text: String, visibleToOriginal: [Int?], ellipsisIndex: Int?) {
        let chars = Array(title)
        if chars.isEmpty { return ("", [], nil) }
        if maxWidth <= 0 { return ("", [], nil) }
        if measuredWidth(title, attributes) <= maxWidth {
            return (title, Array(0..<chars.count).map { Optional($0) }, nil)
        }
        let ellipsis = "…"
        if measuredWidth(ellipsis, attributes) > maxWidth {
            return (ellipsis, [nil], 0)
        }
        if mode == .byTruncatingHead {
            var low = 0
            var high = chars.count
            while low < high {
                let mid = (low + high + 1) / 2
                let candidate = ellipsis + String(chars.suffix(mid))
                if measuredWidth(candidate, attributes) <= maxWidth {
                    low = mid
                } else {
                    high = mid - 1
                }
            }
            let suffixCount = low
            let suffixStart = chars.count - suffixCount
            let text = ellipsis + String(chars.suffix(suffixCount))
            let mapping = [Int?](arrayLiteral: nil) + Array(suffixStart..<chars.count).map { Optional($0) }
            return (text, mapping, 0)
        }
        if mode == .byTruncatingMiddle {
            var leftCount = (chars.count + 1) / 2
            var rightStart = leftCount
            var candidate = String(chars.prefix(leftCount)) + ellipsis + String(chars.suffix(chars.count - rightStart))
            while measuredWidth(candidate, attributes) > maxWidth && (leftCount > 0 || rightStart < chars.count) {
                if rightStart < chars.count {
                    rightStart += 1
                }
                candidate = String(chars.prefix(leftCount)) + ellipsis + String(chars.suffix(chars.count - rightStart))
                if measuredWidth(candidate, attributes) <= maxWidth {
                    break
                }
                if leftCount > 0 {
                    leftCount -= 1
                }
                candidate = String(chars.prefix(leftCount)) + ellipsis + String(chars.suffix(chars.count - rightStart))
            }
            if measuredWidth(candidate, attributes) > maxWidth {
                return (ellipsis, [nil], 0)
            }
            let text = String(chars.prefix(leftCount)) + ellipsis + String(chars.suffix(chars.count - rightStart))
            let mapping = Array(0..<leftCount).map { Optional($0) } + [nil] + Array(rightStart..<chars.count).map { Optional($0) }
            return (text, mapping, leftCount)
        }
        var low = 0
        var high = chars.count
        while low < high {
            let mid = (low + high + 1) / 2
            let candidate = String(chars.prefix(mid)) + ellipsis
            if measuredWidth(candidate, attributes) <= maxWidth {
                low = mid
            } else {
                high = mid - 1
            }
        }
        let prefixCount = low
        let text = String(chars.prefix(prefixCount)) + ellipsis
        let mapping = Array(0..<prefixCount).map { Optional($0) } + [nil]
        return (text, mapping, prefixCount)
    }

    private func measuredWidth(_ text: String, _ attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        (text as NSString).size(withAttributes: attributes).width
    }

    private func updateSizes(_ newHeight: CGFloat, _ style: AppearanceStylePreference) {
        setFrameWidthHeight(newHeight, style)
        if style != .appIcons {
            let hWidth = frame.width - Appearance.edgeInsetsSize * 2
            let labelWidth = hWidth - appIcon.frame.width - Appearance.appIconLabelSpacing - statusIcons.totalWidth
            label.setWidth(labelWidth)
        }
    }

    private func updatePositions(_ newHeight: CGFloat, _ style: AppearanceStylePreference) {
        let edgeInsets = Appearance.edgeInsetsSize
        assignIfDifferent(&appIcon.frame.origin, NSPoint(x: edgeInsets, y: edgeInsets))
        if style != .appIcons {
            let hWidth = frame.width - edgeInsets * 2
            let hHeight = max(appIcon.frame.height, TilesView.layoutCache.labelHeight)
            if App.shared.userInterfaceLayoutDirection == .rightToLeft {
                assignIfDifferent(&appIcon.frame.origin.x, edgeInsets + hWidth - appIcon.frame.width)
            }
            statusIcons.layoutIcons(hWidth: hWidth, hHeight: hHeight, edgeInsets: edgeInsets)
            let labelWidth = hWidth - appIcon.frame.width - Appearance.appIconLabelSpacing - statusIcons.totalWidth
            let labelX: CGFloat
            if App.shared.userInterfaceLayoutDirection == .leftToRight {
                labelX = appIcon.frame.maxX + Appearance.appIconLabelSpacing
            } else {
                labelX = edgeInsets + hWidth - appIcon.frame.width - Appearance.appIconLabelSpacing - labelWidth
            }
            assignIfDifferent(&label.frame.origin.x, labelX)
            assignIfDifferent(&label.frame.origin.y, edgeInsets + ((hHeight - TilesView.layoutCache.labelHeight) / 2).rounded())
        }
        updateWindowlessAppIndicatorPosition(style)
        updateDockLabelIconPosition(style)
    }

    private func updateDockLabelIconPosition(_ style: AppearanceStylePreference) {
        let iconSize = max(appIcon.frame.width, appIcon.frame.height)
        let offset = (iconSize * (style == .appIcons && Appearance.resolvedSize == .large ? 0.03 : 0.05)).rounded()
        let badgeTopRightX = appIcon.frame.maxX + offset
        let badgeTopRightY = appIcon.frame.minY - offset
        assignIfDifferent(&dockLabelIcon.frame.origin.x, badgeTopRightX - dockLabelIcon.frame.width)
        assignIfDifferent(&dockLabelIcon.frame.origin.y, badgeTopRightY)
    }

    private func updateWindowlessAppIndicatorPosition(_ style: AppearanceStylePreference) {
        guard !windowlessAppIndicator.isHidden else { return }
        assignIfDifferent(&windowlessAppIndicator.frame.origin.x, windowlessIndicatorXPosition())
        assignIfDifferent(&windowlessAppIndicator.frame.origin.y, windowlessIndicatorYPosition(style))
        windowlessAppIndicator.needsDisplay = true
    }

    private func windowlessIndicatorXPosition() -> CGFloat {
        return (appIcon.frame.midX - windowlessAppIndicator.frame.width / 2).rounded()
    }

    private func windowlessIndicatorYPosition(_ style: AppearanceStylePreference) -> CGFloat {
        let verticalOffset = style == .titles ? CGFloat(5) : CGFloat(10)
        return (appIcon.frame.maxY - windowlessAppIndicator.frame.height + verticalOffset).rounded()
    }

    private func getAppOrAndWindowTitle() -> String {
        let appName = window_?.application.localizedName
        let windowTitle = window_?.title
        if Preferences.showTitles == .appName {
            return appName ?? ""
        } else if Preferences.showTitles == .appNameAndWindowTitle {
            if appName == windowTitle {
                return appName ?? ""
            }
            return [appName, windowTitle].compactMap { $0 }.joined(separator: " - ")
        }
        return windowTitle ?? ""
    }

    private func setFrameWidthHeight(_ newHeight: CGFloat, _ style: AppearanceStylePreference) {
        var contentWidth = CGFloat(0)
        if style == .titles {
            contentWidth = TileView.maxTileWidth(style: style) - Appearance.edgeInsetsSize * 2
        } else {
            contentWidth = Appearance.iconSize
        }
        let frameWidth = (contentWidth + Appearance.edgeInsetsSize * 2).rounded()
        let widthMin = TileView.minTileWidth()
        let width = max(frameWidth, widthMin).rounded()
        assignIfDifferent(&frame.size.width, width)
        assignIfDifferent(&frame.size.height, newHeight)
    }

    private func getAccessibilityHelp(_ appName: String?, _ dockLabel: String?) -> String {
        [appName, dockLabel.map { getAccessibilityTextForBadge($0) }]
            .compactMap { $0 }
            .joined(separator: " - ")
    }

    private func getAccessibilityTextForBadge(_ dockLabel: String) -> String {
        if let dockLabelInt = Int(dockLabel) {
            return "Red badge with number \(dockLabelInt)"
        }
        return "Red badge"
    }

    static func makeShadow(_ color: NSColor?) -> NSShadow? {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 1
        return shadow
    }

    static func makeAppIconShadow(_ color: NSColor?) -> NSShadow? {
        guard let color else { return nil }
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.4)
        shadow.shadowOffset = NSSize(width: 0.1, height: 1)
        shadow.shadowBlurRadius = 2
        return shadow
    }

    static func maxTileWidth(_ screen: NSScreen = NSScreen.preferred) -> CGFloat {
        let style = Preferences.appearanceStyle(SwitcherSession.current?.presentationSource ?? .shortcut(0))
        return maxTileWidth(style: style, screen: screen)
    }

    static func maxTileWidth(style: AppearanceStylePreference,
                             screen: NSScreen = NSScreen.preferred) -> CGFloat {
        return TilesPanel.maxRowWidth(style: style, screen: screen) * Appearance.windowMaxWidthInRow - Appearance.interCellPadding * 2
    }

    static func widthOfComfortableReadability() -> CGFloat? {
        let labTitleView = TileTitleView(font: Appearance.font)
        labTitleView.stringValue = "abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz-abcdefghijklmnopqrstuvwxyz" + extraTextForPadding
        return labTitleView.cell!.cellSize.width
    }

    static func widthOfLongestTitle() -> CGFloat? {
        let labTitleView = TileTitleView(font: Appearance.font)
        var maxWidth = CGFloat(0)
        for window in Windows.list {
            guard window.shouldShowTheUser else { continue }
            labTitleView.stringValue = window.title + extraTextForPadding
            let width = labTitleView.cell!.cellSize.width
            if width > maxWidth {
                maxWidth = width
            }
        }
        guard maxWidth > 0 else { return nil }
        return maxWidth
    }

    static func minTileWidth(_ screen: NSScreen = NSScreen.preferred) -> CGFloat {
        let style = Preferences.appearanceStyle(SwitcherSession.current?.presentationSource ?? .shortcut(0))
        return minTileWidth(style: style, screen: screen)
    }

    static func minTileWidth(style: AppearanceStylePreference,
                             screen: NSScreen = NSScreen.preferred) -> CGFloat {
        return TilesPanel.maxRowWidth(style: style, screen: screen) * Appearance.windowMinWidthInRow - Appearance.interCellPadding * 2
    }

    static func iconSize(_ screen: NSScreen = NSScreen.preferred) -> NSSize {
        let style = Preferences.appearanceStyle(SwitcherSession.current?.presentationSource ?? .shortcut(0))
        return iconSize(style: style, screen: screen)
    }

    static func iconSize(style: AppearanceStylePreference,
                         screen: NSScreen = NSScreen.preferred) -> NSSize {
        let minimumWidth = style == .appIcons ? minTileWidth(style: style, screen: screen) : 0
        return TilePresentationResolver.iconSize(
            usesAppIconLayout: style == .appIcons,
            baseIconSize: Appearance.iconSize,
            minimumTileWidth: minimumWidth,
            edgeInsets: Appearance.edgeInsetsSize)
    }

    static func height(_ labelHeight: CGFloat) -> CGFloat {
        let style = Preferences.appearanceStyle(SwitcherSession.current?.presentationSource ?? .shortcut(0))
        return height(labelHeight, style: style)
    }

    static func height(_ labelHeight: CGFloat, style: AppearanceStylePreference) -> CGFloat {
        let iconHeight = TileView.iconSize(style: style).height
        if style == .appIcons {
            return iconHeight + Appearance.edgeInsetsSize * 2 + Appearance.intraCellPadding * 2 + labelHeight
        }
        return max(iconHeight, labelHeight) + Appearance.edgeInsetsSize * 2
    }
}

private extension NSSize {
    func scaled(by scale: CGFloat) -> NSSize {
        NSSize(width: width * scale, height: height * scale)
    }
}
