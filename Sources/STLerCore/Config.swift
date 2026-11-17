import AppKit

/// User settings, stored as JSON at `~/.config/stler/config.json` (override the path with `STLER_CONFIG`).
struct Config: Codable, Equatable {
    var view = ViewAngle.iso
    /// `system` (system gray) or `#rrggbb`.
    var color = "system"
    /// Enabled formats: `stl`, `3mf`, `step`.
    var formats = ["stl", "3mf"]
    /// For multi-plate 3MF projects, render only the first plate.
    var firstPlateOnly = true
    /// Re-render files even when their signature is up to date.
    var force = false
    /// Folder levels processed by `follow`; 0 means unlimited.
    var followDepth = 3
    var badge = BadgeCorner.bottomRight
    /// `freecadcmd` location for STEP; empty means the default FreeCAD install path.
    var freecadPath = ""
    /// Folders affected by `reset --all` and the app's reset button.
    var watch: [String] = []

    static let supportedFormats: Set<String> = ["stl", "3mf", "step"]

    static let url = ProcessInfo.processInfo.environment["STLER_CONFIG"].map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/stler/config.json")

    /// `followDepth` as an optional limit.
    var maxDepth: Int? { followDepth == 0 ? nil : followDepth }

    var nsColor: NSColor { Self.parseColor(color) ?? .systemGray }

    init() {}

    /// Missing or invalid keys fall back to their defaults, so older config files keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        view = read(.view, view)
        color = read(.color, color)
        formats = read(.formats, formats)
        firstPlateOnly = read(.firstPlateOnly, firstPlateOnly)
        force = read(.force, force)
        followDepth = read(.followDepth, followDepth)
        badge = read(.badge, badge)
        freecadPath = read(.freecadPath, freecadPath)
        watch = read(.watch, watch)
    }

    /// Loads the config file, or the defaults when it is missing or unreadable.
    static func load() -> Config {
        guard let data = try? Data(contentsOf: url), let config = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return config
    }

    func save() throws {
        try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: Self.url)
    }

    /// Sets one key from its string form (comma-separated for lists).
    /// - Returns: An error message for invalid input, `nil` on success.
    mutating func set(_ key: String, _ value: String) -> String? {
        let list = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        switch key {
        case "view":
            guard let v = ViewAngle(rawValue: value) else { return "view must be one of: \(ViewAngle.allCases.map(\.rawValue).joined(separator: ", "))" }
            view = v
        case "color":
            guard Self.parseColor(value) != nil else { return "color must be `system` or #RRGGBB" }
            color = value.lowercased()
        case "formats":
            guard !list.isEmpty, Set(list).isSubset(of: Self.supportedFormats) else { return "formats must be a comma list of: \(Self.supportedFormats.sorted().joined(separator: ", "))" }
            formats = list
        case "firstPlateOnly":
            guard let b = Bool(value) else { return "firstPlateOnly must be true or false" }
            firstPlateOnly = b
        case "force":
            guard let b = Bool(value) else { return "force must be true or false" }
            force = b
        case "followDepth":
            guard value == "deep" || (Int(value) ?? 0) >= 1 else { return "followDepth must be 1, 2, 3... or `deep` (unlimited)" }
            followDepth = Int(value) ?? 0
        case "badge":
            guard let b = BadgeCorner(rawValue: value) else { return "badge must be one of: \(BadgeCorner.allCases.map(\.rawValue).joined(separator: ", "))" }
            badge = b
        case "freecadPath":
            guard value.isEmpty || FileManager.default.isExecutableFile(atPath: (value as NSString).expandingTildeInPath) else { return "freecadPath must be empty (auto-detect) or an executable freecadcmd" }
            freecadPath = value
        case "watch":
            watch = list
        default:
            return "unknown key `\(key)`"
        }
        return nil
    }

    /// Parses `system` or `#RRGGBB`.
    static func parseColor(_ spec: String) -> NSColor? {
        if spec == "system" { return .systemGray }
        guard spec.count == 7, spec.hasPrefix("#"), let v = Int(spec.dropFirst(), radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}
