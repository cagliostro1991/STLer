import AppKit
import SceneKit

var failures = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() { print("ok   \(message)") } else { print("FAIL \(message)"); failures += 1 }
}

func close(_ a: CGFloat, _ b: Double) -> Bool { abs(Double(a) - b) < 1e-6 }

let fm = FileManager.default
let tmp = fm.temporaryDirectory.appendingPathComponent("styler-tests-\(UUID().uuidString)")
try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

func touch(_ path: String, _ content: String = "x") throws {
    try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try content.write(toFile: path, atomically: true, encoding: .utf8)
}

// MARK: config

var c = Config()
check(c.set("view", "bogus") != nil, "config rejects unknown view")
check(c.set("view", "top") == nil && c.view == "top", "config accepts a view")
check(c.set("color", "#12") != nil, "config rejects short colour")
check(c.set("color", "#AABBCC") == nil && c.color == "#aabbcc", "config lowercases colour")
check(c.set("formats", "stl,step") == nil && c.formats == ["stl", "step"], "config accepts format list")
check(c.set("formats", "obj") != nil, "config rejects unsupported format")
check(c.set("followDepth", "0") != nil, "config rejects depth 0")
check(c.set("followDepth", "deep") == nil && c.followDepth == 0, "config maps deep to 0")
check(c.set("badge", "middle") != nil, "config rejects unknown badge corner")
check(c.set("freecadPath", "/nonexistent") != nil, "config rejects missing freecadPath")
let partial = try JSONDecoder().decode(Config.self, from: Data(#"{"view":"top"}"#.utf8))
check(partial.view == "top" && partial.followDepth == 3 && partial.badge == "bottomRight", "partial config falls back to defaults")
check(parseColor("system") != nil && parseColor("#zzzzzz") == nil && parseColor("3d9a2c") == nil, "parseColor validates input")

// MARK: file collection

let tree = tmp.appendingPathComponent("tree").path
for f in ["a.stl", "sub/b.stl", "sub/deep/c.stl", "sub/deep/d.txt", ".hidden/e.stl", "s.STP"] { try touch("\(tree)/\(f)") }
let names: ([String]) -> [String] = { $0.map { ($0 as NSString).lastPathComponent }.sorted() }
check(names(collectFiles([tree], formats: ["stl"], maxDepth: 1)) == ["a.stl"], "depth 1 = open folder only")
check(names(collectFiles([tree], formats: ["stl"], maxDepth: 2)) == ["a.stl", "b.stl"], "depth 2 adds one level")
check(names(collectFiles([tree], formats: ["stl"])) == ["a.stl", "b.stl", "c.stl"], "unlimited depth skips hidden folders and other extensions")
check(names(collectFiles([tree], formats: ["step"])) == ["s.STP"], "step format also matches .stp in any case")
let ordered = byDepth(["\(tree)/sub/deep/c.stl", "\(tree)/sub/b.stl", "\(tree)/a.stl"], under: tree)
check(names(ordered) == ["a.stl", "b.stl", "c.stl"] && (ordered[0] as NSString).lastPathComponent == "a.stl" && (ordered[2] as NSString).lastPathComponent == "c.stl", "byDepth puts top level first")

// MARK: signature

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
check(renderBatch([stl], config: cfg).rendered == 1, "renders a new file")
check(mtime() == old, "setting an icon keeps the file's modification date")
check(Signature.read(stl) != nil, "rendered file carries a signature")
check(renderBatch([stl], config: cfg).skipped == 1, "unchanged file is skipped")
cfg.badge = "off"
check(renderBatch([stl], config: cfg).rendered == 1, "changed settings re-render")
check(renderBatch([stl], config: cfg, force: true).rendered == 1, "force re-renders")
check(resetIcons([stl]).reset == 1 && Signature.read(stl) == nil, "reset removes our icon and signature")
check(mtime() == old, "reset keeps the file's modification date")
let foreign = tmp.appendingPathComponent("foreign.stl").path
try touch(foreign)
check(resetIcons([foreign]).untouched == 1, "reset leaves files without our signature alone")

try? fm.removeItem(at: tmp)
print(failures == 0 ? "all checks passed" : "\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
