import Foundation

/// Reports model files as they are opened anywhere on this Mac, including indexed external drives.
/// macOS has no "file opened" hook, but Spotlight updates `kMDItemLastUsedDate` when a file is opened, and a live query sees that within seconds.
/// Needs a running main run loop. Files on volumes that Spotlight does not index are not seen.
final class OpenedFileWatcher {
    private let query = NSMetadataQuery()
    private var observer: NSObjectProtocol?

    var isRunning: Bool { query.isStarted }

    /// - Parameters:
    ///   - extensions: File extensions to watch, without the dot.
    ///   - onOpened: Called on the main thread with the paths that were opened since `start`.
    func start(extensions: [String], onOpened: @escaping ([String]) -> Void) {
        guard !query.isStarted else { return }
        let names = extensions.map { "kMDItemFSName LIKE[c] '*.\($0)'" }.joined(separator: " OR ")
        query.predicate = NSPredicate(
            format: "kMDItemLastUsedDate > %@ AND (\(names))", Date() as NSDate)
        query.searchScopes = [NSMetadataQueryIndexedLocalComputerScope]
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: query, queue: .main
        ) { note in
            let keys = [NSMetadataQueryUpdateAddedItemsKey, NSMetadataQueryUpdateChangedItemsKey]
            let items = keys.flatMap { note.userInfo?[$0] as? [NSMetadataItem] ?? [] }
            let paths = items.compactMap {
                $0.value(forAttribute: NSMetadataItemPathKey) as? String
            }
            if !paths.isEmpty { onOpened(Array(Set(paths))) }
        }
        query.start()
    }

    func stop() {
        query.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// Keeps the opened files worth an icon: ordinary user files of an enabled type that still exist.
    static func relevant(_ paths: [String], config: Config) -> [String] {
        paths.filter { path in
            guard let type = FileType(path: path), config[type].enabled,
                FileScanner.isUserFile(path)
            else { return false }
            return FileManager.default.fileExists(atPath: path)
        }
    }
}
