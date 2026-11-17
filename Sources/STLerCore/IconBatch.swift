import AppKit

/// Outcome of a batch run; `messages` carry problems for the caller to show.
struct BatchResult {
    var rendered = 0
    var skipped = 0
    var failed = 0
    var messages: [String] = []
}

/// Writes and removes STLer icons on files.
enum IconBatch {
    private static let iconSize = CGSize(width: 512, height: 512)

    /// Renders and stamps every file whose signature differs from the current settings (all files with `config.force`).
    /// - Parameter onProgress: Called once per file with the number of files handled so far and the total.
    static func apply(_ files: [String], config: Config, onProgress: ((_ done: Int, _ total: Int) -> Void)? = nil) -> BatchResult {
        let signature = Signature.make(for: config)
        var result = BatchResult()
        let stale = files.filter { config.force || Signature.read($0) != signature }
        let converted = convertSteps(in: stale, config: config, result: &result)

        for (index, file) in files.enumerated() {
            onProgress?(index + 1, files.count)
            if !config.force, Signature.read(file) == signature { result.skipped += 1; continue }
            let isStep = StepConverter.isStep(file)
            var options = IconRenderer.Options(config: config)
            if isStep { options.badgeText = "STEP" }
            guard let source = isStep ? converted[file] : URL(fileURLWithPath: file),
                  let image = IconRenderer.render(source, size: iconSize, options: options),
                  setIcon(image, on: file, signature: signature) else {
                result.failed += 1
                result.messages.append("failed: \(file)")
                continue
            }
            result.rendered += 1
        }
        return result
    }

    /// `apply` for one folder, down to `config.followDepth`, top level first.
    static func applyToFolder(_ folder: String, config: Config) -> BatchResult {
        apply(FileScanner.scan([folder], formats: config.formats, maxDepth: config.maxDepth), config: config)
    }

    /// Removes only icons carrying our signature, so icons set by the user stay.
    /// - Returns: How many files were reset and how many were left alone.
    static func reset(_ files: [String]) -> (reset: Int, untouched: Int) {
        var done = 0
        for file in files where Signature.read(file) != nil {
            preservingModDate(file) {
                NSWorkspace.shared.setIcon(nil, forFile: file, options: [])
                Signature.remove(file)
            }
            done += 1
        }
        resetQuickLookCache()
        return (done, files.count - done)
    }

    private static func convertSteps(in files: [String], config: Config, result: inout BatchResult) -> [String: URL] {
        let steps = files.filter(StepConverter.isStep)
        guard !steps.isEmpty else { return [:] }
        guard let freecad = StepConverter.executable(config.freecadPath) else {
            result.messages.append("STEP skipped: freecadcmd not found (install FreeCAD or set freecadPath)")
            return [:]
        }
        return StepConverter.convert(steps, freecad: freecad)
    }

    private static func setIcon(_ image: NSImage, on path: String, signature: String) -> Bool {
        preservingModDate(path) {
            guard NSWorkspace.shared.setIcon(image, forFile: path, options: []) else { return false }
            Signature.write(path, signature)
            return true
        }
    }

    /// `NSWorkspace.setIcon` bumps the modification date; restore it so Finder sorting and slicers keep seeing the real one.
    @discardableResult
    private static func preservingModDate<T>(_ path: String, _ body: () -> T) -> T {
        let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        defer { if let date { try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: path) } }
        return body()
    }

    private static func resetQuickLookCache() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-r", "cache"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
