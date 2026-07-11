import Cocoa

class SheetWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    class WindowContentView: NSStackView {
        var separator: NSView!

        init(_ separator: NSView) {
            super.init(frame: .zero)
            self.separator = separator
        }

        required init?(coder: NSCoder) {
            fatalError("Class only supports programmatic initialization")
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            separator.layer?.backgroundColor = DesignSystem.semanticCGColor(.borderSubtle, in: separator)
        }
    }

    static let width = CGFloat(500)
    let separator = DesignSystemDividerView()
    var doneButton: NSButton!
    private let footer = NSStackView()
    private let footerContainer = NSView()
    var contentWidth: CGFloat { SheetWindow.width }

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        makeDoneButton()
        setupView()
    }

    func setupView() {
        let contentView = makeContentView()
        let view = WindowContentView(separator)
        view.orientation = .vertical
        view.alignment = .centerX
        view.spacing = TableGroupSetView.spacing
        view.addArrangedSubview(contentView)
        contentView.topAnchor.constraint(equalTo: view.topAnchor, constant: TableGroupSetView.padding).isActive = true
        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -TableGroupSetView.padding).isActive = true
        contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: TableGroupSetView.padding).isActive = true
        view.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalToConstant: contentWidth + TableGroupSetView.leftRightPadding).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separator.topAnchor.constraint(equalTo: contentView.bottomAnchor, constant: TableGroupSetView.padding).isActive = true
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = TableGroupView.toolRowSpacing
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.addArrangedSubview(doneButton)
        footerContainer.addSubview(footer)
        footerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addArrangedSubview(footerContainer)
        NSLayoutConstraint.activate([
            footerContainer.widthAnchor.constraint(equalTo: view.widthAnchor),
            footerContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footer.topAnchor.constraint(equalTo: footerContainer.topAnchor),
            footer.leadingAnchor.constraint(greaterThanOrEqualTo: footerContainer.leadingAnchor, constant: TableGroupSetView.padding),
            footer.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -TableGroupSetView.padding),
            footer.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -TableGroupSetView.padding),
        ])
        self.contentView = DesignSystemWindowContentView(content: view)
    }

    func makeContentView() -> NSView {
        return NSView()
    }

    func addFooterButton(_ button: NSButton, beforeDoneButton: Bool = true) {
        let index = beforeDoneButton ? max(footer.arrangedSubviews.count - 1, 0) : footer.arrangedSubviews.count
        footer.insertArrangedSubview(button, at: index)
    }

    private func makeDoneButton() {
        doneButton = NSButton(title: NSLocalizedString("Done", comment: ""), target: self, action: #selector(cancel))
        doneButton.keyEquivalent = "\r"
        DesignSystemControlStyler.styleButton(doneButton)
        if #available(macOS 10.14, *) {
            doneButton.bezelColor = NSColor.controlAccentColor
        }
    }

    // allow to close with the escape key
    @objc func cancel(_ sender: Any?) {
        sheetParent!.endSheet(self)
    }
}
