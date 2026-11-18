import Foundation
import SceneKit
import simd

/// Reads a 3MF package into one flattened SceneKit node in world space.
///
/// Supports the core spec, `components` with transforms and the production extension's `p:path` references
/// (Bambu Studio, Orca, Prusa, Fusion). Archive access goes through `/usr/bin/bsdtar`, which handles UTF-8 names.
final class ThreeMFLoader {
    private struct Component { let id: Int; let path: String?; let transform: simd_double4x4 }
    /// `material` is the (property group id, index) of the object itself; `triangleMaterials` is parallel to `triangles`, `nil` entries inherit.
    private struct Object {
        var type = "model"; var vertices: [SIMD3<Double>] = []; var triangles: [SIMD3<Int>] = [];
        var components: [Component] = []
        var material: SIMD2<Int>?; var triangleMaterials: [SIMD2<Int>?] = []
    }
    private struct Item { let id: Int; let path: String?; let transform: simd_double4x4 }
    private struct Model {
        var objects: [Int: Object] = [:]; var items: [Item] = [];
        var colorGroups: [Int: [SIMD3<Float>]] = [:]
    }

    private static let skippedTypes: Set<String> = ["support", "solidsupport", "surface"]
    private static let maxComponentDepth = 16

    private let url: URL
    private let plates: Int
    private var models: [String: Model] = [:]

    /// The parsed models of the last file, so changing a setting in the window does not parse a multi-megabyte package again.
    private static var cache: (key: String, models: [String: Model])?
    private static let cacheLock = NSLock()

