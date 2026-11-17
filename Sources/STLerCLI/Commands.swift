import AppKit

struct CLIError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

let usage = """
usage:
  stler [run] [--view V] [--color system|#RRGGBB] [--force|--no-force] [--depth N|deep]
         [--badge off|topLeft|topRight|bottomLeft|bottomRight] [--dry-run] [<folder|file>...]
  stler follow                 render the folder in front in Finder, down to config followDepth
  stler install | uninstall    LaunchAgent that keeps `follow` running at login
  stler reset [--all] [<folder|file>...]
  stler config get [key] | set <key> <value>
views: iso front back left right top bottom
keys:  view color formats firstPlateOnly force followDepth badge freecadPath watch
run without paths uses the folder open in Finder (fallback: cwd) first, then config `watch`.
run skips files already rendered with the same settings; force (config or flag) re-renders everything.
followDepth: 1 = only the open folder, 2, 3... = levels of subfolders, deep = unlimited.
reset removes only icons set by stler (--all adds config `watch`).
"""

/// Flags shared by `run` and `reset`, applied on top of the saved config.
struct RunOptions {
    var config: Config
    var maxDepth: Int?
    var dryRun = false
    var all = false
    var paths: [String] = []

    init(parsing arguments: [String], base: Config) throws {
        config = base
        var iterator = arguments.makeIterator()
        func value(for flag: String) throws -> String {
            guard let next = iterator.next() else { throw CLIError("\(flag) needs a value") }
            return next
        }
        while let argument = iterator.next() {
            switch argument {
            case "--view", "--color", "--badge":
                if let error = config.set(String(argument.dropFirst(2)), try value(for: argument)) { throw CLIError(error) }
            case "--depth":
                var probe = Config()
                if let error = probe.set("followDepth", try value(for: argument)) { throw CLIError(error) }
                maxDepth = probe.maxDepth
            case "--force": config.force = true
            case "--no-force": config.force = false
            case "--dry-run": dryRun = true
            case "--all": all = true
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
        paths = [folder] + options.config.watch
    }
    let files = FileScanner.scan(paths, formats: options.config.formats, maxDepth: options.maxDepth)
    if options.dryRun {
        files.forEach { print($0) }
        return
    }
    let result = IconBatch.apply(files, config: options.config) { done, total in
        if done % 25 == 0 { print("[\(done)/\(total)]") }
    }
    result.messages.forEach { print($0) }
    print(summary(result))
}

func reset(_ arguments: [String]) throws {
    let options = try RunOptions(parsing: arguments, base: Config.load())
    let paths = options.paths + (options.all ? options.config.watch : [])
    guard !paths.isEmpty else { throw CLIError(usage) }
    let result = IconBatch.reset(FileScanner.scan(paths, formats: Array(Config.supportedFormats)))
    print("reset \(result.reset), untouched \(result.untouched) (no stler signature)")
}

func configure(_ arguments: [String]) throws {
    var config = Config.load()
    switch arguments.first {
    case "get":
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any] ?? [:]
        if arguments.count > 1 {
            guard let value = object[arguments[1]] else { throw CLIError("unknown key `\(arguments[1])`") }
            print(value)
        } else {
            let json = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: json, as: UTF8.self))
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
func follow() -> Never {
    var last: String?
    var unavailable = false
    func tick() {
        let folder = FinderFolder.front()
        if folder == nil, !unavailable { print("finder: no front window / no access") }
        unavailable = folder == nil
        guard let folder, folder != last else { return }
        last = folder
        print("\(folder): \(summary(IconBatch.applyToFolder(folder, config: Config.load())))")
    }
    tick()
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in tick() }
    RunLoop.main.run()
    exit(0)
}
