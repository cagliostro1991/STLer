import AppKit
import SceneKit

var failures = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() { print("ok   \(message)") } else { print("FAIL \(message)"); failures += 1 }
}

func close(_ a: CGFloat, _ b: Double) -> Bool { abs(Double(a) - b) < 1e-6 }

let fm = FileManager.default
let tmp = fm.temporaryDirectory.appendingPathComponent("stler-tests-\(UUID().uuidString)")
try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

func touch(_ path: String, _ content: String = "x") throws {
    try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try content.write(toFile: path, atomically: true, encoding: .utf8)
}

// MARK: config

var c = Config()
check(c.set("view", "bogus") != nil, "config rejects unknown view")
check(c.set("view", "top") == nil && c.view == .top, "config accepts a view")
check(c.set("color", "#12") != nil, "config rejects short colour")
check(c.set("color", "#AABBCC") == nil && c.color == "#aabbcc", "config lowercases colour")
check(c.set("formats", "stl,step") == nil && c.formats == ["stl", "step"], "config accepts format list")
check(c.set("formats", "obj") != nil, "config rejects unsupported format")
check(c.set("followDepth", "0") != nil, "config rejects depth 0")
check(c.set("followDepth", "deep") == nil && c.followDepth == 0, "config maps deep to 0")
check(c.set("badge", "middle") != nil, "config rejects unknown badge corner")
check(c.set("freecadPath", "/nonexistent") != nil, "config rejects missing freecadPath")
let partial = try JSONDecoder().decode(Config.self, from: Data(#"{"view":"top"}"#.utf8))
check(partial.view == .top && partial.followDepth == 3 && partial.badge == .bottomRight, "partial config falls back to defaults")
let invalid = try JSONDecoder().decode(Config.self, from: Data(#"{"view":"sideways","badge":"middle","followDepth":5}"#.utf8))
check(invalid.view == .iso && invalid.badge == .bottomRight && invalid.followDepth == 5, "invalid values fall back per key, valid ones are kept")
check(Config.parseColor("system") != nil && Config.parseColor("#zzzzzz") == nil && Config.parseColor("3d9a2c") == nil, "parseColor validates input")

// MARK: file scanning

let tree = tmp.appendingPathComponent("tree").path
for f in ["a.stl", "sub/b.stl", "sub/deep/c.stl", "sub/deep/d.txt", ".hidden/e.stl", "s.STP"] { try touch("\(tree)/\(f)") }
let names: ([String]) -> [String] = { $0.map { ($0 as NSString).lastPathComponent }.sorted() }
check(names(FileScanner.collect([tree], formats: ["stl"], maxDepth: 1)) == ["a.stl"], "depth 1 = open folder only")
check(names(FileScanner.collect([tree], formats: ["stl"], maxDepth: 2)) == ["a.stl", "b.stl"], "depth 2 adds one level")
check(names(FileScanner.collect([tree], formats: ["stl"])) == ["a.stl", "b.stl", "c.stl"], "unlimited depth skips hidden folders and other extensions")
check(names(FileScanner.collect([tree], formats: ["step"])) == ["s.STP"], "step format also matches .stp in any case")
let ordered = FileScanner.ordered(["\(tree)/sub/deep/c.stl", "\(tree)/sub/b.stl", "\(tree)/a.stl"], under: tree)
check(ordered.map { ($0 as NSString).lastPathComponent } == ["a.stl", "b.stl", "c.stl"], "ordered puts the top level first")
check(FileScanner.scan([tree, "\(tree)/sub"], formats: ["stl"]).count == 3, "scan removes duplicates across overlapping paths")

// MARK: view and signature

check(ViewAngle.iso.cameraUp.z == 1 && ViewAngle.front.cameraUp.z == 1, "iso and side views keep Z up (iso used to roll the model)")
check(ViewAngle.top.cameraUp.y == 1 && ViewAngle.bottom.cameraUp.y == 1, "top and bottom views use Y up")
var sigConfig = Config()
let baseSignature = Signature.make(for: sigConfig)
sigConfig.badge = .off
check(Signature.make(for: sigConfig) != baseSignature, "signature changes with settings that change the icon")
sigConfig = Config()
sigConfig.followDepth = 1
check(Signature.make(for: sigConfig) == baseSignature, "signature ignores settings that do not change the icon")

let sigFile = tmp.appendingPathComponent("sig.stl").path
try touch(sigFile)
check(Signature.read(sigFile) == nil, "no signature on a fresh file")
Signature.write(sigFile, "v2|iso")
check(Signature.read(sigFile) == "v2|iso", "signature round-trips")
Signature.remove(sigFile)
check(Signature.read(sigFile) == nil, "signature can be removed")

// MARK: 3MF

func write3MF(_ name: String, plates: Bool) throws -> URL {
    let dir = tmp.appendingPathComponent(name)
    try touch("\(dir.path)/3D/3dmodel.model", """
    <?xml version="1.0" encoding="UTF-8"?>
    <model unit="millimeter" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"><resources>
    <object id="1" type="model"><mesh><vertices>
    <vertex x="0" y="0" z="0"/><vertex x="1" y="0" z="0"/><vertex x="0" y="1" z="0"/><vertex x="0" y="0" z="1"/>
    </vertices><triangles>
    <triangle v1="0" v2="2" v3="1"/><triangle v1="0" v2="1" v3="3"/><triangle v1="1" v2="2" v3="3"/><triangle v1="2" v2="0" v3="3"/>
    </triangles></mesh></object>
    <object id="2" type="model"><components><component objectid="1" transform="1 0 0 0 1 0 0 0 1 10 0 0"/></components></object>
    <object id="3" type="model"><components><component objectid="1"/></components></object>
    </resources><build><item objectid="2" transform="1 0 0 0 1 0 0 0 1 0 5 0"/><item objectid="3"/></build></model>
    """)
    if plates {
        try touch("\(dir.path)/Metadata/model_settings.config", """
        <config><plate><metadata key="plater_id" value="1"/><model_instance><metadata key="object_id" value="2"/></model_instance></plate>
        <plate><metadata key="plater_id" value="2"/><model_instance><metadata key="object_id" value="3"/></model_instance></plate></config>
        """)
    }
    let out = tmp.appendingPathComponent("\(name).3mf")
    let zip = Process()
    zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.currentDirectoryURL = dir
    zip.arguments = ["-qr", out.path, "."]
    try zip.run()
    zip.waitUntilExit()
    return out
}

let vertexCount: (SCNNode?) -> Int = { $0?.geometry?.sources(for: .vertex).first?.vectorCount ?? -1 }
let plated = try write3MF("plated", plates: true)
let node = ThreeMFLoader(url: plated).load()
check(vertexCount(node) == 12, "first plate only keeps one object (4 triangles)")
if let node {
    let (lo, hi) = node.boundingBox
    check(close(lo.x, 10) && close(hi.x, 11) && close(lo.y, 5) && close(hi.y, 6) && close(lo.z, 0) && close(hi.z, 1), "component and item transforms compose (x+10, y+5)")
}
check(vertexCount(ThreeMFLoader(url: plated, firstPlateOnly: false).load()) == 24, "all plates when firstPlateOnly is off")
let single = try write3MF("single", plates: false)
check(vertexCount(ThreeMFLoader(url: single).load()) == 24, "no plate metadata means every build item")

// MARK: end to end

let stl = tmp.appendingPathComponent("tetra.stl").path
try touch(stl, """
solid t
facet normal 0 0 0
outer loop
vertex 0 0 0
vertex 10 0 0
vertex 0 10 0
endloop
endfacet
facet normal 0 0 0
outer loop
vertex 0 0 0
vertex 0 10 0
vertex 0 0 10
endloop
endfacet
facet normal 0 0 0
outer loop
vertex 0 0 0
vertex 0 0 10
vertex 10 0 0
endloop
endfacet
facet normal 0 0 0
outer loop
vertex 10 0 0
vertex 0 0 10
vertex 0 10 0
endloop
endfacet
endsolid t
""")
let old = Date(timeIntervalSince1970: 1_577_836_800)
try fm.setAttributes([.modificationDate: old], ofItemAtPath: stl)
let mtime: () -> Date? = { (try? fm.attributesOfItem(atPath: stl))?[.modificationDate] as? Date }
var cfg = Config()
check(IconBatch.apply([stl], config: cfg).rendered == 1, "renders a new file")
check(mtime() == old, "setting an icon keeps the file's modification date")
check(Signature.read(stl) != nil, "rendered file carries a signature")
check(IconBatch.apply([stl], config: cfg).skipped == 1, "unchanged file is skipped")
cfg.badge = .off
check(IconBatch.apply([stl], config: cfg).rendered == 1, "changed settings re-render")
cfg.force = true
check(IconBatch.apply([stl], config: cfg).rendered == 1, "force re-renders")
check(IconBatch.reset([stl]).reset == 1 && Signature.read(stl) == nil, "reset removes our icon and signature")
check(mtime() == old, "reset keeps the file's modification date")
let foreign = tmp.appendingPathComponent("foreign.stl").path
try touch(foreign)
check(IconBatch.reset([foreign]).untouched == 1, "reset leaves files without our signature alone")

// MARK: orientation (compares rendered pictures)

typealias Box = (min: SIMD3<Double>, max: SIMD3<Double>)

/// Writes axis-aligned boxes as an ASCII STL with outward-facing triangles.
func writeBoxes(_ boxes: [Box], to path: String) throws {
    let quads = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    var text = "solid boxes\n"
    for (a, c) in boxes {
        let corners = [[a.x, a.y, a.z], [c.x, a.y, a.z], [c.x, c.y, a.z], [a.x, c.y, a.z], [a.x, a.y, c.z], [c.x, a.y, c.z], [c.x, c.y, c.z], [a.x, c.y, c.z]]
        for q in quads {
            for triangle in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]] {
                text += "facet normal 0 0 0\nouter loop\n"
                for i in triangle { text += "vertex \(corners[i][0]) \(corners[i][1]) \(corners[i][2])\n" }
                text += "endloop\nendfacet\n"
            }
        }
    }
    try (text + "endsolid boxes\n").write(toFile: path, atomically: true, encoding: .utf8)
}

/// Where the mass of a rendered silhouette sits: `dx` and `dyUp` are the centroid offset from the silhouette's
/// bounding-box centre as a fraction of its width/height (up and right are positive), `aspect` is height / width.
func silhouette(of image: NSImage) -> (aspect: Double, dx: Double, dyUp: Double)? {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    var (minX, maxX, minY, maxY) = (Int.max, -1, Int.max, -1)
    var (sumX, sumY, count) = (0.0, 0.0, 0.0)
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
            (minX, maxX, minY, maxY) = (min(minX, x), max(maxX, x), min(minY, y), max(maxY, y))
            sumX += Double(x); sumY += Double(y); count += 1
        }
    }
    guard count > 0 else { return nil }
    let (width, height) = (Double(maxX - minX + 1), Double(maxY - minY + 1))
    return (height / width, (sumX / count - Double(minX + maxX) / 2) / width, (Double(minY + maxY) / 2 - sumY / count) / height)
}

