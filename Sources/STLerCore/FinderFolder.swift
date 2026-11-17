import AppKit

/// Reads Finder state through AppleScript; macOS asks once for Automation access to Finder.
enum FinderFolder {
    /// Folder of the frontmost Finder window, or `nil` when there is none or access was denied. Call on the main thread.
    static func front() -> String? {
        let source = #"tell application "Finder" to if (count of windows) > 0 then POSIX path of (target of front window as alias)"#
        var error: NSDictionary?
        guard let path = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue, !path.isEmpty else { return nil }
        return path
    }
}
