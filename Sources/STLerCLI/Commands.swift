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
  stler version | update       print the version / look for a newer release on GitHub
  stler reset <folder|file>... remove icons set by stler
  stler config get [key] | set <key> <value>
views: iso front back left right top bottom
keys:  followDepth followOpened followOpenedFolder stepEngine (freecad|opencascade) freecadPath scope scopeFolders (comma list)
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
    var state = FollowState()
    var unavailable = false
    func tick() {
        var folder = FinderFolder.front()
        if folder == nil, !unavailable { print("finder: no front window / no access") }
        unavailable = folder == nil
        while let current = folder, state.shouldScan(current, modified: FollowState.modificationDate(of: current)) {
            var lastCheck = Date()
            var entry = ActivityLog.Entry(title: "Finder: \((current as NSString).abbreviatingWithTildeInPath)", running: true)
            var published = false
            var cancelled = false
            let started = Date()
            var lastWrite = Date.distantPast
            let result = IconBatch.applyToFolder(current, config: Config.load(), onProgress: { done, total, file in
                entry.done = done; entry.total = total; entry.current = file
                // A scan that finds nothing to do ends within a second and is not worth a journal line.
                guard Date().timeIntervalSince(started) > 1, Date().timeIntervalSince(lastWrite) > 1 else { return }
                lastWrite = Date()
                published = true
                ActivityLog.upsert(entry)
            }, shouldContinue: {
                guard Date().timeIntervalSince(lastCheck) > 1.5 else { return true }
                lastCheck = Date()
                if published, ActivityLog.isCancelRequested(entry.id) { cancelled = true; return false }
                let front = FinderFolder.front()
                return front == nil || front == current
            })
            let reason = cancelled ? " (cancelled)" : result.interrupted ? " (interrupted, another folder opened)" : ""
            if result.rendered > 0 || result.failed > 0 || cancelled {
                entry.running = false
                entry.current = ""
                entry.summary = summary(result) + reason
                ActivityLog.upsert(entry)
            } else if published {
                ActivityLog.remove(entry.id)
            }
            if result.interrupted, !cancelled { state.forget(current) }
            print("\(current): \(summary(result))\(reason)")
            folder = result.interrupted && !cancelled ? FinderFolder.front() : nil
        }
    }
    let watcher = OpenedFileWatcher()
    func openedFiles(_ paths: [String]) {
        let config = Config.load()
        let opened = OpenedFileWatcher.relevant(paths, config: config)
        var files = opened
        if config.followOpenedFolder {
            // The opened files come first, then their neighbours; `pending` keeps only what needs a new icon.
            files += Set(opened.map { ($0 as NSString).deletingLastPathComponent }).sorted().flatMap { FileScanner.siblings(of: $0 + "/x", formats: config.enabledFormats) }
        }
        var seen = Set<String>()
        files = IconBatch.pending(files.filter { seen.insert($0).inserted }, config: config)
        guard !files.isEmpty else { return }
        let title = files.count == 1 ? "Opened: \((files[0] as NSString).lastPathComponent)" : "Opened: \(files.count) files"
        var entry = ActivityLog.Entry(title: title, running: true, done: 0, total: files.count)
        ActivityLog.upsert(entry)
        let result = IconBatch.apply(files, config: config)
        entry.running = false
        entry.done = files.count
        entry.summary = summary(result)
        ActivityLog.upsert(entry)
        print("\(title): \(summary(result))")
    }
    func syncWatcher() {
        let config = Config.load()
        if config.followOpened, !watcher.isRunning {
            watcher.start(extensions: FileType.allCases.flatMap(\.extensions), onOpened: openedFiles)
        } else if !config.followOpened, watcher.isRunning {
            watcher.stop()
        }
    }
    tick()
    syncWatcher()
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in tick(); syncWatcher() }
    RunLoop.main.run()
    exit(0)
}

/// `stler update`: asks GitHub whether a newer release exists and prints the answer.
func checkForUpdate() -> Never {
    UpdateChecker.check { outcome in
        switch outcome {
        case .upToDate: print("stler \(AppVersion.current) is up to date")
        case .available(let release): print("stler \(release.tag) is available (you have \(AppVersion.current)): \(release.url.absoluteString)")
        case .failed(let message): FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1)
        }
        exit(0)
    }
    RunLoop.main.run()
    exit(0)
}
