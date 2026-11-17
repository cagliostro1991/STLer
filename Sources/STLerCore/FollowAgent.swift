import Foundation

/// The LaunchAgent that keeps `stler follow` running, as the CLI installs it and the window reports on it.
enum FollowAgent {
    static let label = "dev.stler.follow"
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    static let plistURL = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    static let binaryURL = home.appendingPathComponent(".local/bin/stler")
    static let logURL = home.appendingPathComponent("Library/Logs/stler.log")
    static var domain: String { "gui/\(getuid())" }

    enum State: Equatable {
        case notInstalled
        /// The plist is there but launchd does not run the agent (not loaded, or crashed).
        case stopped
        case running
    }

    /// The CLI to install from: the `stler` built next to the app, otherwise the copy already in `~/.local/bin`.
    static func cliURL(appBundle: URL) -> URL? {
        [appBundle.deletingLastPathComponent().appendingPathComponent("stler"), binaryURL].first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Opens Terminal and runs `stler install` (which copies the CLI to `~/.local/bin` and loads the agent).
    /// - Returns: What the user should do next.
    static func installInTerminal(appBundle: URL) -> String {
        guard let cli = cliURL(appBundle: appBundle) else { return "The stler command line tool was not found next to the app. Run `make build` first." }
        let quoted = "'" + cli.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        guard TerminalScript.run("\(quoted) install\necho\necho 'Finished. Go back to STLer and press Check again.'", name: "stler-install-follow")
        else { return "Could not prepare the install script. Run: stler install" }
        return "Installing in Terminal. The first run asks for permission to control Finder."
    }

    /// Pure part of `state()`, kept apart so it can be tested.
    /// - Parameter launchctlOutput: Output of `launchctl print gui/<uid>/dev.stler.follow`, empty when the agent is not loaded.
    static func state(plistExists: Bool, binaryExists: Bool, launchctlOutput: String) -> State {
        guard plistExists, binaryExists else { return .notInstalled }
        return launchctlOutput.contains("state = running") ? .running : .stopped
    }

    /// Stops the agent without removing it: it starts again at the next login, or with `start()`.
    /// - Returns: True when launchd accepted the command.
    @discardableResult
    static func stop() -> Bool { launchctl(["bootout", "\(domain)/\(label)"]) == 0 }

    /// Loads an installed agent again.
    @discardableResult
    static func start() -> Bool { launchctl(["bootstrap", domain, plistURL.path]) == 0 }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Looks at the plist, the installed binary and launchd. Spawns `launchctl`, so call it off the main thread.
    static func state() -> State {
        let fileManager = FileManager.default
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "\(domain)/\(label)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        var output = ""
        if (try? process.run()) != nil {
            output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            process.waitUntilExit()
        }
        return state(plistExists: fileManager.fileExists(atPath: plistURL.path), binaryExists: fileManager.isExecutableFile(atPath: binaryURL.path), launchctlOutput: output)
    }
}