let dumpDirectory = ProcessInfo.processInfo.environment["STLER_TEST_OUT"]
func renderPicture(_ boxes: [Box], view: ViewAngle, name: String) throws -> NSImage? {
    let path = tmp.appendingPathComponent("\(name).stl").path
    try writeBoxes(boxes, to: path)
    var options = IconRenderer.Options()
    options.view = view
    let image = IconRenderer.render(URL(fileURLWithPath: path), size: CGSize(width: 256, height: 256), options: options)
    if let dumpDirectory, let tiff = image?.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
        try fm.createDirectory(atPath: dumpDirectory, withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: "\(dumpDirectory)/\(name).png"))
    }
    return image
}

let cube: Box = (SIMD3(-10, -10, 0), SIMD3(10, 10, 20))
let arms: [(name: String, box: Box, iso: (dx: Double, dyUp: Double))] = [
    // A small far-away block makes a dumbbell: the big cube holds the mass, so the centroid sits opposite to where
    // the block points on screen. Both are equally tall, so only the horizontal direction shifts the centroid.
    ("arm +X", (SIMD3(35, -2.5, 0), SIMD3(40, 2.5, 20)), (-1, 1)),
    ("arm +Y", (SIMD3(-2.5, 35, 0), SIMD3(2.5, 40, 20)), (-1, -1)),
    ("arm -X", (SIMD3(-40, -2.5, 0), SIMD3(-35, 2.5, 20)), (1, -1)),
    ("arm -Y", (SIMD3(-2.5, -40, 0), SIMD3(2.5, -35, 20)), (1, 1)),
]
let threshold = 0.03   // horizontal shift; the vertical one is smaller in an isometric view
let verticalThreshold = 0.01
var seen: [String] = []
for arm in arms {
    guard let picture = try renderPicture([cube, arm.box], view: .iso, name: "iso-\(arm.name)"), let m = silhouette(of: picture) else {
        check(false, "iso render of \(arm.name) produced a picture")
        continue
    }
    check(m.dx * arm.iso.dx > threshold && m.dyUp * arm.iso.dyUp > verticalThreshold, "iso: \(arm.name) puts the mass in the expected quadrant (dx \(String(format: "%.2f", m.dx)), up \(String(format: "%.2f", m.dyUp)))")
    seen.append(String(format: "%.2f/%.2f", m.dx, m.dyUp))
}
check(Set(seen).count == 4, "the four rotated models give four different pictures")

if let pillar = try renderPicture([(SIMD3(-2, -2, 0), SIMD3(2, 2, 40))], view: .iso, name: "iso-pillar"), let m = silhouette(of: pillar) {
    check(m.aspect > 3, "iso: a tall Z pillar stands upright (height/width \(String(format: "%.1f", m.aspect)))")
}
if let raised = try renderPicture([cube, (SIMD3(-2, -2, 20), SIMD3(2, 2, 50))], view: .iso, name: "iso-tower"), let m = silhouette(of: raised) {
    check(m.dyUp < -verticalThreshold, "iso: mass sits below the bounding-box centre of a model with a tall spike (up \(String(format: "%.2f", m.dyUp)))")
}
for view in [ViewAngle.top, .front] {
    if let picture = try renderPicture([cube, arms[0].box], view: view, name: "\(view.rawValue)-arm +X"), let m = silhouette(of: picture) {
        check(m.dx < -threshold, "\(view.rawValue): +X points to screen right (mass shifts left, dx \(String(format: "%.2f", m.dx)))")
    }
}

try? fm.removeItem(at: tmp)
print(failures == 0 ? "all checks passed" : "\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
