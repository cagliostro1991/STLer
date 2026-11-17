import AppKit

/// Expands folders recursively (files directly in a folder are depth 1) and keeps only files with an enabled extension.
func collectFiles(_ paths: [String], formats: [String], maxDepth: Int? = nil) -> [String] {
    let fm = FileManager.default
    var allowed = Set(formats)
    if allowed.contains("step") { allowed.insert("stp") }
    var files: [String] = []
    for p in paths {
        let path = (p as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
        if isDir.boolValue {
            let e = fm.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            let base = URL(fileURLWithPath: path).standardizedFileURL.pathComponents.count
            while let u = e?.nextObject() as? URL {
                let depth = u.standardizedFileURL.pathComponents.count - base
                if let maxDepth, (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true, depth >= maxDepth { e?.skipDescendants() }
                if allowed.contains(u.pathExtension.lowercased()) { files.append(u.path) }
            }
        } else if allowed.contains((path as NSString).pathExtension.lowercased()) {
            files.append(path)
        }
    }
    return files
}

/// Folder shown in the frontmost Finder window; needs a one-time Automation permission. Call on the main thread.
func activeFinderFolder() -> String? {
    let src = "tell application \"Finder\" to if (count of windows) > 0 then POSIX path of (target of front window as alias)"
    var err: NSDictionary?
    guard let out = NSAppleScript(source: src)?.executeAndReturnError(&err).stringValue, !out.isEmpty else { return nil }
    return out
}

/// Orders files so the top level of `folder` comes first, then deeper levels.
func byDepth(_ files: [String], under folder: String) -> [String] {
    let base = (folder as NSString).standardizingPath.count
    func depth(_ f: String) -> Int { f.dropFirst(base).split(separator: "/").count }
    return files.enumerated().sorted { (depth($0.element), $0.offset) < (depth($1.element), $1.offset) }.map(\.element)
}

/// Runs `body` and restores the file's modification date, which `NSWorkspace.setIcon` otherwise bumps.
@discardableResult
func preservingModDate<T>(_ path: String, _ body: () -> T) -> T {
    let fm = FileManager.default
    let date = (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    defer { if let date { try? fm.setAttributes([.modificationDate: date], ofItemAtPath: path) } }
    return body()
}

/// Renders and stamps every file whose signature differs from the current settings.
func renderBatch(_ files: [String], config c: Config, view: String? = nil, colorSpec: String? = nil, badge: String? = nil, force: Bool? = nil, progress: Bool = false) -> (rendered: Int, skipped: Int, failed: Int) {
    let view = view ?? c.view, colorSpec = colorSpec ?? c.color, badge = badge ?? c.badge, force = force ?? c.force
    guard let color = parseColor(colorSpec) else { return (0, 0, files.count) }
    let sig = Signature.make(view: view, color: colorSpec, firstPlateOnly: c.firstPlateOnly, badge: badge)
    var rendered = 0, skipped = 0, failed = 0
    let stale = files.filter { force || Signature.read($0) != sig }
    var converted: [String: URL] = [:]
    let stepFiles = stale.filter(StepConverter.isStep)
    if !stepFiles.isEmpty {
        if let freecad = StepConverter.executable(c.freecadPath) { converted = StepConverter.convert(stepFiles, freecad: freecad) }
        else { print("STEP skipped: freecadcmd not found (install FreeCAD or set freecadPath)") }
    }
    for (i, f) in files.enumerated() {
        if !force, Signature.read(f) == sig { skipped += 1; continue }
        let isStep = StepConverter.isStep(f)
        guard let source = isStep ? converted[f] : URL(fileURLWithPath: f),
              let img = render(stl: source, size: CGSize(width: 512, height: 512), view: view, color: color, firstPlateOnly: c.firstPlateOnly, badge: badge, badgeText: isStep ? "STEP" : nil),
              preservingModDate(f, { NSWorkspace.shared.setIcon(img, forFile: f, options: []) && { Signature.write(f, sig); return true }() }) else { print("fail \(f)"); failed += 1; continue }
        rendered += 1
        if progress, rendered % 25 == 0 { print("[\(i + 1)/\(files.count)]") }
    }
    return (rendered, skipped, failed)
}

/// Renders one opened folder down to `followDepth`, top level first.
func processFolder(_ folder: String, config c: Config) -> (rendered: Int, skipped: Int, failed: Int) {
    let files = byDepth(collectFiles([folder], formats: c.formats, maxDepth: c.followDepth == 0 ? nil : c.followDepth), under: folder)
    return renderBatch(files, config: c)
}

/// Removes only icons set by STyLer (files carrying our signature); returns how many were reset and how many were left alone.
func resetIcons(_ files: [String]) -> (reset: Int, untouched: Int) {
    var done = 0
    for f in files where Signature.read(f) != nil {
        preservingModDate(f) {
            NSWorkspace.shared.setIcon(nil, forFile: f, options: [])
            Signature.remove(f)
        }
        done += 1
    }
    resetQuickLookCache()
    return (done, files.count - done)
}

func resetQuickLookCache() {
    let q = Process()
    q.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
    q.arguments = ["-r", "cache"]
    q.standardOutput = FileHandle.nullDevice
    q.standardError = FileHandle.nullDevice
    try? q.run()
    q.waitUntilExit()
}
