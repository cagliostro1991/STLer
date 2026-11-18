import Foundation

/// Runs commands in a visible Terminal window, so the user watches and can stop them.
/// Goes through a `.command` file and `open -a Terminal`, which needs no Automation permission.
enum TerminalScript {
    /// - Parameters:
    ///   - commands: Shell lines to run.
    ///   - name: File name stem for the temporary script.
    /// - Returns: False when the script could not be written.
    @discardableResult
    static func run(_ commands: String, name: String) -> Bool {
        let script = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(name).command")
        let body = "#!/bin/zsh\n\(commands)\n"
        guard (try? body.write(to: script, atomically: true, encoding: .utf8)) != nil,
            (try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: script.path)) != nil
        else { return false }
        Process.launchedProcess(
            launchPath: "/usr/bin/open", arguments: ["-a", "Terminal", script.path])
        return true
    }
}
