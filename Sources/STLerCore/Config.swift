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
    /// How much of the model to show; 0 means all. 3MF: plates (Bambu/Orca projects). STEP: parts of an assembly, in file order.
    var limit = 0
    /// 0...100: how much of the colours stored in the model file replaces the fill `color`. 3MF only for now.
    var modelColors = 0

    init(enabled: Bool = true, color: String = "system", limit: Int = 0) {
        self.enabled = enabled
        self.color = color
        self.limit = limit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        enabled = read(.enabled, enabled)
        view = read(.view, view)
        projection = read(.projection, projection)
        color = read(.color, color)
        label = read(.label, label)
        limit = max(read(.limit, limit), 0)
        modelColors = min(max(read(.modelColors, modelColors), 0), 100)
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
        case "modelColors":
            guard let percent = Int(value), (0...100).contains(percent) else { return "modelColors must be a number from 0 to 100" }
            modelColors = percent
        case "limit":
            guard value == "all" || (Int(value) ?? -1) >= 1 else { return "limit must be 1, 2, 3... or `all` (3MF: plates, STEP: parts)" }
            limit = Int(value) ?? 0
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
    var threeMF = TypeStyle(color: FileType.threeMF.defaultColor, limit: 1)
    var step = TypeStyle(enabled: false, color: FileType.step.defaultColor)
    /// Folder levels processed by `follow`; 0 means unlimited.
    var followDepth = 3
    /// STEP converter. STEP stays off while the chosen one is missing.
    var stepEngine = StepEngine.freecad
    /// `freecadcmd` location for the FreeCAD engine; empty means the usual install locations.
    var freecadPath = ""
    /// `follow` also renders a file the moment it is opened anywhere (any folder, indexed drives), not only the open Finder folder.
    var followOpened = false
    /// With `followOpened`: the other models in the opened file's own folder (no subfolders, at most `FileScanner.siblingLimit`).
    var followOpenedFolder = false
    /// Where the app's Clear and Apply buttons work: the listed folders, or the whole home folder.
    var scope = Scope.folder
    var scopeFolders: [String] = []

    enum Scope: String, Codable { case folder, home }

    private enum CodingKeys: String, CodingKey {
        case stl, threeMF = "3mf", step, followDepth, followOpened, followOpenedFolder, stepEngine, freecadPath, scope, scopeFolders
    }

    private enum LegacyKeys: String, CodingKey { case view, color, formats, badge, scopeFolder, firstPlateOnly }

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

    /// Formats to scan for, as `FileScanner` expects them. STEP counts only while its engine is available.
    var enabledFormats: [String] {
        FileType.allCases.filter { self[$0].enabled && ($0 != .step || StepConverter.isReady(self)) }.map(\.rawValue)
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
        followDepth = read(.followDepth, followDepth)
        followOpened = read(.followOpened, followOpened)
        followOpenedFolder = read(.followOpenedFolder, followOpenedFolder)
        stepEngine = read(.stepEngine, stepEngine)
        freecadPath = read(.freecadPath, freecadPath)
        if let firstPlateOnly = (try? decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(Bool.self, forKey: .firstPlateOnly)) ?? nil {
            threeMF.limit = firstPlateOnly ? 1 : 0
        }
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
            if type == .step, parts[1] == "enabled", Bool(value) == true, !StepConverter.isReady(self) {
                return "STEP needs its engine (\(stepEngine.title)): install it first, or switch stepEngine"
            }
            return self[type].set(parts[1], value)
        }
        switch key {
        case "followDepth":
            guard value == "deep" || (Int(value) ?? 0) >= 1 else { return "followDepth must be 1, 2, 3... or `deep` (unlimited)" }
            followDepth = Int(value) ?? 0
        case "followOpened":
            guard let b = Bool(value) else { return "followOpened must be true or false" }
            followOpened = b
        case "followOpenedFolder":
            guard let b = Bool(value) else { return "followOpenedFolder must be true or false" }
            followOpenedFolder = b
        case "stepEngine":
            guard let engine = StepEngine(rawValue: value) else { return "stepEngine must be freecad or opencascade" }
            stepEngine = engine
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
