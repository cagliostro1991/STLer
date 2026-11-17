import Foundation
import SceneKit
import simd

/// Reads 3MF packages (core spec, components, production-extension `p:path` references) into one flattened SceneKit node.
final class ThreeMFLoader {
    private struct Component { let id: Int; let path: String?; let tf: simd_double4x4 }
    private struct Obj { var type = "model"; var verts: [SIMD3<Double>] = []; var tris: [SIMD3<Int>] = []; var comps: [Component] = [] }
    private struct Item { let id: Int; let path: String?; let tf: simd_double4x4 }
    private struct Model { var objs: [Int: Obj] = [:]; var items: [Item] = [] }

    private static let skippedTypes: Set<String> = ["support", "solidsupport", "surface"]
    private let url: URL
    private let firstPlateOnly: Bool
    private var models: [String: Model] = [:]
    private var points: [SCNVector3] = []

    init(url: URL, firstPlateOnly: Bool = true) {
        self.url = url
        self.firstPlateOnly = firstPlateOnly
    }

    /// Returns a node with all printable objects in world space, or nil when the package has no readable mesh.
    func load() -> SCNNode? {
        guard let rootPath = rootModelPath(), let root = model(at: rootPath) else { return nil }
        let plate = firstPlateOnly ? firstPlateObjectIDs() : nil
        for item in root.items where plate?.contains(item.id) ?? true { emit(id: item.id, file: item.path ?? rootPath, tf: item.tf, depth: 0) }
        guard !points.isEmpty else { return nil }
        var normals: [SCNVector3] = []
        for i in stride(from: 0, to: points.count, by: 3) {
            let a = points[i], b = points[i + 1], c = points[i + 2]
            let u = SIMD3(b.x - a.x, b.y - a.y, b.z - a.z), v = SIMD3(c.x - a.x, c.y - a.y, c.z - a.z)
            let n = simd_normalize(simd_cross(SIMD3<Double>(Double(u.x), Double(u.y), Double(u.z)), SIMD3<Double>(Double(v.x), Double(v.y), Double(v.z))))
            let sn = SCNVector3(CGFloat(n.x), CGFloat(n.y), CGFloat(n.z))
            normals += [sn, sn, sn]
        }
        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: points), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: (0..<Int32(points.count)).map { $0 }, primitiveType: .triangles)])
        return SCNNode(geometry: geo)
    }

    private func emit(id: Int, file: String, tf: simd_double4x4, depth: Int) {
        guard depth < 16, let obj = model(at: file)?.objs[id], !Self.skippedTypes.contains(obj.type) else { return }
        for t in obj.tris where t.max() < obj.verts.count && t.min() >= 0 {
            for k in 0..<3 {
                let p = simd_mul(SIMD4(obj.verts[t[k]], 1), tf)
                points.append(SCNVector3(CGFloat(p.x), CGFloat(p.y), CGFloat(p.z)))
            }
        }
        for c in obj.comps { emit(id: c.id, file: c.path ?? file, tf: simd_mul(c.tf, tf), depth: depth + 1) }
    }

    private func model(at path: String) -> Model? {
        let key = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if let m = models[key] { return m }
        guard let data = archive(["-xOf", url.path, key]) else { return nil }
        let parser = ModelParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return nil }
        let m = Model(objs: parser.objs, items: parser.items)
        models[key] = m
        return m
    }

    /// Object ids on the first plate of a Bambu/Orca project, or nil for single-plate packages.
    private func firstPlateObjectIDs() -> Set<Int>? {
        guard let data = archive(["-xOf", url.path, "Metadata/model_settings.config"]) else { return nil }
        let parser = PlateParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.ids.isEmpty ? nil : parser.ids
    }

    private func rootModelPath() -> String? {
        guard let list = archive(["-tf", url.path]), let names = String(data: list, encoding: .utf8)?.split(separator: "\n").map(String.init) else { return nil }
        return names.first { $0.caseInsensitiveCompare("3D/3dmodel.model") == .orderedSame } ?? names.first { $0.lowercased().hasSuffix(".model") }
    }

    private func archive(_ args: [String]) -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? data : nil
    }

    private final class PlateParser: NSObject, XMLParserDelegate {
        var ids: Set<Int> = []
        private var inPlate = false
        private var done = false

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
            if name == "plate", !done { inPlate = true }
            else if inPlate, name == "metadata", a["key"] == "object_id", let id = a["value"].flatMap(Int.init) { ids.insert(id) }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if name == "plate", inPlate { inPlate = false; done = true }
        }
    }

    private final class ModelParser: NSObject, XMLParserDelegate {
        var objs: [Int: Obj] = [:]
        var items: [Item] = []
        private var cur: Int?

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
            switch name.split(separator: ":").last.map(String.init) ?? name {
            case "object":
                guard let id = a["id"].flatMap(Int.init) else { return }
                cur = id
                objs[id] = Obj(type: a["type"] ?? "model")
            case "vertex":
                if let c = cur, let x = a["x"].flatMap(Double.init), let y = a["y"].flatMap(Double.init), let z = a["z"].flatMap(Double.init) { objs[c]?.verts.append(SIMD3(x, y, z)) }
            case "triangle":
                if let c = cur, let v1 = a["v1"].flatMap(Int.init), let v2 = a["v2"].flatMap(Int.init), let v3 = a["v3"].flatMap(Int.init) { objs[c]?.tris.append(SIMD3(v1, v2, v3)) }
            case "component":
                if let c = cur, let id = a["objectid"].flatMap(Int.init) { objs[c]?.comps.append(Component(id: id, path: a["p:path"] ?? a["path"], tf: Self.matrix(a["transform"]))) }
            case "item":
                if let id = a["objectid"].flatMap(Int.init) { items.append(Item(id: id, path: a["p:path"] ?? a["path"], tf: Self.matrix(a["transform"]))) }
            default: break
            }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if (name.split(separator: ":").last.map(String.init) ?? name) == "object" { cur = nil }
        }

        /// 3MF stores 12 numbers as the first four rows of a row-vector 4x4 matrix.
        static func matrix(_ s: String?) -> simd_double4x4 {
            let m = (s ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            guard m.count == 12 else { return matrix_identity_double4x4 }
            return simd_double4x4(rows: [[m[0], m[1], m[2], 0], [m[3], m[4], m[5], 0], [m[6], m[7], m[8], 0], [m[9], m[10], m[11], 1]])
        }
    }
}
