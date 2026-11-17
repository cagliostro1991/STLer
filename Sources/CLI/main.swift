import AppKit

let usage = """
usage:
  styler [run] [--view V] [--color system|#RRGGBB] [--force|--no-force] [--depth N|deep] [--badge off|topLeft|topRight|bottomLeft|bottomRight] [--dry-run] [<folder|file>...]
  styler follow            (render the Finder folder in front down to config followDepth; Ctrl-C to stop)
  styler install | uninstall   (LaunchAgent that keeps `follow` running at login)
  styler reset [--all] [<folder|file>...]
  styler config get [key] | set <key> <value>
views: iso front back left right top bottom
keys:  view color formats firstPlateOnly force followDepth badge freecadPath watch
run without paths uses the folder open in Finder (fallback: cwd) first, then config `watch`.
run skips files already rendered with the same settings; force (config or flag) re-renders everything.
followDepth: 1 = only the open folder, 2, 3... = levels of subfolders, deep = unlimited.
reset removes only icons set by styler (--all = config `watch` paths).
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

setvbuf(stdout, nil, _IOLBF, 0)

let agentLabel = "dev.styler.follow"
let agentPlist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")

/// Runs launchctl; returns the exit status.
@discardableResult func launchctl(_ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
    return p.terminationStatus
}
var args = Array(CommandLine.arguments.dropFirst())
let command = ["run", "reset", "config", "follow", "install", "uninstall"].contains(args.first ?? "") ? args.removeFirst() : "run"
var cfg = Config.load()

if command == "install" {
    let fm = FileManager.default
    let bin = fm.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/styler")
    let log = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/styler.log")
    guard let me = Bundle.main.executableURL else { fail("cannot locate own executable") }
    try fm.createDirectory(at: bin.deletingLastPathComponent(), withIntermediateDirectories: true)
    if me.resolvingSymlinksInPath().path != bin.path {
        try? fm.removeItem(at: bin)
        try fm.copyItem(at: me, to: bin)
    }
    let plist: [String: Any] = [
        "Label": agentLabel,
        "ProgramArguments": [bin.path, "follow"],
        "RunAtLoad": true,
        "KeepAlive": true,
        "ProcessType": "Background",
        "LimitLoadToSessionType": "Aqua",
        "StandardOutPath": log.path,
        "StandardErrorPath": log.path,
    ]
    try fm.createDirectory(at: agentPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: agentPlist)
    launchctl(["bootout", "gui/\(getuid())/\(agentLabel)"])
    guard launchctl(["bootstrap", "gui/\(getuid())", agentPlist.path]) == 0 else { fail("launchctl bootstrap failed") }
    print("installed: \(bin.path), log: \(log.path)")
    exit(0)
}

if command == "uninstall" {
    launchctl(["bootout", "gui/\(getuid())/\(agentLabel)"])
    try? FileManager.default.removeItem(at: agentPlist)
    print("uninstalled (binary in ~/.local/bin/styler and config left in place)")
    exit(0)
}

if command == "follow" {
    var last: String?
    var lastWasNil = false
    while true {
        let polled = activeFinderFolder()
        if polled == nil, !lastWasNil { print("finder: no front window / no access") }
        lastWasNil = polled == nil
        if let folder = polled, folder != last {
            last = folder
            let r = processFolder(folder, config: Config.load())
            print("\(folder): rendered \(r.rendered), skipped \(r.skipped), failed \(r.failed)")
        }
        Thread.sleep(forTimeInterval: 2)
    }
}

if command == "config" {
    switch args.first {
    case "get":
        let data = try JSONEncoder().encode(cfg)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if args.count > 1 { print(obj[args[1]] ?? fail("unknown key `\(args[1])`")) }
        else { print(String(decoding: try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)) }
    case "set":
        guard args.count >= 3 else { fail(usage) }
        if let err = cfg.set(args[1], args[2...].joined(separator: ",")) { fail(err) }
        try cfg.save()
    default: fail(usage)
    }
    exit(0)
}

var view = cfg.view, colorSpec = cfg.color, force = cfg.force, all = false, dryRun = false, maxDepth: Int?, badge = cfg.badge
var paths: [String] = []
var it = args.makeIterator()
while let a = it.next() {
    switch a {
    case "--view": view = it.next() ?? ""
    case "--color": colorSpec = (it.next() ?? "").lowercased()
    case "--force": force = true
    case "--no-force": force = false
    case "--all": all = true
    case "--dry-run": dryRun = true
    case "--badge":
        badge = it.next() ?? ""
        guard Config.badgeValues.contains(badge) else { fail("--badge must be one of: \(Config.badgeValues.joined(separator: ", "))") }
    case "--depth":
        let v = it.next() ?? ""
        guard v == "deep" || (Int(v) ?? 0) >= 1 else { fail("--depth must be 1, 2, 3... or deep") }
        maxDepth = v == "deep" ? nil : Int(v)
    default: paths.append(a)
    }
}
let explicitPaths = !paths.isEmpty
if command == "reset", all { paths += cfg.watch }
var activeFolder: String?
if command == "run", !explicitPaths {
    activeFolder = activeFinderFolder() ?? FileManager.default.currentDirectoryPath
    paths = [activeFolder!] + cfg.watch
}
guard !paths.isEmpty else { fail(usage) }
guard viewDirections[view] != nil else { fail("unknown view `\(view)`") }
guard parseColor(colorSpec) != nil else { fail("color must be `system` or #RRGGBB") }

var files: [String] = []
var seen = Set<String>()
for p in paths {
    let formats = command == "reset" ? Array(Config.supportedFormats) : cfg.formats
    for f in byDepth(collectFiles([p], formats: formats, maxDepth: maxDepth), under: p) where seen.insert(f).inserted { files.append(f) }
}
if let activeFolder { print("active folder: \(activeFolder)") }
if dryRun { files.forEach { print($0) }; exit(0) }

if command == "reset" {
    let r = resetIcons(files)
    print("reset \(r.reset), untouched \(r.untouched) (no styler signature)")
    exit(0)
}

let r = renderBatch(files, config: cfg, view: view, colorSpec: colorSpec, badge: badge, force: force, progress: true)
print("rendered \(r.rendered), skipped \(r.skipped), failed \(r.failed)")
