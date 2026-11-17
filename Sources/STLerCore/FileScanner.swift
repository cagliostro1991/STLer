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
            let rootDepth = root.standardizedFileURL.pathComponents.count
            let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            while let url = walker?.nextObject() as? URL {
                let depth = url.standardizedFileURL.pathComponents.count - rootDepth
                if let maxDepth, depth >= maxDepth, (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true { walker?.skipDescendants() }
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
}
