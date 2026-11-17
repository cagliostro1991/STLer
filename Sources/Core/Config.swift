import AppKit

/// Persistent settings stored in `~/.config/styler/config.json`.
struct Config: Codable, Equatable {
    var view = "iso"
    var color = "system"
    var formats = ["stl", "3mf"]
    var firstPlateOnly = true
    var force = false
    var followDepth = 3
    var badge = "bottomRight"
    var freecadPath = ""
    var watch: [String] = []

    static let supportedFormats: Set<String> = ["stl", "3mf", "step"]
    static let badgeValues = ["off", "topLeft", "topRight", "bottomLeft", "bottomRight"]
    static let url = ProcessInfo.processInfo.environment["STYLER_CONFIG"].map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/styler/config.json")

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        view = try c.decodeIfPresent(String.self, forKey: .view) ?? view
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? color
        formats = try c.decodeIfPresent([String].self, forKey: .formats) ?? formats
        firstPlateOnly = try c.decodeIfPresent(Bool.self, forKey: .firstPlateOnly) ?? firstPlateOnly
        force = try c.decodeIfPresent(Bool.self, forKey: .force) ?? force
        followDepth = try c.decodeIfPresent(Int.self, forKey: .followDepth) ?? followDepth
        badge = try c.decodeIfPresent(String.self, forKey: .badge) ?? badge
        freecadPath = try c.decodeIfPresent(String.self, forKey: .freecadPath) ?? freecadPath
        watch = try c.decodeIfPresent([String].self, forKey: .watch) ?? watch
    }

    /// Loads the config file, falling back to defaults when it is missing or unreadable.
    static func load() -> Config {
        guard let data = try? Data(contentsOf: url), let cfg = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return cfg
    }

    /// Writes the config file, creating `~/.config/styler` when needed.
    func save() throws {
        try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: Self.url)
    }

    /// Sets one key from its command-line string form; returns an error message on invalid input.
    mutating func set(_ key: String, _ value: String) -> String? {
        let list = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        switch key {
        case "view":
            guard viewDirections[value] != nil else { return "view must be one of: \(viewDirections.keys.sorted().joined(separator: ", "))" }
            view = value
        case "color":
            guard parseColor(value) != nil else { return "color must be `system` or #RRGGBB" }
            color = value.lowercased()
        case "formats":
            guard !list.isEmpty, Set(list).isSubset(of: Self.supportedFormats) else { return "formats must be a comma list of: stl, 3mf, step" }
            formats = list
        case "firstPlateOnly":
            guard let b = Bool(value) else { return "firstPlateOnly must be true or false" }
            firstPlateOnly = b
        case "force":
            guard let b = Bool(value) else { return "force must be true or false" }
            force = b
        case "freecadPath":
            guard value.isEmpty || FileManager.default.isExecutableFile(atPath: (value as NSString).expandingTildeInPath) else { return "freecadPath must be empty (auto-detect) or an executable freecadcmd" }
            freecadPath = value
        case "badge":
            guard Self.badgeValues.contains(value) else { return "badge must be one of: \(Self.badgeValues.joined(separator: ", "))" }
            badge = value
        case "followDepth":
            guard value == "deep" || (Int(value) ?? 0) >= 1 else { return "followDepth must be 1, 2, 3... or `deep` (unlimited)" }
            followDepth = value == "deep" ? 0 : Int(value)!
        case "watch": watch = list
        default: return "unknown key `\(key)`"
        }
        return nil
    }
}

/// Parses `system` (system gray) or `#RRGGBB`.
func parseColor(_ s: String) -> NSColor? {
    if s == "system" { return .systemGray }
    guard s.count == 7, s.hasPrefix("#"), let v = Int(s.dropFirst(), radix: 16) else { return nil }
    return NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}
