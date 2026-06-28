import Cocoa

private final class MaterialSurfaceNoAnimationDelegate: NSObject, CALayerDelegate {
    static let shared = MaterialSurfaceNoAnimationDelegate()
    func action(for layer: CALayer, forKey event: String) -> (any CAAction)? { NSNull() }
}

struct MaterialSurfaceLayerIdentity: Equatable {
    let effectView: ObjectIdentifier
    let tintLayer: ObjectIdentifier
    let gradientLayer: ObjectIdentifier?
    let borderLayer: ObjectIdentifier?
}

final class MaterialSurfaceView: NSView {
    var role: DesignSurfaceRole {
        didSet { applyRoleChange() }
    }
    var componentState: DesignComponentState {
        didSet { updateAppearance() }
    }
    private let effectView = NSVisualEffectView()
    private let tintLayer = CALayer()
    private var gradientLayer: CAGradientLayer?
    private var borderLayer: CALayer?
    private var lastAccessibilityOptions = DesignAccessibilityOptions.current

    init(role: DesignSurfaceRole = .plateau, state: DesignComponentState = DesignComponentState()) {
        self.role = role
        self.componentState = state
        super.init(frame: .zero)
        setupView()
        applyRoleChange()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    var layerIdentity: MaterialSurfaceLayerIdentity {
        MaterialSurfaceLayerIdentity(effectView: ObjectIdentifier(effectView),
                                     tintLayer: ObjectIdentifier(tintLayer),
                                     gradientLayer: gradientLayer.map(ObjectIdentifier.init),
                                     borderLayer: borderLayer.map(ObjectIdentifier.init))
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        updateLayerFrames()
    }

    @available(macOS 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAppearance()
    }

    func accessibilityDisplayOptionsDidChange(_ options: DesignAccessibilityOptions = .current) {
        guard options != lastAccessibilityOptions else { return }
        lastAccessibilityOptions = options
        updateAppearance(environment: DesignSystemEnvironment(colorScheme: DesignColorScheme.resolve(from: currentAppearance), isActive: window?.isKeyWindow ?? NSApp.isActive, accessibility: options))
    }

    func refreshAppearance() {
        updateAppearance()
    }

    var tintCompositingFilterForTests: Any? { tintLayer.compositingFilter }

    #if DEBUG
    func applyPreviewEnvironment(_ environment: DesignSystemEnvironment) {
        updateAppearance(environment: environment)
    }
    #endif

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)
        layer?.masksToBounds = false
        layer?.addSublayer(tintLayer)
        tintLayer.delegate = MaterialSurfaceNoAnimationDelegate.shared
        tintLayer.compositingFilter = "multiplyBlendMode"
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func applyRoleChange() {
        updateOptionalLayers()
        updateAppearance()
    }

    private func updateOptionalLayers() {
        if role.usesGradientLayer {
            ensureGradientLayer()
        } else {
            gradientLayer?.removeFromSuperlayer()
            gradientLayer = nil
        }
        if role.usesBorderLayer {
            ensureBorderLayer()
        } else {
            borderLayer?.removeFromSuperlayer()
            borderLayer = nil
        }
    }

    private func ensureGradientLayer() {
        guard gradientLayer == nil else { return }
        let layer = CAGradientLayer()
        layer.delegate = MaterialSurfaceNoAnimationDelegate.shared
        self.layer?.addSublayer(layer)
        gradientLayer = layer
    }

    private func ensureBorderLayer() {
        guard borderLayer == nil else { return }
        let layer = CALayer()
        layer.delegate = MaterialSurfaceNoAnimationDelegate.shared
        self.layer?.addSublayer(layer)
        borderLayer = layer
    }

    private func updateAppearance(environment: DesignSystemEnvironment? = nil) {
        let resolvedEnvironment = environment ?? DesignSystemEnvironment.current(for: self)
        let style = DesignSurfaceStyle.resolve(role: role, state: componentState, environment: resolvedEnvironment)
        let appearance = currentAppearance
        lastAccessibilityOptions = resolvedEnvironment.accessibility
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        apply(style, environment: resolvedEnvironment, appearance: appearance)
        CATransaction.commit()
    }

    private func apply(_ style: DesignSurfaceStyle, environment: DesignSystemEnvironment, appearance: NSAppearance) {
        effectView.isHidden = environment.accessibility.reduceTransparency || role != .window
        layer?.cornerRadius = style.cornerRadius
        layer?.backgroundColor = DesignSystemColors.cgColor(style.fillRole, environment: environment, appearance: appearance)
        layer?.shadowColor = style.shadow?.shadowColor?.cgColor
        layer?.shadowOffset = style.shadow?.shadowOffset ?? .zero
        layer?.shadowRadius = style.shadow?.shadowBlurRadius ?? 0
        layer?.shadowOpacity = style.shadow == nil ? 0 : 1
        layer?.borderWidth = style.focusRingWidth
        layer?.borderColor = style.focusRingRole.map { DesignSystemColors.cgColor($0, environment: environment, appearance: appearance) }
        tintLayer.backgroundColor = DesignSystemColors.cgColor(.windowAccentTint, environment: environment, appearance: appearance)
        gradientLayer?.isHidden = !environment.accentGradientEnabled || environment.accessibility.reduceTransparency
        gradientLayer?.colors = [
            DesignSystemColors.cgColor(.accentPrimary, environment: environment, appearance: appearance),
            DesignSystemColors.cgColor(.accentSecondary, environment: environment, appearance: appearance),
        ]
        gradientLayer?.opacity = role == .icon ? 0.28 : 0.10
        gradientLayer?.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer?.endPoint = CGPoint(x: 1, y: 1)
        borderLayer?.borderWidth = style.borderWidth
        borderLayer?.borderColor = style.borderRole.map { DesignSystemColors.cgColor($0, environment: environment, appearance: appearance) }
        updateLayerFrames()
    }

    private func updateLayerFrames() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = layer?.cornerRadius ?? DesignMetric.surfaceRadius
        tintLayer.frame = bounds
        tintLayer.cornerRadius = radius
        gradientLayer?.frame = bounds
        gradientLayer?.cornerRadius = radius
        borderLayer?.frame = bounds
        borderLayer?.cornerRadius = radius
        CATransaction.commit()
    }

    private var currentAppearance: NSAppearance {
        if #available(macOS 10.14, *) {
            return effectiveAppearance
        }
        return NSAppearance(named: .aqua)!
    }
}
