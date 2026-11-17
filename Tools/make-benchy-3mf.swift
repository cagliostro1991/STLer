// Builds the 3MF preview sample from the bundled 3DBenchy.stl: coloured parts by height, three plates with 1, 2 and 3 boats.
// Run: swiftc -O Tools/make-benchy-3mf.swift -o /tmp/make-benchy-3mf && /tmp/make-benchy-3mf Sources/STLerApp/Resources
import Foundation

let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: resources.appendingPathComponent("3DBenchy.stl"))
let count = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 80, as: UInt32.self) })

// Plate 1 has one boat painted by height (hull, cabin, roof, chimney), plate 2 two boats painted by length, plate 3 three boats painted by width.
let palettes = [
    ["#2b5fb4", "#f2f2f2", "#c0392b", "#3a3a3a"],
    ["#e74c3c", "#f39c12", "#f1c40f", "#2ecc71"],
    ["#8e44ad", "#16a085", "#ecf0f1"],
]
func band(_ axis: Int, _ centroid: SIMD3<Float>) -> Int {
    switch axis {
    case 0: let z = centroid.z; return z < 17 ? 0 : z < 33 ? 1 : z < 36 ? 2 : 3
    case 1: return min(3, max(0, Int((centroid.x + 29.2) / 60 * 4)))
    default: return min(2, max(0, Int((centroid.y + 15.5) / 31 * 3)))
    }
}

var index: [SIMD3<Int32>: Int] = [:]
var vertices: [SIMD3<Float>] = []
var corners: [(Int, Int, Int, SIMD3<Float>)] = []
data.withUnsafeBytes { raw in
    for t in 0..<count {
        let base = 84 + t * 50 + 12
        var ids: [Int] = []
        var centroid = SIMD3<Float>(repeating: 0)
        for v in 0..<3 {
            let p = SIMD3<Float>(raw.loadUnaligned(fromByteOffset: base + v * 12, as: Float.self), raw.loadUnaligned(fromByteOffset: base + v * 12 + 4, as: Float.self), raw.loadUnaligned(fromByteOffset: base + v * 12 + 8, as: Float.self))
            let key = SIMD3<Int32>(Int32((p.x * 1000).rounded()), Int32((p.y * 1000).rounded()), Int32((p.z * 1000).rounded()))
            if index[key] == nil { index[key] = vertices.count; vertices.append(p) }
            ids.append(index[key]!)
            centroid += p / 3
        }
        corners.append((ids[0], ids[1], ids[2], centroid))
    }
}

var xml = """
<?xml version="1.0" encoding="UTF-8"?>
<model unit="millimeter" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"><resources>

"""
for (axis, palette) in palettes.enumerated() {
    xml += "<basematerials id=\"\(axis + 1)\">\(palette.map { "<base name=\"c\" displaycolor=\"\($0)\"/>" }.joined())</basematerials>\n"
}
let vertexXML = "<vertices>" + vertices.map { "<vertex x=\"\($0.x)\" y=\"\($0.y)\" z=\"\($0.z)\"/>" }.joined() + "</vertices>"
for axis in 0..<palettes.count {
    xml += "<object id=\"\(axis + 1)\" type=\"model\" pid=\"\(axis + 1)\" pindex=\"0\"><mesh>\(vertexXML)<triangles>"
    for t in corners { xml += "<triangle v1=\"\(t.0)\" v2=\"\(t.1)\" v3=\"\(t.2)\" pid=\"\(axis + 1)\" p1=\"\(band(axis, t.3))\"/>" }
    xml += "</triangles></mesh></object>\n"
}
// Plate k holds k boats, all painted like object k, in a row of its own.
var items: [String] = []
for plate in 1...3 {
    for boat in 0..<plate {
        let (x, y) = (Double(boat) * 70 - Double(plate - 1) * 35, Double(plate - 1) * 40)
        items.append("<item objectid=\"\(plate)\" transform=\"1 0 0 0 1 0 0 0 1 \(x) \(y) 0\"/>")
    }
}
xml += "</resources><build>" + items.joined() + "</build></model>"

let work = FileManager.default.temporaryDirectory.appendingPathComponent("benchy-3mf-\(UUID().uuidString)")
func write(_ text: String, _ path: String) throws {
    let url = work.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
}
try write(xml, "3D/3dmodel.model")
try write("""
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>
""", "[Content_Types].xml")
try write("""
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>
""", "_rels/.rels")
try write("""
<config>\((1...3).map { "<plate><metadata key=\"plater_id\" value=\"\($0)\"/><model_instance><metadata key=\"object_id\" value=\"\($0)\"/></model_instance></plate>" }.joined())</config>
""", "Metadata/model_settings.config")

let output = resources.appendingPathComponent("3DBenchy.3mf")
try? FileManager.default.removeItem(at: output)
let zip = Process()
zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
zip.currentDirectoryURL = work
zip.arguments = ["-qr9", output.path, "[Content_Types].xml", "_rels", "3D", "Metadata"]
try zip.run()
zip.waitUntilExit()
try? FileManager.default.removeItem(at: work)
print("wrote", output.path)