    private var cacheKey: String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return
            "\(url.path)|\((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)|\(attributes?[.size] as? Int ?? 0)"
    }
    private var points: [SCNVector3] = []
    private var colors: [SIMD3<Float>] = []
    private let fill: SIMD3<Float>
    private let colorAmount: Float
    private var filamentColors: [SIMD3<Float>] = []
    private var objectExtruders: [Int: Int] = [:]

    /// - Parameters:
    ///   - plates: For Bambu/Orca projects with several plates, keep the objects of the first `plates` plates; 0 keeps all.
    ///   - fill: Colour (RGB, 0...1) for parts without a colour of their own.
    ///   - colorAmount: 0...1, how much of the colours stored in the file replaces `fill`. 0 skips reading them.
    init(
        url: URL, plates: Int = 1, fill: SIMD3<Float> = SIMD3(repeating: 0.6),
        colorAmount: Float = 0
    ) {
        self.url = url
        self.plates = plates
        self.fill = fill
        self.colorAmount = colorAmount
        Self.cacheLock.lock()
        if let cached = Self.cache, cached.key == cacheKey { models = cached.models }
        Self.cacheLock.unlock()
    }

    /// - Returns: A node with all printable objects, or `nil` when the package has no readable mesh.
    func load() -> SCNNode? {
        guard let rootPath = rootModelPath(), let root = model(at: rootPath) else { return nil }
        let plate = plates > 0 ? plateObjectIDs() : nil
        if colorAmount > 0 { loadBambuColors() }
        for item in root.items where plate?.contains(item.id) ?? true {
            emit(
                id: item.id, file: item.path ?? rootPath, transform: item.transform, depth: 0,
                inherited: extruderColor(of: item.id))
        }
        Self.cacheLock.lock()
        Self.cache = (cacheKey, models)
        Self.cacheLock.unlock()
        guard !points.isEmpty else { return nil }
        return SCNNode(
            geometry: FlatGeometry.make(
                points: points,
                colors: colorAmount > 0 && colors.count == points.count ? colors : nil))
    }

    private func emit(
        id: Int, file: String, transform: simd_double4x4, depth: Int, inherited: SIMD3<Float>?
    ) {
        guard depth < Self.maxComponentDepth, let model = model(at: file),
            let object = model.objects[id], !Self.skippedTypes.contains(object.type)
        else { return }
        let base = object.material.flatMap { color(model, $0) } ?? inherited
        for (index, triangle) in object.triangles.enumerated()
        where triangle.min() >= 0 && triangle.max() < object.vertices.count {
            let own =
                index < object.triangleMaterials.count
                ? object.triangleMaterials[index].flatMap { color(model, $0) } : nil
            let shade = colorAmount > 0 ? fill + ((own ?? base ?? fill) - fill) * colorAmount : fill
            for corner in 0..<3 {
                let p = simd_mul(SIMD4(object.vertices[triangle[corner]], 1), transform)
                points.append(SCNVector3(CGFloat(p.x), CGFloat(p.y), CGFloat(p.z)))
                if colorAmount > 0 { colors.append(shade) }
            }
        }
        for component in object.components {
            emit(
                id: component.id, file: component.path ?? file,
                transform: simd_mul(component.transform, transform), depth: depth + 1,
                inherited: base)
        }
    }

    private func color(_ model: Model, _ material: SIMD2<Int>) -> SIMD3<Float>? {
        guard let group = model.colorGroups[material.x], group.indices.contains(material.y) else {
            return nil
        }
        return group[material.y]
    }

    /// Bambu/Orca: filament colours in `project_settings.config`, the filament of each object in `model_settings.config`.
    private func loadBambuColors() {
        if let data = archive(["-xOf", url.path, "Metadata/project_settings.config"]),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["filament_colour"] as? [String]
        {
            filamentColors = list.map { Self.parseHex($0) ?? SIMD3(repeating: 0.6) }
        }
        if !filamentColors.isEmpty,
            let data = archive(["-xOf", url.path, "Metadata/model_settings.config"])
        {
            let parser = ExtruderParser()
            let xml = XMLParser(data: data)
            xml.delegate = parser
            xml.parse()
            objectExtruders = parser.extruders
        }
    }

    private func extruderColor(of object: Int) -> SIMD3<Float>? {
        guard let extruder = objectExtruders[object], filamentColors.indices.contains(extruder - 1)
        else { return nil }
        return filamentColors[extruder - 1]
    }

    /// `#RRGGBB` or `#RRGGBBAA` (alpha ignored).
    private static func parseHex(_ text: String) -> SIMD3<Float>? {
        let hex = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard hex.count == 6 || hex.count == 8, let value = UInt32(hex.prefix(6), radix: 16) else {
            return nil
        }
        return SIMD3(Float((value >> 16) & 255), Float((value >> 8) & 255), Float(value & 255))
            / 255
    }

    private func model(at path: String) -> Model? {
        let key = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if let cached = models[key] { return cached }
        guard let data = archive(["-xOf", url.path, key]) else { return nil }
        let parser = ModelParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return nil }
        let model = Model(
            objects: parser.objects, items: parser.items, colorGroups: parser.colorGroups)
        models[key] = model
        return model
    }

    /// Bambu/Orca list the objects of each plate in `Metadata/model_settings.config`.
    /// - Returns: Object ids on the first `plates` plates, or `nil` for packages without plate metadata.
    private func plateObjectIDs() -> Set<Int>? {
        guard let data = archive(["-xOf", url.path, "Metadata/model_settings.config"]) else {
            return nil
        }
        let parser = PlateParser(limit: plates)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.ids.isEmpty ? nil : parser.ids
    }

    private func rootModelPath() -> String? {
        guard let listing = archive(["-tf", url.path]),
            let text = String(data: listing, encoding: .utf8)
        else { return nil }
        let names = text.split(separator: "\n").map(String.init)
        return names.first { $0.caseInsensitiveCompare("3D/3dmodel.model") == .orderedSame }
            ?? names.first { $0.lowercased().hasSuffix(".model") }
    }

    private func archive(_ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    /// Collects the `object_id`s of the first `limit` `<plate>`s in `model_settings.config`.
    private final class PlateParser: NSObject, XMLParserDelegate {
        var ids: Set<Int> = []
        private let limit: Int
        private var seen = 0
        private var inPlate = false

        init(limit: Int) { self.limit = limit }

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            if name == "plate" {
                seen += 1
                inPlate = seen <= limit
            } else if inPlate, name == "metadata", attributes["key"] == "object_id",
                let id = attributes["value"].flatMap(Int.init)
            {
                ids.insert(id)
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            if name == "plate" { inPlate = false }
        }
    }

    /// Collects the filament (`extruder`, 1-based) of each `<object>` in `model_settings.config`; the ones set on parts are ignored.
    private final class ExtruderParser: NSObject, XMLParserDelegate {
        var extruders: [Int: Int] = [:]
        private var object: Int?
        private var depth = 0

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes a: [String: String]
        ) {
            if name == "object" {
                object = a["id"].flatMap(Int.init)
                depth = 0
            } else if object != nil, name == "part" {
                depth += 1
            } else if let object, depth == 0, name == "metadata", a["key"] == "extruder",
                let value = a["value"].flatMap(Int.init)
            {
                extruders[object] = value
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            if name == "part" { depth -= 1 } else if name == "object" { object = nil }
        }
    }

    /// Collects objects (meshes and component lists) and build items from one `.model` file; namespace prefixes are ignored.
    private final class ModelParser: NSObject, XMLParserDelegate {
        var objects: [Int: Object] = [:]
        var items: [Item] = []
        var colorGroups: [Int: [SIMD3<Float>]] = [:]
        private var current: Int?
        private var group: Int?

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes a: [String: String]
        ) {
            switch name.split(separator: ":").last.map(String.init) ?? name {
            case "object":
                guard let id = a["id"].flatMap(Int.init) else { return }
                current = id
                objects[id] = Object(type: a["type"] ?? "model")
                if let pid = a["pid"].flatMap(Int.init) {
                    objects[id]?.material = SIMD2(pid, a["pindex"].flatMap(Int.init) ?? 0)
                }
            case "basematerials", "colorgroup":
                group = a["id"].flatMap(Int.init)
                if let group { colorGroups[group] = [] }
            case "base", "color":
                if let group,
                    let color = (a["displaycolor"] ?? a["color"]).flatMap(ThreeMFLoader.parseHex)
                {
                    colorGroups[group]?.append(color)
                }
            case "vertex":
                if let id = current, let x = a["x"].flatMap(Double.init),
                    let y = a["y"].flatMap(Double.init), let z = a["z"].flatMap(Double.init)
                {
                    objects[id]?.vertices.append(SIMD3(x, y, z))
                }
            case "triangle":
                if let id = current, let v1 = a["v1"].flatMap(Int.init),
                    let v2 = a["v2"].flatMap(Int.init), let v3 = a["v3"].flatMap(Int.init)
                {
                    objects[id]?.triangles.append(SIMD3(v1, v2, v3))
                    objects[id]?.triangleMaterials.append(
                        a["pid"].flatMap(Int.init).map { SIMD2($0, a["p1"].flatMap(Int.init) ?? 0) }
                    )
                }
            case "component":
                if let id = current, let target = a["objectid"].flatMap(Int.init) {
                    objects[id]?.components.append(
                        Component(
                            id: target, path: a["p:path"] ?? a["path"],
                            transform: Self.matrix(a["transform"])))
                }
            case "item":
                if let target = a["objectid"].flatMap(Int.init) {
                    items.append(
                        Item(
                            id: target, path: a["p:path"] ?? a["path"],
                            transform: Self.matrix(a["transform"])))
                }
            default:
                break
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch name.split(separator: ":").last.map(String.init) ?? name {
            case "object": current = nil
            case "basematerials", "colorgroup": group = nil
            default: break
            }
        }

        /// 3MF stores 12 numbers: the first four rows of a row-vector 4x4 matrix (`v' = v * M`).
        static func matrix(_ text: String?) -> simd_double4x4 {
            let m = (text ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap {
                Double($0)
            }
            guard m.count == 12 else { return matrix_identity_double4x4 }
            return simd_double4x4(rows: [
                [m[0], m[1], m[2], 0], [m[3], m[4], m[5], 0], [m[6], m[7], m[8], 0],
                [m[9], m[10], m[11], 1],
            ])
        }
    }
}
