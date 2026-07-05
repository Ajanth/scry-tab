import Cocoa

final class AppearanceLivePreviewPlaybackController {
    private(set) var isManuallyPaused = false
    var isWindowVisible: (() -> Bool)?
    var onAdvance: (() -> Void)?
    var onPauseStateRefresh: (() -> Void)?
    var onAccessibilityDisplayOptionsChanged: (() -> Void)?

    private var timer: Timer?
    private var accessibilityDisplayObserver: NSObjectProtocol?

    deinit {
        timer?.invalidate()
        if let accessibilityDisplayObserver {
            NotificationCenter.default.removeObserver(accessibilityDisplayObserver)
        }
    }

    func start() {
        guard timer == nil, accessibilityDisplayObserver == nil else { return }
        scheduleTimer()
        observeAccessibilityDisplayOptions()
    }

    func toggleManualPause() {
        isManuallyPaused.toggle()
        onPauseStateRefresh?()
    }

    private func scheduleTimer() {
        let interval = AppearanceLivePreviewResolver.advanceInterval
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.handleTimerTick()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func observeAccessibilityDisplayOptions() {
        accessibilityDisplayObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.onPauseStateRefresh?()
            self?.onAccessibilityDisplayOptionsChanged?()
        }
    }

    private func handleTimerTick() {
        onPauseStateRefresh?()
        guard shouldRun() else { return }
        onAdvance?()
    }

    private func shouldRun() -> Bool {
        AppearanceLivePreviewResolver.shouldRun(
            isManuallyPaused: isManuallyPaused,
            isWindowVisible: isWindowVisible?() ?? false,
            isSwitcherActive: SwitcherSession.isActive,
            prefersReducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }
}

final class AppearanceLivePreviewPlaybackGlyphView: NSView {
    enum Symbol {
        case play
        case pause
    }

    var symbol: Symbol {
        didSet {
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        let size = AppearanceLivePreviewArtwork.Metrics.pauseButtonGlyphSize
        return NSSize(width: size, height: size)
    }

    init(symbol: Symbol) {
        self.symbol = symbol
        let size = AppearanceLivePreviewArtwork.Metrics.pauseButtonGlyphSize
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: size, height: size)))
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    override func draw(_ dirtyRect: NSRect) {
        AppearanceLivePreviewArtwork.Palette.pauseGlyph.setFill()
        guard symbol == .pause else {
            drawPlay()
            return
        }
        drawPause()
    }

    private func drawPlay() {
        let rect = bounds.insetBy(dx: bounds.width * 0.2, dy: bounds.height * 0.12)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.midY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.close()
        path.fill()
    }

    private func drawPause() {
        let height = bounds.height * 0.74
        let width = bounds.width * 0.24
        let gap = bounds.width * 0.18
        let y = bounds.midY - height / 2
        let leftX = bounds.midX - gap / 2 - width
        let rightX = bounds.midX + gap / 2
        drawPauseBar(NSRect(x: leftX, y: y, width: width, height: height))
        drawPauseBar(NSRect(x: rightX, y: y, width: width, height: height))
    }

    private func drawPauseBar(_ rect: NSRect) {
        let radius = rect.width / 2
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
}
