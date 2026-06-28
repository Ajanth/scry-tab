#if DEBUG
import Cocoa

final class ComponentGalleryWindow: NSPanel {
    static var shared: ComponentGalleryWindow?
    private let scrollView = NSScrollView()
    private let stack = NSStackView()
    private let popoverPresenter = MaterialPopoverPresenter()
    private var retainedModalPanel: MaterialModalPanel?

    static func showGallery() {
        if shared == nil { shared = ComponentGalleryWindow() }
        shared?.makeKeyAndOrderFront(nil)
    }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                   backing: .buffered,
                   defer: false)
        title = "Design System Gallery"
        isReleasedWhenClosed = false
        setupView()
        center()
    }

    private func setupView() {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = DesignMetric.gallerySectionGap
        stack.edgeInsets = NSEdgeInsets(top: DesignMetric.galleryOuterPadding, left: DesignMetric.galleryOuterPadding, bottom: DesignMetric.galleryOuterPadding, right: DesignMetric.galleryOuterPadding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = stack
        contentView = scrollView
        addSurfaceSection()
        addAppearanceSection()
        addControlSection()
        addFormSection()
        addListSection()
        addTextSection()
        addPresentationSection()
        addPermissionSection()
        addAccessibilitySection()
        stack.widthAnchor.constraint(equalToConstant: DesignMetric.galleryContentWidth).isActive = true
    }

    private func addSurfaceSection() {
        addSection("Surfaces", views: [
            surfaceSample("Normal", state: DesignComponentState()),
            surfaceSample("Hovered", state: DesignComponentState(isHovered: true)),
            surfaceSample("Pressed", state: DesignComponentState(isPressed: true)),
            surfaceSample("Selected", state: DesignComponentState(isSelected: true)),
            surfaceSample("Disabled", state: DesignComponentState(isEnabled: false)),
            surfaceSample("Focused", state: DesignComponentState(isFocused: true)),
        ])
    }

    private func addControlSection() {
        let normal = SurfaceButton(title: "Normal")
        let selected = SurfaceButton(title: "Selected")
        let disabled = SurfaceButton(title: "Disabled")
        selected.state = .on
        disabled.isEnabled = false
        let choices = ChoicePickerView(cards: [
            ChoiceCardView(title: "App Icons", subtitle: "Illustrated switcher", image: NSImage.fromSymbol(.paintpalette, pointSize: 18)),
            ChoiceCardView(title: "Titles", subtitle: "Compact text list", image: NSImage.fromSymbol(.command, pointSize: 18)),
        ])
        choices.widthAnchor.constraint(equalToConstant: DesignMetric.galleryChoicePickerWidth).isActive = true
        addSection("Controls", views: [normal, selected, disabled, CompactPicker(items: ["System", "Light", "Dark"]), SegmentedPicker(items: ["Small", "Medium", "Large"]), choices])
    }

    private func addAppearanceSection() {
        let activeLight = surfaceSample("Light Active", state: DesignComponentState(isSelected: true), environment: DesignSystemEnvironment(colorScheme: .light, isActive: true))
        let inactiveLight = surfaceSample("Light Inactive", state: DesignComponentState(isSelected: true), environment: DesignSystemEnvironment(colorScheme: .light, isActive: false))
        let activeDark = surfaceSample("Dark Active", state: DesignComponentState(isSelected: true), environment: DesignSystemEnvironment(colorScheme: .dark, isActive: true))
        let inactiveDark = surfaceSample("Dark Inactive", state: DesignComponentState(isSelected: true), environment: DesignSystemEnvironment(colorScheme: .dark, isActive: false))
        addSection("Appearance", views: [activeLight, inactiveLight, activeDark, inactiveDark])
    }

    private func addFormSection() {
        let form = SettingsFormView()
        let section = SettingsSectionView(title: "Section", footer: "Footer text")
        section.addRow(SettingsRowView(title: "Row title", subtitle: "Supporting text", content: [SurfaceButton(title: "Action")]))
        section.addRow(SettingsToggleRow(title: "Toggle row", subtitle: "Uses NSSwitch on macOS 10.15+", isOn: true))
        section.addRow(ShortcutRecorderRow(title: "Shortcut recorder", recorder: SurfaceButton(title: "⌘⇥"), subtitle: "Recorder container"))
        form.addSection(section)
        form.widthAnchor.constraint(equalToConstant: DesignMetric.galleryFormWidth).isActive = true
        addSection("Forms", views: [form])
    }

    private func addListSection() {
        let list = SelectionListView()
        list.setRows([
            SelectionListItemView(identifier: "one", title: "Standard row", subtitle: "Summary"),
            SelectionListItemView(identifier: "two", title: "Rich row", subtitle: "Larger row", rich: true),
        ])
        list.selectedIdentifier = "one"
        list.widthAnchor.constraint(equalToConstant: DesignMetric.galleryListWidth).isActive = true
        addSection("Lists", views: [list])
    }

    private func addTextSection() {
        let field = SurfaceTextField(placeholder: "Placeholder")
        let editor = SurfaceTextEditor()
        editor.textView.string = "Text editor surface"
        field.widthAnchor.constraint(equalToConstant: DesignMetric.galleryTextFieldWidth).isActive = true
        editor.widthAnchor.constraint(equalToConstant: DesignMetric.galleryTextEditorWidth).isActive = true
        addSection("Text", views: [field, editor])
    }

    private func addPresentationSection() {
        let modal = SurfaceButton(title: "Modal")
        let popover = SurfaceButton(title: "Popover")
        modal.onAction = { [weak self] _ in self?.showModalSample() }
        popover.onAction = { [weak self, weak popover] _ in
            guard let popover else { return }
            self?.popoverPresenter.show(content: self?.presentationSampleContent() ?? NSView(), relativeTo: popover.bounds, of: popover)
        }
        addSection("Presentation", views: [modal, popover])
    }

    private func addPermissionSection() {
        let granted = PermissionStatusRow(title: "Accessibility", text: "Required to focus windows.", image: NSImage.fromSymbol(.handRaised, pointSize: 18), statusText: "Granted", status: .granted)
        let missing = PermissionStatusRow(title: "Accessibility", text: "Required to focus windows.", image: NSImage.fromSymbol(.handRaised, pointSize: 18), statusText: "Not granted", status: .missing)
        let unknown = PermissionStatusRow(title: "Accessibility", text: "Required to focus windows.", image: NSImage.fromSymbol(.handRaised, pointSize: 18), statusText: "Unknown", status: .unknown)
        for row in [granted, missing, unknown] {
            row.widthAnchor.constraint(equalToConstant: DesignMetric.galleryFormWidth).isActive = true
        }
        addSection("Permissions", views: [granted, missing, unknown])
    }

    private func addAccessibilitySection() {
        let reduceTransparency = surfaceSample("Reduce Transparency", state: DesignComponentState(isSelected: true), environment: DesignSystemEnvironment(colorScheme: .light, accessibility: DesignAccessibilityOptions(increaseContrast: false, reduceTransparency: true, reduceMotion: false)))
        let increaseContrast = surfaceSample("Increase Contrast", state: DesignComponentState(isSelected: true), environment: DesignSystemEnvironment(colorScheme: .light, accessibility: DesignAccessibilityOptions(increaseContrast: true, reduceTransparency: false, reduceMotion: false)))
        let reduceMotion = NSTextField(labelWithString: "Reduce Motion duration: \(DesignMotion.duration(.normal, reduceMotion: true))s, offset: \(DesignMotion.distance(.overlayOffset, reduceMotion: true))pt")
        addSection("Accessibility", views: [reduceTransparency, increaseContrast, reduceMotion])
    }

    private func addSection(_ title: String, views: [NSView]) {
        let label = NSTextField(labelWithString: title)
        label.font = DesignTypography.sectionHeader
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = DesignMetric.galleryRowGap
        row.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(row)
    }

    private func surfaceSample(_ title: String, state: DesignComponentState, environment: DesignSystemEnvironment? = nil) -> NSView {
        let surface = MaterialSurfaceView(role: .plateau, state: state)
        let label = NSTextField(labelWithString: title)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(label)
        surface.widthAnchor.constraint(equalToConstant: DesignMetric.gallerySampleWidth).isActive = true
        surface.heightAnchor.constraint(equalToConstant: DesignMetric.gallerySampleHeight).isActive = true
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
        ])
        if let environment { surface.applyPreviewEnvironment(environment) }
        return surface
    }

    private func showModalSample() {
        let panel = MaterialModalPanel(contentSize: NSSize(width: 360, height: 180), title: "Modal")
        panel.setModalContent(presentationSampleContent())
        retainedModalPanel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func presentationSampleContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = DesignMetric.sectionHeaderFooterGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(NSTextField(labelWithString: "Presentation surface"))
        stack.addArrangedSubview(SurfaceButton(title: "Action"))
        return stack
    }
}
#endif
