import Cocoa

class TileOverView: FlippedView {
    weak var scrollView: ScrollView?
    var previousTarget: TileView?

    @objc func _windowChangedKeyState() {}
    @objc func _layoutSubtreeWithOldSize(_ oldSize: NSSize) {}

    convenience init() {
        self.init(frame: .zero)
        wantsLayer = true
        layer!.masksToBounds = false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    // MARK: - Mouse hover management

    func updateHover() {
        guard let scrollView, !scrollView.isCurrentlyScrolling, !TilesView.hasMarkedText(), !ContextMenuEvents.isMenuOpen else { return }
        let location = convert(TilesPanel.shared.mouseLocationOutsideOfEventStream, from: nil)
        let newTarget = findTarget(location)
        if let target = newTarget ?? previousTarget {
            let statusFrame = target.convert(target.statusIcons.frame, to: superview)
            if statusFrame.contains(location) {
                target.statusIcons.ensureTooltipsInstalled()
            }
        }
        guard newTarget !== previousTarget else { return }
        caTransaction {
            if let newTarget {
                newTarget.mouseMoved()
            } else {
                resetHoveredWindow()
            }
            previousTarget = newTarget
        }
    }

    func findTarget(_ location: NSPoint) -> TileView? {
        guard let documentView = superview else { return nil }
        for case let view as TileView in documentView.subviews {
            let frame = view.frame
            let expandedFrame = CGRect(x: frame.minX - (App.shared.userInterfaceLayoutDirection == .leftToRight ? 0 : 1), y: frame.minY, width: frame.width + 1, height: frame.height + 1)
            if expandedFrame.contains(location) {
                return view
            }
        }
        return nil
    }

    func resetHoveredWindow() {
        previousTarget = nil
        if let oldIndex = SwitcherSession.current?.hoveredIndex {
            SwitcherSession.current?.hoveredIndex = nil
            TilesView.highlight(oldIndex)
        }
    }
}
