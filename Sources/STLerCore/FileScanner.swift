import Foundation

/// Finds model files in folders.
enum FileScanner {
    /// Files with an enabled format under `paths`. Folders are walked recursively; hidden items and package contents are skipped.
    /// - Parameter maxDepth: Files directly in a folder are depth 1; `nil` means unlimited.
    static func collect(_ paths: [String], formats: [String], maxDepth: Int? = nil) -> [String] {
        var allowed = Set(formats)
        if allowed.contains("step") { allowed.insert("stp") }
        var files: [String] = []
        for raw in paths {
            let path = (raw as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }
            guard isDirectory.boolValue else {
                if allowed.contains((path as NSString).pathExtension.lowercased()) { files.append(path) }
                continue
            }
            let root = URL(fileURLWithPath: path)
            let rootDepth = maxDepth == nil ? 0 : root.standardizedFileURL.pathComponents.count
            let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            while let url = walker?.nextObject() as? URL {
                if let maxDepth, url.standardizedFileURL.pathComponents.count - rootDepth >= maxDepth,
                   (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { walker?.skipDescendants() }
                if allowed.contains(url.pathExtension.lowercased()) { files.append(url.path) }
            }
        }
        return files
    }

    /// Orders files so the top level of `folder` comes first, then deeper levels; ties keep their order.
    static func ordered(_ files: [String], under folder: String) -> [String] {
        let base = (folder as NSString).standardizingPath.count
        func depth(_ file: String) -> Int { file.dropFirst(base).split(separator: "/").count }
        return files.enumerated().sorted { (depth($0.element), $0.offset) < (depth($1.element), $1.offset) }.map(\.element)
    }

    /// `collect` per path, each ordered top level first, duplicates across paths removed.
    static func scan(_ paths: [String], formats: [String], maxDepth: Int? = nil) -> [String] {
        var seen = Set<String>()
        return paths
            .flatMap { ordered(collect([$0], formats: formats, maxDepth: maxDepth), under: $0) }
            .filter { seen.insert($0).inserted }
    }

    /// Model files of one type under `folder` from the Spotlight index: instant even on a huge folder, but files the index
    /// has not seen are missed, so treat it as an estimate. Library folders, hidden folders and app packages are left out.
    static func spotlight(_ type: FileType, in folder: String) -> [String] {
        let query = type.extensions.map { "kMDItemFSName == \"*.\($0)\"c" }.joined(separator: " || ")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", folder, query]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).filter(isUserFile)
    }

    /// Spotlight-based file counts per type under `folder`.
    static func estimate(in folder: String) -> [FileType: Int] {
        var counts = [FileType: Int]()
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: FileType.allCases.count) { index in
            let type = FileType.allCases[index]
            let count = spotlight(type, in: folder).count
            lock.lock(); counts[type] = count; lock.unlock()
        }
        return counts
    }

    /// False for files inside hidden folders, `Library` and package-like folders (apps, bundles, photo libraries).
    static func isUserFile(_ path: String) -> Bool {
        let packageSuffixes = [".app", ".bundle", ".framework", ".photoslibrary"]
        let components = path.split(separator: "/")
        return !components.contains { component in
            component.hasPrefix(".") || component == "Library" || packageSuffixes.contains { component.hasSuffix($0) }
        }
    }
}
