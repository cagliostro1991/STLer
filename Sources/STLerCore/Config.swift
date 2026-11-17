import AppKit

/// How the format label on an icon is drawn.
struct LabelStyle: Codable, Equatable {
    var corner = LabelCorner.bottomRight
    var textColor = "#ffffff"
    var backgroundColor = "#262626"
    /// Percent of the label height; 50 makes a pill.
    var cornerRadius = 50
    /// 0...1, applies to the label background and text together.
    var opacity = 0.85

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        corner = read(.corner, corner)
        textColor = read(.textColor, textColor)
        backgroundColor = read(.backgroundColor, backgroundColor)
        cornerRadius = read(.cornerRadius, cornerRadius)
        opacity = read(.opacity, opacity)
    }

    /// - Returns: An error message for invalid input, `nil` on success.
    mutating func set(_ key: String, _ value: String) -> String? {
        switch key {
        case "corner":
            guard let v = LabelCorner(rawValue: value) else { return "corner must be one of: \(LabelCorner.allCases.map(\.rawValue).joined(separator: ", "))" }
            corner = v
        case "textColor", "backgroundColor":
            guard Config.isHex(value) else { return "\(key) must be #RRGGBB" }
            if key == "textColor" { textColor = value.lowercased() } else { backgroundColor = value.lowercased() }
        case "cornerRadius":
            guard let n = Int(value), (0...50).contains(n) else { return "cornerRadius must be a whole number from 0 to 50 (percent of the label height)" }
            cornerRadius = n
        case "opacity":
            guard let n = Double(value), (0...1).contains(n) else { return "opacity must be a number from 0 to 1" }
            opacity = n
        default:
            return "unknown label key `\(key)`"
        }
        return nil
    }
}

/// Settings of one file type.
struct TypeStyle: Codable, Equatable {
    var enabled = true
    var view = ViewAngle.iso
    var projection = Projection.orthographic
    /// `system` (system gray) or `#rrggbb`.
    var color = "system"
    var label = LabelStyle()

    init(enabled: Bool = true, color: String = "system") {
        self.enabled = enabled
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        enabled = read(.enabled, enabled)
        view = read(.view, view)
        projection = read(.projection, projection)
        color = read(.color, color)
        label = read(.label, label)
    }

    var nsColor: NSColor { Config.parseColor(color) ?? .systemGray }

    /// - Returns: An error message for invalid input, `nil` on success.
    mutating func set(_ key: String, _ value: String) -> String? {
        if key.hasPrefix("label.") { return label.set(String(key.dropFirst(6)), value) }
        switch key {
        case "enabled":
            guard let b = Bool(value) else { return "enabled must be true or false" }
            enabled = b
        case "view":
            guard let v = ViewAngle(rawValue: value) else { return "view must be one of: \(ViewAngle.allCases.map(\.rawValue).joined(separator: ", "))" }
            view = v
        case "projection":
            guard let p = Projection(rawValue: value) else { return "projection must be one of: \(Projection.allCases.map(\.rawValue).joined(separator: ", "))" }
            projection = p
        case "color":
            guard Config.parseColor(value) != nil else { return "color must be `system` or #RRGGBB" }
            color = value.lowercased()
        default:
            return "unknown key `\(key)`"
        }
        return nil
    }
}

/// User settings, stored as JSON at `~/.config/stler/config.json` (override the path with `STLER_CONFIG`).
/// Older files with global `view`/`color`/`formats`/`badge` keys are migrated when read.
struct Config: Codable, Equatable {
    var stl = TypeStyle(color: FileType.stl.defaultColor)
    var threeMF = TypeStyle(color: FileType.threeMF.defaultColor)
    var step = TypeStyle(enabled: false, color: FileType.step.defaultColor)
    /// For multi-plate 3MF projects, render only the first plate.
    var firstPlateOnly = true
    /// Folder levels processed by `follow`; 0 means unlimited.
    var followDepth = 3
    /// `freecadcmd` location for STEP; empty means the usual install locations. STEP stays off without it.
    var freecadPath = ""
    /// Where the app's Clear and Apply buttons work: the listed folders, or the whole home folder.
    var scope = Scope.folder
    var scopeFolders: [String] = []

    enum Scope: String, Codable { case folder, home }

    private enum CodingKeys: String, CodingKey {
        case stl, threeMF = "3mf", step, firstPlateOnly, followDepth, freecadPath, scope, scopeFolders
    }

    private enum LegacyKeys: String, CodingKey { case view, color, formats, badge, scopeFolder }

    static let url = ProcessInfo.processInfo.environment["STLER_CONFIG"].map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/stler/config.json")

