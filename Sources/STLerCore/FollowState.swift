import Foundation

/// Decides when `stler follow` scans the front Finder folder: the first time a folder is seen, and again when it changed
/// (a file was added or removed), judged by the folder's modification date. Each folder is remembered on its own, so
/// switching between two open windows does not rescan them over and over.
struct FollowState {
    private var seen: [String: Date] = [:]

    /// - Parameters:
    ///   - folder: The folder in front in Finder.
    ///   - modified: Its modification date now, `nil` when unknown (then it is always scanned).
    /// - Returns: True when it should be scanned; remembers the folder and date as seen.
    mutating func shouldScan(_ folder: String, modified: Date?) -> Bool {
        if seen.count > 200 { seen.removeAll() }
        guard let modified else { seen[folder] = nil; return true }
        defer { seen[folder] = modified }
        return seen[folder] != modified
    }

    /// Makes the next visit scan the folder again, for a scan that was cut short.
    mutating func forget(_ folder: String) { seen[folder] = nil }

    static func modificationDate(of folder: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: folder))?[.modificationDate] as? Date
    }
}
