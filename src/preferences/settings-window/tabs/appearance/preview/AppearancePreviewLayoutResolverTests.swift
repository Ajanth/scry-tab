import XCTest

final class AppearancePreviewLayoutResolverTests: XCTestCase {
    private let mainHost = CGSize(width: 320, height: 200)
    private let compactHost = CGSize(width: 220, height: 137.5)
    private let statusCounts = [2, 2, 1]
    private let tahoe = AppearancePreviewPlatform.macOS26(supportsClearGlass: true)

    /// App Icons panel, tiles, and highlight remain inside the main Appearance and compact Controls hosts.
    func testAppIconsFramesFitBothHosts() {
        for host in [mainHost, compactHost] {
            let layout = resolve(.appIcons, host: host, focusedIndex: 1)
            assertLayout(layout, fits: host)
        }
    }

    /// Titles panel, rows, and highlight remain inside the main Appearance and compact Controls hosts.
    func testTitlesFramesFitBothHosts() {
        for host in [mainHost, compactHost] {
            let layout = resolve(.titles, host: host, focusedIndex: 0)
            assertLayout(layout, fits: host)
        }
    }

    /// App Icons uses the live medium tile highlight geometry around the icon and edge insets.
    func testAppIconsHighlightMatchesLiveTileGeometry() {
        let layout = resolve(.appIcons, host: mainHost, focusedIndex: 1)
        let tile = layout.tileLayouts[1]
        XCTAssertEqual(layout.selectionFrame.origin, tile.frame.origin)
        XCTAssertEqual(layout.selectionFrame.width, tile.frame.width)
        XCTAssertEqual(
            layout.selectionFrame.height,
            tile.iconFrame.height + tile.iconFrame.minY * 2,
            accuracy: 0.001)
        XCTAssertEqual(layout.selectionCornerRadius, 24)
        XCTAssertEqual(layout.selectionBorderWidth, 2)
    }

    /// Titles uses the live medium row geometry, panel padding, dense spacing, and full-row highlight.
    func testTitlesGeometryMatchesLiveMediumLayout() {
        let layout = resolve(.titles, host: mainHost, focusedIndex: 0)
        XCTAssertEqual(layout.panelFrame, CGRect(x: 16, y: 23, width: 288, height: 154))
        XCTAssertEqual(layout.tileLayouts[0].frame, CGRect(x: 19, y: 19, width: 250, height: 38))
        XCTAssertEqual(layout.tileLayouts[0].iconFrame, CGRect(x: 7, y: 7, width: 24, height: 24))
        XCTAssertEqual(layout.tileLayouts[0].labelFrame.minX, 33)
        XCTAssertEqual(layout.tileLayouts[1].frame.minY - layout.tileLayouts[0].frame.maxY, 1)
        XCTAssertEqual(layout.selectionFrame, layout.tileLayouts[0].frame)
        XCTAssertEqual(layout.selectionCornerRadius, 10)
        XCTAssertEqual(layout.selectionBorderWidth, 2)
    }

    /// App Icons remains centered in both settings hosts after uniform production-geometry scaling.
    func testAppIconsCentersInBothHosts() {
        for host in [mainHost, compactHost] {
            let layout = resolve(.appIcons, host: host, focusedIndex: 1)
            XCTAssertEqual(layout.panelFrame.midX, host.width / 2, accuracy: 0.25)
            XCTAssertEqual(layout.panelFrame.midY, host.height / 2, accuracy: 0.25)
            guard let first = layout.tileLayouts.first,
                  let last = layout.tileLayouts.last else {
                XCTFail("Expected demo tiles")
                continue
            }
            XCTAssertEqual(
                first.frame.minX,
                layout.panelFrame.width - last.frame.maxX,
                accuracy: 0.5)
        }
    }

