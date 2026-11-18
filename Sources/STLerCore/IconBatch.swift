import AppKit

/// Outcome of a batch run; `messages` carry problems for the caller to show.
struct BatchResult {
    var rendered = 0
    var skipped = 0
    var failed = 0
    /// The run stopped early because `shouldContinue` returned false.
    var interrupted = false
    var messages: [String] = []
}

/// Writes and removes STLer icons on files.
enum IconBatch {
    private static let iconSize = CGSize(width: 512, height: 512)

    /// Renders and stamps every file of an enabled type whose signature differs from the current settings of its type
    /// (all of them with `force`).
    /// - Parameters:
    ///   - onProgress: Called once per file with the number of files handled so far, the total and the file being handled.
    ///   - shouldContinue: Asked before each file; returning false stops the run (`interrupted` is set).
    static func apply(
        _ files: [String], config: Config, force: Bool = false,
        onProgress: ((_ done: Int, _ total: Int, _ file: String) -> Void)? = nil,
        shouldContinue: (() -> Bool)? = nil
    ) -> BatchResult {
        var result = BatchResult()
        let stale = files.filter { staleType(of: $0, config: config, force: force) != nil }
        let converted = convertSteps(in: stale, config: config, result: &result)

        for (index, file) in files.enumerated() {
            if let shouldContinue, !shouldContinue() {
                result.interrupted = true
                break
            }
            onProgress?(index + 1, files.count, file)
            guard let type = staleType(of: file, config: config, force: force) else {
                result.skipped += 1; continue
            }
            let options = IconRenderer.Options(style: config[type], labelText: type.title)
            guard let source = type == .step ? converted[file] : URL(fileURLWithPath: file),
                let image = IconRenderer.render(source, size: iconSize, options: options),
                setIcon(image, on: file, signature: Signature.make(for: config, type: type))
            else {
                result.failed += 1
                result.messages.append("failed: \(file)")
                continue
            }
            result.rendered += 1
        }
        return result
    }

    /// The files that `apply` would render: their icon is missing or out of date.
    static func pending(_ files: [String], config: Config) -> [String] {
        files.filter { staleType(of: $0, config: config, force: false) != nil }
    }

    /// `apply` for one folder, down to `config.followDepth`, top level first.
    static func applyToFolder(
        _ folder: String, config: Config,
        onProgress: ((_ done: Int, _ total: Int, _ file: String) -> Void)? = nil,
        shouldContinue: (() -> Bool)? = nil
    ) -> BatchResult {
        apply(
            FileScanner.scan([folder], formats: config.enabledFormats, maxDepth: config.maxDepth),
            config: config, onProgress: onProgress, shouldContinue: shouldContinue)
    }

    /// Removes only icons carrying our signature, so icons set by the user stay.
    /// - Returns: How many files were reset and how many were left alone.
    static func reset(
        _ files: [String], onProgress: ((_ done: Int, _ total: Int, _ file: String) -> Void)? = nil,
        shouldContinue: (() -> Bool)? = nil
    ) -> (reset: Int, untouched: Int, interrupted: Bool) {
        var done = 0
        var interrupted = false
        for (index, file) in files.enumerated() {
            if let shouldContinue, !shouldContinue() { interrupted = true; break }
            onProgress?(index + 1, files.count, file)
            guard Signature.read(file) != nil else { continue }
            preservingModDate(file) {
                NSWorkspace.shared.setIcon(nil, forFile: file, options: [])
                Signature.remove(file)
            }
            done += 1
        }
        resetQuickLookCache()
        return (done, files.count - done, interrupted)
    }

    /// The file's type when it is enabled and its icon is missing or out of date.
    private static func staleType(of file: String, config: Config, force: Bool) -> FileType? {
        guard let type = FileType(path: file), config[type].enabled else { return nil }
        return force || Signature.read(file) != Signature.make(for: config, type: type)
            || !Signature.hasIcon(file) ? type : nil
    }

    private static func convertSteps(in files: [String], config: Config, result: inout BatchResult)
        -> [String: URL]
    {
        let steps = files.filter(StepConverter.isStep)
        guard !steps.isEmpty else { return [:] }
        let converted = StepConverter.convert(steps, config: config)
        if let error = converted.error { result.messages.append("STEP skipped: \(error)") }
        return converted.urls
    }

    private static func setIcon(_ image: NSImage, on path: String, signature: String) -> Bool {
        preservingModDate(path) {
            guard NSWorkspace.shared.setIcon(image, forFile: path, options: []) else {
                return false
            }
            Signature.write(path, signature)
            return true
        }
    }

    /// `NSWorkspace.setIcon` bumps the modification date; restore it so Finder sorting and slicers keep seeing the real one.
    @discardableResult
    private static func preservingModDate<T>(_ path: String, _ body: () -> T) -> T {
        let date =
            (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        defer {
            if let date {
                try? FileManager.default.setAttributes(
                    [.modificationDate: date], ofItemAtPath: path)
            }
        }
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
