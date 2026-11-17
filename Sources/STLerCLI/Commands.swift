import AppKit

struct CLIError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

let usage = """
usage:
  stler [run] [--view V] [--projection orthographic|perspective] [--color system|#RRGGBB]
        [--label off|topLeft|topRight|bottomLeft|bottomRight] [--depth N|deep] [--force] [--dry-run] [<folder|file>...]
  stler follow                 render the folder in front in Finder, down to config followDepth
  stler install | uninstall    LaunchAgent that keeps `follow` running at login
  stler reset <folder|file>... remove icons set by stler
  stler config get [key] | set <key> <value>
views: iso front back left right top bottom
keys:  followDepth stepEngine (freecad|opencascade) freecadPath scope scopeFolders (comma list)
       <type>.enabled <type>.view <type>.projection <type>.color
       <type>.label.corner|textColor|backgroundColor|cornerRadius|opacity     (type: stl, 3mf, step)
run flags change every enabled type for this run only; without paths run uses the folder open in Finder (fallback: cwd).
run skips files already rendered with the same settings; --force re-renders them.
followDepth: 1 = only the open folder, 2, 3... = levels of subfolders, deep = unlimited.
reset removes only icons set by stler.
"""

/// Flags for `run` and `reset`, applied on top of the saved config for one run.
struct RunOptions {
    var config: Config
    var maxDepth: Int?
    var force = false
    var dryRun = false
    var paths: [String] = []

    /// Flags that set one per-type key on every type.
    private static let typeFlags = ["--view": "view", "--projection": "projection", "--color": "color", "--label": "label.corner"]

    init(parsing arguments: [String], base: Config) throws {
        config = base
        var iterator = arguments.makeIterator()
        func value(for flag: String) throws -> String {
            guard let next = iterator.next() else { throw CLIError("\(flag) needs a value") }
            return next
        }
        while let argument = iterator.next() {
            switch argument {
            case _ where Self.typeFlags[argument] != nil:
                let text = try value(for: argument)
                for type in FileType.allCases {
                    if let error = config.set("\(type.rawValue).\(Self.typeFlags[argument]!)", text) { throw CLIError(error) }
                }
            case "--depth":
                var probe = Config()
                if let error = probe.set("followDepth", try value(for: argument)) { throw CLIError(error) }
                maxDepth = probe.maxDepth
            case "--force": force = true
            case "--dry-run": dryRun = true
            default: paths.append(argument)
            }
        }
    }
}

private func summary(_ result: BatchResult) -> String {
    "rendered \(result.rendered), skipped \(result.skipped), failed \(result.failed)"
}

func runIcons(_ arguments: [String]) throws {
    let options = try RunOptions(parsing: arguments, base: Config.load())
    var paths = options.paths
    if paths.isEmpty {
        let folder = FinderFolder.front() ?? FileManager.default.currentDirectoryPath
        print("active folder: \(folder)")
        paths = [folder]
    }
    let files = FileScanner.scan(paths, formats: options.config.enabledFormats, maxDepth: options.maxDepth)
    if options.dryRun {
        files.forEach { print($0) }
        return
    }
    let result = IconBatch.apply(files, config: options.config, force: options.force) { done, total, _ in
        if done % 25 == 0 { print("[\(done)/\(total)]") }
    }
    result.messages.forEach { print($0) }
    print(summary(result))
}

func reset(_ arguments: [String]) throws {
    let options = try RunOptions(parsing: arguments, base: Config.load())
    guard !options.paths.isEmpty else { throw CLIError(usage) }
    let result = IconBatch.reset(FileScanner.scan(options.paths, formats: FileType.allCases.map(\.rawValue)))
    print("reset \(result.reset), untouched \(result.untouched) (no stler signature)")
}

func configure(_ arguments: [String]) throws {
    var config = Config.load()
    switch arguments.first {
    case "get":
        var value: Any = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config))
        if arguments.count > 1 {
            for part in arguments[1].split(separator: ".") {
                guard let next = (value as? [String: Any])?[String(part)] else { throw CLIError("unknown key `\(arguments[1])`") }
                value = next
            }
        }
        if JSONSerialization.isValidJSONObject(value) {
            print(String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        } else {
            print(value)
        }
    case "set":
        guard arguments.count >= 3 else { throw CLIError(usage) }
        if let error = config.set(arguments[1], arguments[2...].joined(separator: ",")) { throw CLIError(error) }
        try config.save()
    default:
        throw CLIError(usage)
    }
}

/// Polls the front Finder window every 2 s and renders each newly opened folder. Never returns.
/// A long run checks the front folder now and then and gives way when another folder is opened; the signature makes resuming cheap.
func follow() -> Never {
    var last: String?
    var unavailable = false
    func tick() {
        var folder = FinderFolder.front()
        if folder == nil, !unavailable { print("finder: no front window / no access") }
        unavailable = folder == nil
        while let current = folder, current != last {
            last = current
            var lastCheck = Date()
            var entry: ActivityLog.Entry?
            var lastWrite = Date.distantPast
            let result = IconBatch.applyToFolder(current, config: Config.load(), onProgress: { done, total, file in
                var shown = entry ?? ActivityLog.Entry(title: "Finder: \((current as NSString).abbreviatingWithTildeInPath)", running: true)
                shown.done = done; shown.total = total; shown.current = file
                entry = shown
                guard Date().timeIntervalSince(lastWrite) > 1 || done == 1 else { return }
                lastWrite = Date()
                ActivityLog.upsert(shown)
            }, shouldContinue: {
                guard Date().timeIntervalSince(lastCheck) > 1.5 else { return true }
                lastCheck = Date()
                let front = FinderFolder.front()
                return front == nil || front == current
            })
            if var finished = entry {
                finished.running = false
                finished.current = ""
                finished.summary = summary(result) + (result.interrupted ? " (interrupted, another folder opened)" : "")
                ActivityLog.upsert(finished)
            }
            print("\(current): \(summary(result))\(result.interrupted ? " (interrupted, another folder opened)" : "")")
            folder = result.interrupted ? FinderFolder.front() : nil
        }
    }
    tick()
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in tick() }
    RunLoop.main.run()
    exit(0)
}
