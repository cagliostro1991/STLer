import Foundation
import SceneKit
import simd

/// Reads a 3MF package into one flattened SceneKit node in world space.
///
/// Supports the core spec, `components` with transforms and the production extension's `p:path` references
/// (Bambu Studio, Orca, Prusa, Fusion). Archive access goes through `/usr/bin/bsdtar`, which handles UTF-8 names.
final class ThreeMFLoader {
    private struct Component { let id: Int; let path: String?; let transform: simd_double4x4 }
    private struct Object { var type = "model"; var vertices: [SIMD3<Double>] = []; var triangles: [SIMD3<Int>] = []; var components: [Component] = [] }
    private struct Item { let id: Int; let path: String?; let transform: simd_double4x4 }
    private struct Model { var objects: [Int: Object] = [:]; var items: [Item] = [] }

    private static let skippedTypes: Set<String> = ["support", "solidsupport", "surface"]
    private static let maxComponentDepth = 16

    private let url: URL
    private let firstPlateOnly: Bool
    private var models: [String: Model] = [:]
    private var points: [SCNVector3] = []

    /// - Parameter firstPlateOnly: For Bambu/Orca projects with several plates, keep only the first plate's objects.
    init(url: URL, firstPlateOnly: Bool = true) {
        self.url = url
        self.firstPlateOnly = firstPlateOnly
    }

    /// - Returns: A node with all printable objects, or `nil` when the package has no readable mesh.
    func load() -> SCNNode? {
        guard let rootPath = rootModelPath(), let root = model(at: rootPath) else { return nil }
        let plate = firstPlateOnly ? firstPlateObjectIDs() : nil
        for item in root.items where plate?.contains(item.id) ?? true {
            emit(id: item.id, file: item.path ?? rootPath, transform: item.transform, depth: 0)
        }
        guard !points.isEmpty else { return nil }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: points), SCNGeometrySource(normals: flatNormals())],
            elements: [SCNGeometryElement(indices: (0..<Int32(points.count)).map { $0 }, primitiveType: .triangles)])
        return SCNNode(geometry: geometry)
    }

    /// One normal per triangle corner, so the model renders faceted like a slicer preview.
    private func flatNormals() -> [SCNVector3] {
        func vector(_ p: SCNVector3) -> SIMD3<Double> { SIMD3(Double(p.x), Double(p.y), Double(p.z)) }
        var normals: [SCNVector3] = []
        for i in stride(from: 0, to: points.count, by: 3) {
            let a = vector(points[i])
            let n = simd_normalize(simd_cross(vector(points[i + 1]) - a, vector(points[i + 2]) - a))
            let normal = SCNVector3(CGFloat(n.x), CGFloat(n.y), CGFloat(n.z))
            normals += [normal, normal, normal]
        }
        return normals
    }

    private func emit(id: Int, file: String, transform: simd_double4x4, depth: Int) {
        guard depth < Self.maxComponentDepth, let object = model(at: file)?.objects[id], !Self.skippedTypes.contains(object.type) else { return }
        for triangle in object.triangles where triangle.min() >= 0 && triangle.max() < object.vertices.count {
            for corner in 0..<3 {
                let p = simd_mul(SIMD4(object.vertices[triangle[corner]], 1), transform)
                points.append(SCNVector3(CGFloat(p.x), CGFloat(p.y), CGFloat(p.z)))
            }
        }
        for component in object.components {
            emit(id: component.id, file: component.path ?? file, transform: simd_mul(component.transform, transform), depth: depth + 1)
        }
    }

    private func model(at path: String) -> Model? {
        let key = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if let cached = models[key] { return cached }
        guard let data = archive(["-xOf", url.path, key]) else { return nil }
        let parser = ModelParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return nil }
        let model = Model(objects: parser.objects, items: parser.items)
        models[key] = model
        return model
    }

    /// Bambu/Orca list the objects of each plate in `Metadata/model_settings.config`.
    /// - Returns: Object ids on the first plate, or `nil` for packages without plate metadata.
    private func firstPlateObjectIDs() -> Set<Int>? {
        guard let data = archive(["-xOf", url.path, "Metadata/model_settings.config"]) else { return nil }
        let parser = PlateParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.ids.isEmpty ? nil : parser.ids
    }

    private func rootModelPath() -> String? {
        guard let listing = archive(["-tf", url.path]), let text = String(data: listing, encoding: .utf8) else { return nil }
        let names = text.split(separator: "\n").map(String.init)
        return names.first { $0.caseInsensitiveCompare("3D/3dmodel.model") == .orderedSame } ?? names.first { $0.lowercased().hasSuffix(".model") }
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

    /// Collects the `object_id`s of the first `<plate>` in `model_settings.config`.
    private final class PlateParser: NSObject, XMLParserDelegate {
        var ids: Set<Int> = []
        private var inPlate = false
        private var done = false

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            if name == "plate", !done {
                inPlate = true
            } else if inPlate, name == "metadata", attributes["key"] == "object_id", let id = attributes["value"].flatMap(Int.init) {
                ids.insert(id)
            }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if name == "plate", inPlate { inPlate = false; done = true }
        }
    }

    /// Collects objects (meshes and component lists) and build items from one `.model` file; namespace prefixes are ignored.
    private final class ModelParser: NSObject, XMLParserDelegate {
        var objects: [Int: Object] = [:]
        var items: [Item] = []
        private var current: Int?

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
            switch name.split(separator: ":").last.map(String.init) ?? name {
            case "object":
                guard let id = a["id"].flatMap(Int.init) else { return }
                current = id
                objects[id] = Object(type: a["type"] ?? "model")
            case "vertex":
                if let id = current, let x = a["x"].flatMap(Double.init), let y = a["y"].flatMap(Double.init), let z = a["z"].flatMap(Double.init) {
                    objects[id]?.vertices.append(SIMD3(x, y, z))
                }
            case "triangle":
                if let id = current, let v1 = a["v1"].flatMap(Int.init), let v2 = a["v2"].flatMap(Int.init), let v3 = a["v3"].flatMap(Int.init) {
                    objects[id]?.triangles.append(SIMD3(v1, v2, v3))
                }
            case "component":
                if let id = current, let target = a["objectid"].flatMap(Int.init) {
                    objects[id]?.components.append(Component(id: target, path: a["p:path"] ?? a["path"], transform: Self.matrix(a["transform"])))
                }
            case "item":
                if let target = a["objectid"].flatMap(Int.init) {
                    items.append(Item(id: target, path: a["p:path"] ?? a["path"], transform: Self.matrix(a["transform"])))
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if (name.split(separator: ":").last.map(String.init) ?? name) == "object" { current = nil }
        }

        /// 3MF stores 12 numbers: the first four rows of a row-vector 4x4 matrix (`v' = v * M`).
        static func matrix(_ text: String?) -> simd_double4x4 {
            let m = (text ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            guard m.count == 12 else { return matrix_identity_double4x4 }
            return simd_double4x4(rows: [[m[0], m[1], m[2], 0], [m[3], m[4], m[5], 0], [m[6], m[7], m[8], 0], [m[9], m[10], m[11], 1]])
        }
    }
}
