import Foundation

/// Decides when `stler follow` scans the front Finder folder: when another folder comes to the front,
/// and again when the same folder changed (a file was added or removed), judged by the folder's modification date.
struct FollowState {
    private var folder: String?
    private var modified: Date?

    /// - Parameters:
    ///   - folder: The folder in front in Finder.
    ///   - modified: Its modification date now, `nil` when unknown.
    /// - Returns: True when it should be scanned; remembers the folder and date as seen.
    mutating func shouldScan(_ folder: String, modified: Date?) -> Bool {
        defer { self.folder = folder; self.modified = modified }
        return folder != self.folder || modified != self.modified
    }

    static func modificationDate(of folder: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: folder))?[.modificationDate] as? Date
    }
}
