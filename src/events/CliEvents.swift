class CliEvents {
    static let portName = "\(App.bundleIdentifier).cli"
    private static var messagePort: CFMessagePort?
    private static var runLoopSource: CFRunLoopSource?
    static var ownsAdmission: Bool { messagePort != nil }

    @discardableResult
    static func claimAdmission() -> Bool {
        if messagePort != nil { return true }
        var context = CFMessagePortContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        guard let messagePort = CFMessagePortCreateLocal(nil, portName as CFString, handleEvent, &context, nil) else {
            Logger.error { "Can't claim the local message port. Is another ScryTab already running?" }
            return false
        }
        self.messagePort = messagePort
        return true
    }

    @discardableResult
    static func attachRunLoopSource() -> Bool {
        if runLoopSource != nil { return true }
        guard let messagePort else {
            Logger.error { "Can't attach CLI events without owning admission" }
            return false
        }
        guard let source = CFMessagePortCreateRunLoopSource(nil, messagePort, 0) else {
            Logger.error { "Can't create the CLI message-port run-loop source" }
            return false
        }
        guard let runLoop = BackgroundWork.cliEventsThread.runLoop else {
            CFRunLoopSourceInvalidate(source)
            Logger.error { "The CLI message-port run loop is unavailable" }
            return false
        }
        runLoopSource = source
        CFRunLoopAddSource(runLoop, source, .commonModes)
        return true
    }

    static func stopObserving() {
        if let runLoopSource {
            if let runLoop = BackgroundWork.cliEventsThread?.runLoop {
                CFRunLoopRemoveSource(runLoop, runLoopSource, .commonModes)
            }
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let messagePort { CFMessagePortInvalidate(messagePort) }
        runLoopSource = nil
        messagePort = nil
    }

    private static let handleEvent: CFMessagePortCallBack = { (_: CFMessagePort?, _: Int32, _ data: CFData?, _: UnsafeMutableRawPointer?) in
        Logger.debug { "" }
        if let data,
           let message = String(data: data as Data, encoding: .utf8) {
            Logger.info { message }
            let output = CliServer.executeCommandAndSendReponse(message)
            if let responseData = try? CliServer.jsonEncoder.encode(output) as CFData {
                return Unmanaged.passRetained(responseData)
            }
        }
        Logger.error { "Failed to decode message" }
        return nil
    }
}

class CliServer {
    static let jsonEncoder = JSONEncoder()
    static let error = "error"
    static let noOutput = "noOutput"

    // main.sync is safe here: the main thread never synchronously waits on the CLI thread
    static func executeCommandAndSendReponse(_ rawValue: String) -> Codable {
        var output: Codable = ""
        DispatchQueue.main.sync {
            output = executeCommandAndSendReponse_(rawValue)
        }
        return output
    }

    private static func executeCommandAndSendReponse_(_ rawValue: String) -> Codable {
        if rawValue == "--list" {
            return JsonWindowList(windows: Windows.list
                .filter { !$0.isWindowlessApp }
                .map { JsonWindow(id: $0.cgWindowId, title: $0.title) }
            )
        }
        if rawValue == "--detailed-list" {
            return JsonWindowFullList(windows: Windows.list
                .filter { !$0.isWindowlessApp }
                .map {
                    JsonWindowFull(
                        id: $0.cgWindowId,
                        title: $0.title,
                        appName: $0.application.localizedName,
                        appBundleId: $0.application.bundleIdentifier,
                        spaceIndexes: $0.spaceIndexes,
                        lastFocusOrder: $0.lastFocusOrder,
                        creationOrder: $0.creationOrder,
                        isTabbed: $0.isTabbed,
                        isHidden: $0.isHidden,
                        isFullscreen: $0.isFullscreen,
                        isMinimized: $0.isMinimized,
                        isOnAllSpaces: $0.isOnAllSpaces,
                        position: $0.position,
                        size: $0.size
                    )
                }
            )
        }
        if rawValue.hasPrefix("--focus="),
           let id = CGWindowID(rawValue.dropFirst("--focus=".count)), let window = (Windows.list.first { $0.cgWindowId == id }) {
            window.focus()
            return noOutput
        }
        if rawValue.hasPrefix("--focusUsingLastFocusOrder="),
           let lastFocusOrder = Int(rawValue.dropFirst("--focusUsingLastFocusOrder=".count)), let window = (Windows.list.first { $0.lastFocusOrder == lastFocusOrder }) {
            window.focus()
            return noOutput
        }
        if rawValue.hasPrefix("--show="),
           let shortcutIndex = Int(rawValue.dropFirst("--show=".count)), (0..<Preferences.shortcutCount).contains(shortcutIndex) {
            App.showUi(shortcutIndex)
            return noOutput
        }
        return error
    }

    private struct JsonWindowList: Codable {
        var windows: [JsonWindow]
    }

    private struct JsonWindow: Codable {
        var id: CGWindowID?
        var title: String
    }

    private struct JsonWindowFullList: Codable {
        var windows: [JsonWindowFull]
    }

    private struct JsonWindowFull: Codable {
        var id: CGWindowID?
        var title: String
        // -- additional properties
        var appName: String?
        var appBundleId: String?
        var spaceIndexes: [SpaceIndex]
        var lastFocusOrder: Int
        var creationOrder: Int
        var isTabbed: Bool
        var isHidden: Bool
        var isFullscreen: Bool
        var isMinimized: Bool
        var isOnAllSpaces: Bool
        var position: CGPoint?
        var size: CGSize?
    }
}

class CliClient {
    static func detectCommand() -> String? {
        let args = CommandLine.arguments
        if args.count == 2 && !args[1].starts(with: "--logs=") {
            if args[1] == "--list" || args[1] == "--detailed-list" || args[1].hasPrefix("--focus=") || args[1].hasPrefix("--focusUsingLastFocusOrder=") || args[1].hasPrefix("--show=") {
                return args[1]
            }
        }
        return nil
    }

    static func sendCommandAndProcessResponse(_ command: String) {
        do {
            let serverPortClient = try CFMessagePortCreateRemote(nil, CliEvents.portName as CFString).unwrapOrThrow()
            let data = try command.data(using: .utf8).unwrapOrThrow()
            var returnData: Unmanaged<CFData>?
            let _ = CFMessagePortSendRequest(serverPortClient, 0, data as CFData, 2, 2, CFRunLoopMode.defaultMode.rawValue, &returnData)
            let responseData = try returnData.unwrapOrThrow().takeRetainedValue()
            if let response = String(data: responseData as Data, encoding: .utf8) {
                if response != "\"\(CliServer.error)\"" {
                    if response != "\"\(CliServer.noOutput)\"" {
                        print(response)
                    }
                    exit(0)
                }
            }
            print("Couldn't execute command. Is it correct?")
            exit(1)
        } catch {
            print("ScryTab.app needs to be running for CLI commands to work")
            exit(1)
        }
    }
}
