import Cocoa

/// `NSPopUpButton` configured to look like System Settings popups and — critically — to size
/// itself to the *currently-selected* item rather than the widest one (the AppKit default).
///
/// There is no public API to opt into "size to current item" — `NSPopUpButton` is hardcoded to
/// reserve room for its widest item so the chrome doesn't visually resize when the user picks a
/// different selection. To get pixel-perfect bezel + arrow + padding metrics, the only viable
/// path is to override `intrinsicContentSize` and have AppKit measure a *probe* button that
/// happens to contain just the current title.
///
/// The previous version did that probe measurement on *every* `intrinsicContentSize` query.
/// AppKit queries the property many times per layout cycle, and the `_windowChangedKeyState`
/// cascade fires a fresh layout cycle on every focus change — so we were running `sizeToFit`
/// (which triggers TextKit2 layout on Tahoe) ~50 times per cascade × ~25 popups in Settings.
/// Roughly 50ms of pure overhead per focus switch from this one method.
///
/// Fix: keep the probe technique (preserves pixel-identical sizing), cache the result keyed by
/// the displayed title. The cache is invalidated automatically next time `title` changes (which
/// happens on every selection mutation), so we don't have to override every individual mutator
/// path. AppKit's repeated queries hit the cache in O(1).
class PopupButtonLikeSystemSettings: NSPopUpButton {
    var drawsAppOwnedSurface: Bool { true }
    private var cachedIntrinsicSize: NSSize?
    private var cachedIntrinsicSizeTitle: String?
    private var hovered = false
    private var pressed = false
    private var trackingArea: NSTrackingArea?
    private var windowObservers = [NSObjectProtocol]()
    private var accessibilityObserver: NSObjectProtocol?

    convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }

    override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        DesignSystemControlStyler.stylePopupButton(self)
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    deinit {
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
    }

    override var intrinsicContentSize: NSSize {
        let currentTitle = title
        if let cached = cachedIntrinsicSize, cachedIntrinsicSizeTitle == currentTitle {
            return cached
        }
        let size: NSSize
        if let selectedItem {
            size = measureSize(for: currentTitle, image: selectedItem.image)
        } else {
            size = super.intrinsicContentSize
        }
        cachedIntrinsicSize = size
        cachedIntrinsicSizeTitle = currentTitle
        return size
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        pressed = false
        needsDisplay = true
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        pressed = true
        needsDisplay = true
        super.mouseDown(with: event)
        pressed = false
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservers.forEach { NotificationCenter.default.removeObserver($0) }
        windowObservers.removeAll()
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.needsDisplay = true
                })
            }
        }
        accessibilityObserver = NotificationCenter.default.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.needsDisplay = true
        }
        needsDisplay = true
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { needsDisplay = true }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { needsDisplay = true }
        return resigned
    }

    override func draw(_ dirtyRect: NSRect) {
        drawSurface()
        super.draw(dirtyRect)
    }

    /// Probe measurement — pixel-identical to what AppKit would compute for a popup whose menu
    /// has a single item with this title. Heavy (full TextKit layout via `sizeToFit`), hence
    /// the caller caches the result.
    private func measureSize(for titleText: String, image: NSImage?) -> NSSize {
        let probe = NSPopUpButton()
        probe.addItem(withTitle: titleText)
        probe.item(at: 0)!.image = image
        let probeCell = probe.cell! as! NSPopUpButtonCell
        let selfCell = cell! as! NSPopUpButtonCell
        probe.isBordered = isBordered
        probeCell.bezelStyle = selfCell.bezelStyle
        probeCell.arrowPosition = selfCell.arrowPosition
        probeCell.imagePosition = selfCell.imagePosition
        probe.font = font
        probe.controlSize = controlSize
        probe.showsBorderOnlyWhileMouseInside = showsBorderOnlyWhileMouseInside
        probe.sizeToFit()
        return probe.intrinsicContentSize
    }

    private func drawSurface() {
        let lineWidth = isFocused ? CGFloat(1.5) : CGFloat(1)
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: rect, xRadius: DesignSystem.Metrics.controlRadius, yRadius: DesignSystem.Metrics.controlRadius)
        surfaceFillColor().setFill()
        path.fill()
        borderColor().setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func surfaceFillColor() -> NSColor {
        if !isEnabled {
            return DesignSystem.color(.surfaceFlat, appearance: effectiveAppearance).withAlphaComponent(0.5)
        }
        if pressed {
            return DesignSystem.color(.surfacePressed, appearance: effectiveAppearance)
        }
        if hovered {
            return DesignSystem.color(.surfaceHover, appearance: effectiveAppearance)
        }
        return DesignSystem.color(.surfaceFlat, appearance: effectiveAppearance)
    }

    private func borderColor() -> NSColor {
        isFocused ? DesignSystem.color(.focusAccent, appearance: effectiveAppearance) : DesignSystem.color(.borderSubtle, appearance: effectiveAppearance)
    }

    private var isFocused: Bool { window?.firstResponder == self && NSApp.isActive }
}
