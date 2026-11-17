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

    /// Orders files so the top level of `folder` comes first, then deeper levels; within a level the smaller files come first,
    /// so one huge model does not keep the quick ones waiting. Ties keep their order.
    static func ordered(_ files: [String], under folder: String) -> [String] {
        let base = (folder as NSString).standardizingPath.count
        func depth(_ file: String) -> Int { file.dropFirst(base).split(separator: "/").count }
        func size(_ file: String) -> Int { (try? FileManager.default.attributesOfItem(atPath: file)[.size] as? Int) ?? 0 }
        let keys = files.map { (depth: depth($0), size: size($0)) }
        return files.indices.sorted { (keys[$0].depth, keys[$0].size, $0) < (keys[$1].depth, keys[$1].size, $1) }.map { files[$0] }
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

    /// Most files taken from the folder of an opened file, so one open never starts a long job.
    static let siblingLimit = 50

    /// The other models that lie directly in the folder of `file` (no subfolders), small ones first, at most `siblingLimit`.
    static func siblings(of file: String, formats: [String]) -> [String] {
        let folder = (file as NSString).deletingLastPathComponent
        guard isUserFile(folder + "/x") else { return [] }
        var allowed = Set(formats)
        if allowed.contains("step") { allowed.insert("stp") }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        let models = names.filter { !$0.hasPrefix(".") && allowed.contains(($0 as NSString).pathExtension.lowercased()) }.map { folder + "/" + $0 }
        return Array(ordered(models, under: folder).prefix(siblingLimit))
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
