#if DEBUG
import Cocoa

final class QAMenu: NSPanel {
    static var shared: QAMenu?
    private let stack = NSStackView()

    private static let autosaveName = "QAMenu"
    private static let openSettingsOnLaunchKey = "debug.openSettingsOnLaunch"
    private static let graphEnabledKey = "debug.graphEnabled"

    static var openSettingsOnLaunch: Bool {
        UserDefaults.standard.bool(forKey: openSettingsOnLaunchKey)
    }

    static var graphEnabled: Bool {
        UserDefaults.standard.bool(forKey: graphEnabledKey)
    }

    static func toggleVisibility() {
        guard let panel = shared else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
        }
    }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 220, height: 0),
                   styleMask: [.titled, .closable, .miniaturizable, .utilityWindow], backing: .buffered, defer: false)
        level = .floating
        title = "QA Menu"
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        addBaseButtons()
        let container = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
        sizeToFitContent()
        // setFrameAutosaveNameSafely drops a corrupt persisted frame (which would abort the app) and
        // applies a valid one; it returns whether a valid saved frame existed, so center otherwise.
        if !setFrameAutosaveNameSafely(Self.autosaveName) {
            center()
        }
    }

    private func addBaseButtons() {
        let langDropdown = NSPopUpButton()
        langDropdown.addItems(withTitles: LanguagePreference.allCases.map { $0.localizedString })
        langDropdown.selectItem(at: CachedUserDefaults.intFromMacroPref("language", LanguagePreference.allCases))
        langDropdown.onAction = { sender in
            let index = (sender as! NSPopUpButton).indexOfSelectedItem
            UserDefaults.standard.set(String(index), forKey: "language")
            CachedUserDefaults.removeFromCache("language")
            if Preferences.language == .systemDefault {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set([Preferences.language.appleLanguageCode!], forKey: "AppleLanguages")
            }
            App.restart()
        }
        let settingsButton = NSButton(title: "Settings…", target: nil, action: nil)
        settingsButton.onAction = { _ in App.showSettingsWindow() }
        let openOnLaunchCheckbox = NSButton(checkboxWithTitle: "Open on launch", target: nil, action: nil)
        openOnLaunchCheckbox.state = Self.openSettingsOnLaunch ? .on : .off
        openOnLaunchCheckbox.onAction = { sender in
            UserDefaults.standard.set((sender as! NSButton).state == .on, forKey: Self.openSettingsOnLaunchKey)
        }
        let graphCheckbox = NSButton(checkboxWithTitle: "Live queue graph", target: nil, action: nil)
        graphCheckbox.state = Self.graphEnabled ? .on : .off
        graphCheckbox.onAction = { sender in
            let on = (sender as! NSButton).state == .on
            UserDefaults.standard.set(on, forKey: Self.graphEnabledKey)
            DebugMenu.setEnabled(on)
        }
        let quitButton = NSButton(title: "Quit", target: nil, action: nil)
        quitButton.onAction = { _ in App.shared.terminate(nil) }
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.addView(settingsButton, in: .leading)
        topRow.addView(openOnLaunchCheckbox, in: .leading)
        topRow.addView(quitButton, in: .trailing)
        stack.addArrangedSubview(topRow)
        topRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -stack.edgeInsets.right).isActive = true
        stack.addArrangedSubview(graphCheckbox)
        stack.addArrangedSubview(langDropdown)
    }

    private func sizeToFitContent() {
        var size = stack.fittingSize
        size.width += stack.edgeInsets.right
        setContentSize(size)
    }

}
#endif
