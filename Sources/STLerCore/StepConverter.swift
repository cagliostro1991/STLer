import Foundation

/// Optional STEP support: converts STEP/STP files to cached STL through FreeCAD's headless `freecadcmd`.
enum StepConverter {
    private static let knownLocations = [
        "/Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd",
        "~/Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd",
        "/opt/homebrew/bin/freecadcmd",
        "/usr/local/bin/freecadcmd",
    ]
    private static let cacheDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/stler")

    private static let script = """
    import json, os, Part, MeshPart
    for job in json.load(open(os.environ["STLER_JOBS"])):
        try:
            shape = Part.read(job["in"])
            deflection = max(shape.BoundBox.DiagonalLength * 0.001, 0.001)
            MeshPart.meshFromShape(Shape=shape, LinearDeflection=deflection, AngularDeflection=0.5, Relative=False).write(job["out"])
        except Exception as e:
            print("stler-fail", job["in"], e)
    """

    /// - Parameter custom: `freecadPath` from the config; empty means the usual install locations.
    /// - Returns: Path of an executable `freecadcmd`, or `nil` when it cannot be found there. Cheap: only file checks.
    static func executable(_ custom: String) -> String? {
        if !custom.isEmpty {
            let path = (custom as NSString).expandingTildeInPath
            return FileManager.default.isExecutableFile(atPath: path) ? path : nil
        }
        return knownLocations.map { ($0 as NSString).expandingTildeInPath }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// `executable("")` plus a Spotlight search for any `FreeCAD*.app` (weekly builds, other folders). Slower, call off the main thread.
    static func search() -> String? {
        if let known = executable("") { return known }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [#"kMDItemFSName == "FreeCAD*.app"c"#]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n")
            .map { "\($0)/Contents/Resources/bin/freecadcmd" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func isStep(_ path: String) -> Bool {
        ["step", "stp"].contains((path as NSString).pathExtension.lowercased())
    }

    /// Converts files in one FreeCAD run, because its start-up dominates the cost. Results are cached by path, mtime and size.
    /// - Returns: Original path to the STL of every file that converted successfully.
    static func convert(_ files: [String], freecad: String) -> [String: URL] {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        var result: [String: URL] = [:]
        var jobs: [[String: String]] = []
        for file in files {
            let output = cacheURL(for: file)
            if fileManager.fileExists(atPath: output.path) { result[file] = output } else { jobs.append(["in": file, "out": output.path]) }
        }
        guard !jobs.isEmpty, let json = try? JSONSerialization.data(withJSONObject: jobs) else { return result }

        let id = UUID().uuidString
        let jobsURL = fileManager.temporaryDirectory.appendingPathComponent("stler-\(id).json")
        let scriptURL = fileManager.temporaryDirectory.appendingPathComponent("stler-\(id).py")
        defer { try? fileManager.removeItem(at: jobsURL); try? fileManager.removeItem(at: scriptURL) }
        guard (try? json.write(to: jobsURL)) != nil, (try? script.write(to: scriptURL, atomically: true, encoding: .utf8)) != nil else { return result }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: freecad)
        process.arguments = [scriptURL.path]
        process.environment = ProcessInfo.processInfo.environment.merging(["STLER_JOBS": jobsURL.path]) { $1 }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return result }
        process.waitUntilExit()
        for job in jobs where fileManager.fileExists(atPath: job["out"]!) { result[job["in"]!] = URL(fileURLWithPath: job["out"]!) }
        return result
    }

    /// FNV-1a hash of path, mtime and size; `String.hashValue` is randomised per process and would defeat the cache.
    private static func cacheURL(for path: String) -> URL {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let key = "\(path)|\((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)|\(attributes?[.size] as? Int ?? 0)"
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return cacheDirectory.appendingPathComponent(String(format: "%016llx.stl", hash))
    }
}
