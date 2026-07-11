import Cocoa

class TilesPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    static var maxPossibleAppIconSize = NSSize.zero
    static var shared: TilesPanel!
    private var frozenTopCenter: NSPoint?
    private var highWaterHeight: CGFloat = 0
    var hasCustomContent = false

    convenience init() {
        self.init(contentRect: .zero, styleMask: .nonactivatingPanel, backing: .buffered, defer: false)
        delegate = self
        isFloatingPanel = true
        animationBehavior = .none
        hidesOnDeactivate = false
        titleVisibility = .hidden
        backgroundColor = .clear
        TilesView.initialize()
        contentView! = TilesView.contentView
        // triggering ScryTab before or during Space transition animation brings the window on the Space post-transition
        collectionBehavior = .canJoinAllSpaces
        // 2nd highest level possible; this allows the app to go on top of context menus
        // highest level is .screenSaver but makes drag and drop on top the main window impossible
        level = .popUpMenu
        setAccessibilitySubrole(.unknown)
        // for VoiceOver
        setAccessibilityLabel(App.name)
        updateAppearance()
        Self.shared = self
    }

    func updateAppearance() {
        hasShadow = Appearance.enablePanelShadow
        appearance = NSAppearance(named: Appearance.currentTheme == .dark ? .vibrantDark : .vibrantLight)
    }

    func updateContents(_ preservedScrollOrigin: CGPoint?) {
        caTransaction {
            TilesView.updateItemsAndLayout(preservedScrollOrigin)
            guard SwitcherSession.isActive else { return }
            setContentSize(TilesView.contentView.frame.size)
            guard SwitcherSession.isActive else { return }
            repositionOrFreeze()
        }
        // prevent further AppKit work
        TilesView.clearNeedsLayout()
    }


    private func repositionOrFreeze() {
        let size = frame.size
        guard TilesView.isSearchModeOn else {
            NSScreen.preferred.repositionPanel(self)
            resetFrozenPosition()
            return
        }
        if size.height > highWaterHeight {
            NSScreen.preferred.repositionPanel(self)
            highWaterHeight = size.height
            frozenTopCenter = NSPoint(x: frame.midX, y: frame.maxY)
        } else if let topCenter = frozenTopCenter {
            setFrameOrigin(NSPoint(x: topCenter.x - size.width * 0.5, y: topCenter.y - size.height))
        }
    }

    func resetFrozenPosition() {
        frozenTopCenter = nil
        highWaterHeight = 0
    }

    override func orderOut(_ sender: Any?) {
        if !hasCustomContent {
            TilesView.clearNeedsLayout()
        }
        // orderOut requires WindowServer. Let's hide before calling it, in case it lags
        alphaValue = 0
        super.orderOut(sender)
    }

    func show() {
        updateAppearance()
        // The panel may have been hidden (alpha=0) by `App.showUiOrCycleSelection` on a
        // cross-shortcut summon to mask the rebuild. Reveal it atomically now that contents
        // and Appearance are in their final state.
        alphaValue = 1
        makeKeyAndOrderFront(nil)
        ContextMenuEvents.toggle(true)
        CursorEvents.toggle(true)
        if !hasCustomContent {
            DispatchQueue.main.async { TilesView.scrollView.flashScrollers() }
        }
    }

    static func maxRowWidth(_ screen: NSScreen = NSScreen.preferred) -> CGFloat {
        maxRowWidth(
            style: Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex),
            screen: screen)
    }

    static func maxRowWidth(style: AppearanceStylePreference,
                            screen: NSScreen = NSScreen.preferred) -> CGFloat {
        if style == .titles,
           let readableWidth = TilesView.layoutCache.comfortableReadabilityWidth {
            return titleMaxRowWidth(readableWidth: readableWidth, screen: screen)
        }
        return (screen.frame.width * Appearance.maxWidthOnScreen - Appearance.windowPadding * 2).rounded()
    }

    static func titleMaxRowWidth(readableWidth: CGFloat,
                                 screen: NSScreen = NSScreen.preferred) -> CGFloat {
        return (
            min(
                screen.frame.width * Appearance.maxWidthOnScreen,
                readableWidth + Appearance.intraCellPadding * 2 + Appearance.appIconLabelSpacing + Appearance.iconSize
                // widthOfLongestTitle + Appearance.intraCellPadding * 2 + Appearance.appIconLabelSpacing + Appearance.iconSize
            ) - Appearance.windowPadding * 2
        ).rounded()
    }

    static func maxRowHeight(_ screen: NSScreen = NSScreen.preferred) -> CGFloat {
        return (screen.frame.height * Appearance.maxHeightOnScreen - Appearance.windowPadding * 2).rounded()
    }

    static func updateMaxPossibleAppIconSize() {
        let (w, h) = NSScreen.screens.reduce((CGFloat.zero, CGFloat.zero)) { acc, screen in
            let size = TileView.iconSize(screen)
            return (max(acc.0, size.width * screen.backingScaleFactor),
                max(acc.1, size.height * screen.backingScaleFactor))
        }
        maxPossibleAppIconSize = NSSize(width: w.rounded(), height: h.rounded())
    }
}

extension TilesPanel: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // other windows can steal key focus from scry-tab; we make sure that if it's active, if keeps key focus
        // dispatching to the main queue is necessary to introduce a delay in scheduling the makeKey; otherwise it is ignored
        DispatchQueue.main.async {
            if SwitcherSession.isActive {
                TilesPanel.shared.makeKeyAndOrderFront(nil)
            }
            MainMenu.toggle(true)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // we toggle the mainMenu off when showing the main window
        // this avoids command+q from quitting ScryTab itself, or command+p from printing
        DispatchQueue.main.async {
            MainMenu.toggle(false)
            if TilesView.isSearchEditing || TilesPanel.shared.hasCustomContent {
                MainMenu.toggleEditMenu(true)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            Applications.manuallyRefreshAllWindows()
        }
    }
}
