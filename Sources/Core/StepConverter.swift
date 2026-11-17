import Foundation

/// Optional STEP support: converts STEP/STP to cached STL through FreeCAD's headless `freecadcmd`.
enum StepConverter {
    static let defaultPath = "/Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd"
    static let cacheDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/styler")

    private static let script = """
    import json, os, Part, MeshPart
    for job in json.load(open(os.environ["STYLER_JOBS"])):
        try:
            shape = Part.read(job["in"])
            deflection = max(shape.BoundBox.DiagonalLength * 0.001, 0.001)
            MeshPart.meshFromShape(Shape=shape, LinearDeflection=deflection, AngularDeflection=0.5, Relative=False).write(job["out"])
        except Exception as e:
            print("styler-fail", job["in"], e)
    """

    /// Path of an executable `freecadcmd`, from the config override or the default install location.
    static func executable(_ custom: String) -> String? {
        let path = custom.isEmpty ? defaultPath : (custom as NSString).expandingTildeInPath
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    static func isStep(_ path: String) -> Bool {
        ["step", "stp"].contains((path as NSString).pathExtension.lowercased())
    }

    /// Cache file for a STEP file, keyed by path, modification time and size.
    static func cacheURL(for path: String) -> URL {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let key = "\(path)|\((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)|\(attrs?[.size] as? Int ?? 0)"
        var h: UInt64 = 0xcbf29ce484222325
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return cacheDir.appendingPathComponent(String(format: "%016llx.stl", h))
    }

    /// Converts all files in one FreeCAD run (its start-up dominates the cost); returns original path to STL for the ones that succeeded.
    static func convert(_ files: [String], freecad: String) -> [String: URL] {
        let fm = FileManager.default
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        var result: [String: URL] = [:]
        var jobs: [[String: String]] = []
        for f in files {
            let out = cacheURL(for: f)
            if fm.fileExists(atPath: out.path) { result[f] = out } else { jobs.append(["in": f, "out": out.path]) }
        }
        guard !jobs.isEmpty, let json = try? JSONSerialization.data(withJSONObject: jobs) else { return result }
        let id = UUID().uuidString
        let jobsURL = fm.temporaryDirectory.appendingPathComponent("styler-\(id).json")
        let scriptURL = fm.temporaryDirectory.appendingPathComponent("styler-\(id).py")
        defer { try? fm.removeItem(at: jobsURL); try? fm.removeItem(at: scriptURL) }
        guard (try? json.write(to: jobsURL)) != nil, (try? script.write(to: scriptURL, atomically: true, encoding: .utf8)) != nil else { return result }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: freecad)
        p.arguments = [scriptURL.path]
        p.environment = ProcessInfo.processInfo.environment.merging(["STYLER_JOBS": jobsURL.path]) { $1 }
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return result }
        p.waitUntilExit()
        for j in jobs where fm.fileExists(atPath: j["out"]!) { result[j["in"]!] = URL(fileURLWithPath: j["out"]!) }
        return result
    }
}