    /// App Icons reproduces production icon, font, inset, and Tahoe radius metrics for every size.
    func testAppIconsAllSizesMatchProductionMetrics() {
        let cases: [(AppearancePreviewSize, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (.small, 70, 13, 24, 0),
            (.medium, 110, 14, 35, 5),
            (.large, 150, 16, 45, 10),
        ]
        for (size, iconSize, fontSize, cellRadius, outerLabelInset) in cases {
            let layout = resolve(.appIcons, size: size, host: mainHost, focusedIndex: 1)
            XCTAssertEqual(layout.tileLayouts[1].iconFrame.width / layout.contentScale, iconSize, accuracy: 1)
            XCTAssertEqual(layout.tileLayouts[1].iconFrame.minX / layout.contentScale, 6, accuracy: 1)
            XCTAssertEqual(layout.tileLayouts[0].labelFrame.minX / layout.contentScale, outerLabelInset, accuracy: 1)
            XCTAssertEqual(layout.visualStyle.fontPointSize, fontSize)
            XCTAssertEqual(layout.selectionCornerRadius / layout.contentScale, cellRadius, accuracy: 1)
        }
    }

    /// Titles reproduces production icon, font, label, row, and status metrics for every size.
    func testTitlesAllSizesMatchProductionMetrics() {
        let cases: [(AppearancePreviewSize, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (.small, 18, 13, 32, 11),
            (.medium, 24, 14, 38, 12),
            (.large, 30, 16, 44, 14),
        ]
        for (size, iconSize, fontSize, rowHeight, statusFontSize) in cases {
            let layout = resolve(.titles, size: size, host: mainHost, focusedIndex: 0)
            XCTAssertEqual(layout.tileLayouts[0].iconFrame.width / layout.contentScale, iconSize, accuracy: 1)
            XCTAssertEqual(layout.tileLayouts[0].frame.height / layout.contentScale, rowHeight, accuracy: 1)
            XCTAssertEqual(layout.visualStyle.fontPointSize, fontSize)
            XCTAssertEqual(layout.visualStyle.statusFontPointSize, statusFontSize)
        }
    }

    /// Pre-Tahoe App Icons keeps production legacy insets and radii across every concrete size.
    func testLegacyAppIconsAllSizesMatchProductionMetrics() {
        for size in [AppearancePreviewSize.small, .medium, .large] {
            let layout = resolve(
                .appIcons,
                size: size,
                host: mainHost,
                focusedIndex: 1,
                platform: .legacy)
            XCTAssertEqual(layout.tileLayouts[1].iconFrame.minX / layout.contentScale, 5, accuracy: 1)
            XCTAssertEqual(layout.panelCornerRadius / layout.contentScale, 23, accuracy: 1)
            XCTAssertEqual(layout.selectionCornerRadius / layout.contentScale, 10, accuracy: 1)
        }
    }

    /// Final panel, tile, icon, label, status, and highlight edges align to the supplied backing scale.
    func testResolvedFramesArePixelAligned() {
        for style in [AppearancePreviewStyle.appIcons, .titles] {
            let layout = AppearancePreviewLayoutResolver.resolve(
                style: style,
                size: .medium,
                itemStatusCounts: statusCounts,
                focusedIndex: 1,
                hostSize: CGSize(width: 233, height: 147),
                backingScale: 2,
                platform: tahoe)
            let rects = [layout.panelFrame, layout.selectionFrame] + layout.tileLayouts.flatMap {
                [$0.frame, $0.iconFrame, $0.labelFrame, $0.statusFrame]
            }
            rects.forEach { assertPixelAligned($0, backingScale: 2) }
        }
    }

    /// Titles mirrors icon, label, and status geometry in both settings hosts for right-to-left locales.
    func testTitlesMirrorsForRightToLeftLayout() {
        for host in [mainHost, compactHost] {
            let leftToRight = resolve(.titles, host: host, focusedIndex: 0)
            let rightToLeft = resolve(
                .titles,
                host: host,
                focusedIndex: 0,
                layoutDirection: .rightToLeft)
            let rowWidth = leftToRight.tileLayouts[0].frame.width
            XCTAssertEqual(
                rightToLeft.tileLayouts[0].iconFrame.minX,
                rowWidth - leftToRight.tileLayouts[0].iconFrame.maxX,
                accuracy: 0.001)
            XCTAssertEqual(
                rightToLeft.tileLayouts[0].labelFrame.minX,
                rowWidth - leftToRight.tileLayouts[0].labelFrame.maxX,
                accuracy: 0.001)
            XCTAssertEqual(
                rightToLeft.tileLayouts[0].statusFrame.minX,
                rowWidth - leftToRight.tileLayouts[0].statusFrame.maxX,
                accuracy: 0.001)
        }
    }

    /// App Icons mirrors tile order while preserving each tile's centered icon and label geometry.
    func testAppIconsMirrorsTileOrderForRightToLeftLayout() {
        for host in [mainHost, compactHost] {
            let leftToRight = resolve(.appIcons, host: host, focusedIndex: 1)
            let rightToLeft = resolve(
                .appIcons,
                host: host,
                focusedIndex: 1,
                layoutDirection: .rightToLeft)
            zip(leftToRight.tileLayouts, rightToLeft.tileLayouts).forEach { left, right in
                XCTAssertEqual(
                    right.frame.minX,
                    leftToRight.panelFrame.width - left.frame.maxX,
                    accuracy: 0.5)
                XCTAssertEqual(right.iconFrame, left.iconFrame)
                XCTAssertEqual(right.labelFrame, left.labelFrame)
            }
        }
    }

    /// Resizing the host does not change which App Icons label is visible.
    func testHostResizePreservesFocusedLabelVisibility() {
        let main = resolve(.appIcons, host: mainHost, focusedIndex: 1)
        let compact = resolve(.appIcons, host: compactHost, focusedIndex: 1)
        XCTAssertEqual(main.tileLayouts.map(\.showsLabel), [false, true, false])
        XCTAssertEqual(compact.tileLayouts.map(\.showsLabel), [false, true, false])
    }

    /// Resolving App Icons after Titles immediately includes the focused label state.
    func testTitlesToAppIconsShowsFocusedLabelImmediately() {
        _ = resolve(.titles, host: mainHost, focusedIndex: 0)
        let appIcons = resolve(.appIcons, host: mainHost, focusedIndex: 1)
        XCTAssertEqual(appIcons.tileLayouts.map(\.showsLabel), [false, true, false])
        XCTAssertFalse(appIcons.selectionFrame.isEmpty)
    }

    /// Repeated App Icons and Titles resolution always restores the same style-specific highlight.
    func testRepeatedStyleSwitchingDoesNotRetainHighlightGeometry() {
        let firstAppIcons = resolve(.appIcons, host: compactHost, focusedIndex: 1)
        let titles = resolve(.titles, host: compactHost, focusedIndex: 0)
        let secondAppIcons = resolve(.appIcons, host: compactHost, focusedIndex: 1)
        XCTAssertNotEqual(firstAppIcons.selectionFrame, titles.selectionFrame)
        XCTAssertEqual(firstAppIcons.selectionFrame, secondAppIcons.selectionFrame)
        XCTAssertEqual(firstAppIcons.selectionCornerRadius, secondAppIcons.selectionCornerRadius)
    }

    /// Tahoe selects clear glass only for App Icons and keeps live panel shadow and font-weight decisions.
    func testTahoeVisualDecisionsMatchLiveSwitcher() {
        let appIcons = resolve(.appIcons, host: mainHost, focusedIndex: 1)
        XCTAssertEqual(appIcons.visualStyle.materialKind, .liquidGlassClear)
        XCTAssertEqual(appIcons.visualStyle.fontWeight, .semibold)
        XCTAssertEqual(appIcons.visualStyle.fontPointSize, 14)
        XCTAssertFalse(appIcons.visualStyle.usesPanelShadow)
        XCTAssertEqual(appIcons.visualStyle.panelBorderWidth, 0)
        let titles = resolve(.titles, host: mainHost, focusedIndex: 0)
        XCTAssertEqual(titles.visualStyle.materialKind, .liquidGlassRegular)
        XCTAssertEqual(titles.visualStyle.fontWeight, .medium)
        XCTAssertEqual(titles.visualStyle.fontPointSize, 14)
        XCTAssertTrue(titles.visualStyle.usesPanelShadow)
        XCTAssertEqual(titles.visualStyle.panelBorderWidth, 0)
        let regularFallback = resolve(
            .appIcons,
            host: mainHost,
            focusedIndex: 1,
            platform: .macOS26(supportsClearGlass: false))
        XCTAssertEqual(regularFallback.visualStyle.materialKind, .liquidGlassRegular)
        XCTAssertTrue(regularFallback.visualStyle.usesPanelShadow)
    }

    /// Pre-Tahoe previews use the live frosted fallback, regular fonts, shadows, and legacy radii.
    func testLegacyVisualDecisionsMatchLiveSwitcher() {
        let legacy = resolve(
            .appIcons,
            host: mainHost,
            focusedIndex: 1,
            platform: .legacy)
        XCTAssertEqual(legacy.visualStyle.materialKind, .frosted)
        XCTAssertEqual(legacy.visualStyle.fontWeight, .regular)
        XCTAssertEqual(legacy.visualStyle.fontPointSize, 14)
        XCTAssertTrue(legacy.visualStyle.usesPanelShadow)
        XCTAssertEqual(legacy.visualStyle.panelBorderWidth, 0)
        XCTAssertLessThan(legacy.panelCornerRadius, resolve(.appIcons, host: mainHost, focusedIndex: 1).panelCornerRadius)
    }

    private func resolve(_ style: AppearancePreviewStyle,
                         size: AppearancePreviewSize = .medium,
                         host: CGSize,
                         focusedIndex: Int,
                         platform: AppearancePreviewPlatform? = nil,
                         layoutDirection: AppearancePreviewLayoutDirection = .leftToRight) -> AppearancePreviewLayout {
        AppearancePreviewLayoutResolver.resolve(
            style: style,
            size: size,
            itemStatusCounts: statusCounts,
            focusedIndex: focusedIndex,
            hostSize: host,
            backingScale: 2,
            platform: platform ?? tahoe,
            layoutDirection: layoutDirection)
    }

    private func assertLayout(_ layout: AppearancePreviewLayout,
                              fits host: CGSize,
                              file: StaticString = #file,
                              line: UInt = #line) {
        let hostBounds = CGRect(origin: .zero, size: host)
        XCTAssertTrue(hostBounds.contains(layout.panelFrame), file: file, line: line)
        let panelBounds = CGRect(origin: .zero, size: layout.panelFrame.size)
        XCTAssertTrue(panelBounds.contains(layout.selectionFrame), file: file, line: line)
        layout.tileLayouts.forEach {
            XCTAssertTrue(panelBounds.contains($0.frame), file: file, line: line)
            XCTAssertTrue(
                CGRect(origin: .zero, size: $0.frame.size).contains($0.iconFrame),
                file: file,
                line: line)
        }
    }

    private func assertPixelAligned(_ rect: CGRect,
                                    backingScale: CGFloat,
                                    file: StaticString = #file,
                                    line: UInt = #line) {
        [rect.minX, rect.minY, rect.maxX, rect.maxY].forEach {
            XCTAssertEqual(
                $0 * backingScale,
                ($0 * backingScale).rounded(),
                accuracy: 0.0001,
                file: file,
                line: line)
        }
    }
}