    subscript(type: FileType) -> TypeStyle {
        get {
            switch type {
            case .stl: stl
            case .threeMF: threeMF
            case .step: step
            }
        }
        set {
            switch type {
            case .stl: stl = newValue
            case .threeMF: threeMF = newValue
            case .step: step = newValue
            }
        }
    }

    /// Formats to scan for, as `FileScanner` expects them. STEP counts only while FreeCAD can be found.
    var enabledFormats: [String] {
        FileType.allCases.filter { self[$0].enabled && ($0 != .step || StepConverter.executable(freecadPath) != nil) }.map(\.rawValue)
    }

    /// `followDepth` as an optional limit.
    var maxDepth: Int? { followDepth == 0 ? nil : followDepth }

    /// Folders the app's Clear and Apply buttons work on; empty when no folder is chosen.
    var scopePaths: [String] {
        switch scope {
        case .home: [NSHomeDirectory()]
        case .folder: scopeFolders.map { ($0 as NSString).expandingTildeInPath }
        }
    }

    init() {}

    /// Missing or invalid keys fall back to their defaults, so older config files keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        if !c.contains(.stl) && !c.contains(.threeMF) && !c.contains(.step) { migrateLegacy(try decoder.container(keyedBy: LegacyKeys.self)) }
        stl = read(.stl, stl)
        threeMF = read(.threeMF, threeMF)
        step = read(.step, step)
        firstPlateOnly = read(.firstPlateOnly, firstPlateOnly)
        followDepth = read(.followDepth, followDepth)
        freecadPath = read(.freecadPath, freecadPath)
        scope = read(.scope, scope)
        scopeFolders = read(.scopeFolders, scopeFolders)
        if scopeFolders.isEmpty, let old = try? decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(String.self, forKey: .scopeFolder), !old.isEmpty {
            scopeFolders = [old]
        }
    }

    /// Copies the old global view, colour and label corner to every type and turns `formats` into the enabled flags.
    private mutating func migrateLegacy(_ legacy: KeyedDecodingContainer<LegacyKeys>) {
        let view = (try? legacy.decodeIfPresent(ViewAngle.self, forKey: .view)) ?? nil
        let color = (try? legacy.decodeIfPresent(String.self, forKey: .color)) ?? nil
        let badge = (try? legacy.decodeIfPresent(LabelCorner.self, forKey: .badge)) ?? nil
        let formats = (try? legacy.decodeIfPresent([String].self, forKey: .formats)) ?? nil
        for type in FileType.allCases {
            var style = self[type]
            if let view { style.view = view }
            if let color, Self.parseColor(color) != nil { style.color = color }
            if let badge { style.label.corner = badge }
            if let formats { style.enabled = formats.contains(type.rawValue) }
            self[type] = style
        }
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

    /// Sets one setting from its string form. Per-type keys are dotted: `stl.view`, `3mf.enabled`, `step.label.textColor`.
    /// - Returns: An error message for invalid input, `nil` on success.
    mutating func set(_ key: String, _ value: String) -> String? {
        let parts = key.split(separator: ".", maxSplits: 1).map(String.init)
        if parts.count == 2, let type = FileType(rawValue: parts[0]) {
            if type == .step, parts[1] == "enabled", Bool(value) == true, StepConverter.executable(freecadPath) == nil {
                return "STEP needs FreeCAD: install it or set freecadPath to an executable freecadcmd first"
            }
            return self[type].set(parts[1], value)
        }
        switch key {
        case "firstPlateOnly":
            guard let b = Bool(value) else { return "firstPlateOnly must be true or false" }
            firstPlateOnly = b
        case "followDepth":
            guard value == "deep" || (Int(value) ?? 0) >= 1 else { return "followDepth must be 1, 2, 3... or `deep` (unlimited)" }
            followDepth = Int(value) ?? 0
        case "freecadPath":
            guard value.isEmpty || FileManager.default.isExecutableFile(atPath: (value as NSString).expandingTildeInPath) else { return "freecadPath must be empty (auto-detect) or an executable freecadcmd" }
            freecadPath = value
        case "scope":
            guard let s = Scope(rawValue: value) else { return "scope must be folder or home" }
            scope = s
        case "scopeFolders":
            scopeFolders = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        default:
            return "unknown key `\(key)` (per-type keys look like stl.view, 3mf.enabled, step.label.textColor)"
        }
        return nil
    }

    static func isHex(_ spec: String) -> Bool {
        spec.count == 7 && spec.hasPrefix("#") && Int(spec.dropFirst(), radix: 16) != nil
    }

    /// Parses `system` or `#RRGGBB`.
    static func parseColor(_ spec: String) -> NSColor? {
        if spec == "system" { return .systemGray }
        guard isHex(spec), let v = Int(spec.dropFirst(), radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}
