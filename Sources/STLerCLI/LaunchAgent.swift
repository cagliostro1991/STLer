import Foundation

/// Keeps `stler follow` running from the user's login session.
enum LaunchAgent {
    private static let label = FollowAgent.label
    private static let plistURL = FollowAgent.plistURL
    private static let binaryURL = FollowAgent.binaryURL
    private static let logURL = FollowAgent.logURL
    private static var domain: String { FollowAgent.domain }

    /// Copies the running binary to `~/.local/bin/stler`, writes the agent plist and loads it.
    static func install() throws {
        let fileManager = FileManager.default
        guard let current = Bundle.main.executableURL else { throw CLIError("cannot locate own executable") }
        try fileManager.createDirectory(at: binaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if current.resolvingSymlinksInPath().path != binaryURL.path {
            try? fileManager.removeItem(at: binaryURL)
            try fileManager.copyItem(at: current, to: binaryURL)
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [binaryURL.path, "follow"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
            "LimitLoadToSessionType": "Aqua",
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
        ]
        try fileManager.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: plistURL)
        launchctl(["bootout", "\(domain)/\(label)"])
        guard launchctl(["bootstrap", domain, plistURL.path]) == 0 else { throw CLIError("launchctl bootstrap failed") }
        print("installed: \(binaryURL.path), log: \(logURL.path)")
    }

    /// Unloads the agent and removes its plist; the copied binary and the config stay.
    static func uninstall() {
        launchctl(["bootout", "\(domain)/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
        print("uninstalled (binary in ~/.local/bin/stler and config left in place)")
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
