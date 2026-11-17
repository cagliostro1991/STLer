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
check(c.set("stl.view", "bogus") != nil, "config rejects unknown view")
check(c.set("stl.view", "top") == nil && c.stl.view == .top && c.threeMF.view == .iso, "config sets the view of one type only")
check(c.set("stl.projection", "fisheye") != nil && c.set("stl.projection", "perspective") == nil && c.stl.projection == .perspective, "config validates projection")
check(c.set("stl.color", "#12") != nil, "config rejects short colour")
check(c.set("3mf.color", "#AABBCC") == nil && c.threeMF.color == "#aabbcc", "config lowercases colour")
check(c.set("freecadPath", "/bin/echo") == nil, "config accepts an executable as freecadPath")
check(c.set("step.enabled", "maybe") != nil && c.set("step.enabled", "true") == nil && c.step.enabled, "config validates enabled")
let defaultColors = FileType.allCases.map { Config()[$0].color }
check(Set(defaultColors).count == 3 && defaultColors.allSatisfy(Config.isHex), "each file type has its own default colour")
check(Config().enabledFormats == ["stl", "3mf"] && c.enabledFormats == ["stl", "3mf", "step"], "enabled formats follow the per-type switches")
check(c.set("png.view", "top") != nil && c.set("stl.nothing", "x") != nil, "config rejects unknown types and keys")
var noFreecad = Config()
noFreecad.freecadPath = "/nonexistent"
check(noFreecad.set("step.enabled", "true") != nil && !noFreecad.step.enabled, "STEP cannot be enabled without FreeCAD")
noFreecad.step.enabled = true
check(noFreecad.enabledFormats == ["stl", "3mf"], "STEP is ignored while FreeCAD is missing, even if the flag is on")
check(StepConverter.executable("/bin/echo") == "/bin/echo" && StepConverter.executable("/nonexistent") == nil, "freecadPath must point to an executable")
check(c.set("followDepth", "0") != nil, "config rejects depth 0")
check(c.set("followDepth", "deep") == nil && c.followDepth == 0, "config maps deep to 0")
check(c.set("stl.label.corner", "middle") != nil && c.set("stl.label.corner", "off") == nil && c.stl.label.corner == .off, "config validates the label corner")
check(c.set("freecadPath", "/nonexistent") != nil, "config rejects missing freecadPath")
check(c.set("scope", "everywhere") != nil && c.set("scope", "home") == nil && c.scope == .home, "config validates scope")
check(c.set("scopeFolders", "~/a, ~/b ,") == nil && c.scopeFolders == ["~/a", "~/b"], "scopeFolders takes a comma list")
check(Config().scopePaths.isEmpty && c.scopePaths.count == 1 && c.scopePaths[0] == NSHomeDirectory(), "the home scope is the home folder, an empty folder list is no scope")
var folders = Config()
_ = folders.set("scopeFolders", "/tmp/x,/tmp/y")
check(folders.scopePaths == ["/tmp/x", "/tmp/y"], "several chosen folders are all in scope")
let oldScope = try JSONDecoder().decode(Config.self, from: Data(#"{"scopeFolder":"~/Models"}"#.utf8))
check(oldScope.scopeFolders == ["~/Models"], "a single legacy scopeFolder becomes a one-item list")
check(c.set("stl.label.textColor", "red") != nil && c.set("stl.label.textColor", "#FFEE00") == nil && c.stl.label.textColor == "#ffee00", "config validates the label text colour")
check(c.set("stl.label.backgroundColor", "#00ff00") == nil && c.set("stl.label.backgroundColor", "00ff00") != nil, "config validates the label background colour")
check(c.set("stl.label.opacity", "1.5") != nil && c.set("stl.label.opacity", "0.5") == nil && c.stl.label.opacity == 0.5, "config validates label opacity")
check(c.set("stl.label.cornerRadius", "51") != nil && c.set("stl.label.cornerRadius", "abc") != nil && c.set("stl.label.cornerRadius", "0") == nil && c.stl.label.cornerRadius == 0, "config validates label corner radius")
let legacy = try JSONDecoder().decode(Config.self, from: Data(##"{"view":"top","color":"#112233","formats":["stl"],"badge":"off","followDepth":5}"##.utf8))
check(legacy.stl.enabled && !legacy.threeMF.enabled && !legacy.step.enabled, "legacy formats become the enabled flags")
check(legacy.stl.view == .top && legacy.threeMF.view == .top && legacy.stl.color == "#112233" && legacy.stl.label.corner == .off && legacy.followDepth == 5, "legacy global view, colour and badge move to every type")
let tolerant = try JSONDecoder().decode(Config.self, from: Data(##"{"stl":{"view":"sideways","color":"#abcdef","label":{"corner":"middle","opacity":0.3}}}"##.utf8))
check(tolerant.stl.view == .iso && tolerant.stl.color == "#abcdef" && tolerant.stl.label.corner == .bottomRight && tolerant.stl.label.opacity == 0.3, "invalid values fall back per key, valid ones are kept")
let roundTrip = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(c))
check(roundTrip == c, "a saved config reads back identically")
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

check(FileScanner.isUserFile("/Users/me/Projects/box.stl") && FileScanner.isUserFile("/Users/me/Downloads/a b/c.3mf"), "spotlight results from normal folders are kept")
check(!FileScanner.isUserFile("/Users/me/Library/Caches/x.stl") && !FileScanner.isUserFile("/Users/me/.hidden/x.stl") && !FileScanner.isUserFile("/Applications/Tool.app/Contents/Resources/x.stl") && !FileScanner.isUserFile("/Users/me/Pictures/Photos.photoslibrary/x.stl"), "spotlight results from Library, hidden folders and packages are dropped")

// MARK: view and signature

check(ViewAngle.iso.cameraUp.z == 1 && ViewAngle.front.cameraUp.z == 1, "iso and side views keep Z up (iso used to roll the model)")
check(ViewAngle.top.cameraUp.y == 1 && ViewAngle.bottom.cameraUp.y == 1, "top and bottom views use Y up")
let baseSignature = Signature.make(for: Config(), type: .stl)
let signatureChanges: [(String, String)] = [("stl.view", "top"), ("stl.projection", "perspective"), ("stl.color", "#ff0000"), ("stl.label.corner", "off"),
                                            ("stl.label.textColor", "#000000"), ("stl.label.backgroundColor", "#ffffff"), ("stl.label.cornerRadius", "0"), ("stl.label.opacity", "0.5")]
for (key, value) in signatureChanges {
    var changed = Config()
    _ = changed.set(key, value)
    check(Signature.make(for: changed, type: .stl) != baseSignature, "signature changes with \(key)")
}
var otherType = Config()
_ = otherType.set("3mf.view", "top")
_ = otherType.set("followDepth", "1")
check(Signature.make(for: otherType, type: .stl) == baseSignature, "signature ignores other types and settings that do not change the icon")
var plateConfig = Config()
_ = plateConfig.set("firstPlateOnly", "false")
check(Signature.make(for: plateConfig, type: .threeMF) != Signature.make(for: Config(), type: .threeMF) && Signature.make(for: plateConfig, type: .stl) == baseSignature, "first-plate setting only affects 3MF")
check(FileType(path: "/a/Model.STP") == .step && FileType(path: "b.3mf") == .threeMF && FileType(path: "c.obj") == nil, "file types are recognised by extension")

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
_ = cfg.set("stl.label.corner", "off")
check(IconBatch.apply([stl], config: cfg).rendered == 1, "changed settings re-render")
check(IconBatch.apply([stl], config: cfg, force: true).rendered == 1, "force re-renders")
var disabled = cfg
_ = disabled.set("stl.enabled", "false")
check(IconBatch.apply([stl], config: disabled, force: true).skipped == 1, "a disabled type is left alone")
check(IconBatch.reset([stl]).reset == 1 && Signature.read(stl) == nil, "reset removes our icon and signature")
check(mtime() == old, "reset keeps the file's modification date")
let batchFiles = (1...3).map { tmp.appendingPathComponent("batch\($0).stl").path }
for file in batchFiles { try fm.copyItem(atPath: stl, toPath: file) }
var asked = 0
var stopConfig = Config()
_ = stopConfig.set("stl.label.corner", "off")
let stopped = IconBatch.apply(batchFiles, config: stopConfig, shouldContinue: { asked += 1; return asked <= 1 })
check(stopped.interrupted && stopped.rendered == 1, "a run stops when shouldContinue says so (1 of 3 files rendered)")
check(IconBatch.apply(batchFiles, config: stopConfig).skipped == 1, "a stopped run resumes where it left off (rendered file skipped)")
var progressCalls = 0
_ = IconBatch.apply(batchFiles, config: stopConfig, onProgress: { _, _ in progressCalls += 1 })
check(progressCalls == 3, "progress is reported once per file")
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

/// Number of clearly different brightness levels among the opaque pixels (a flat, unlit model has one).
func shadeLevels(of image: NSImage) -> Int {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return 0 }
    var buckets = [Int](repeating: 0, count: 16)
    var total = 0
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceGray), color.alphaComponent > 0.5 else { continue }
            buckets[min(15, Int(color.whiteComponent * 16))] += 1
            total += 1
        }
    }
    return buckets.filter { Double($0) > Double(total) * 0.05 }.count
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

if let shaded = try renderPicture([cube], view: .iso, name: "iso-zero-normals"), shadeLevels(of: shaded) >= 3 {
    check(true, "an STL with zero facet normals is still shaded (three face tones)")
} else {
    check(false, "an STL with zero facet normals is still shaded (three face tones)")
}

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

// MARK: label style and projection (pixels)

func pixel(_ image: NSImage, _ x: Int, _ y: Int) -> NSColor? {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    let scale = Double(rep.pixelsWide) / image.size.width
    return rep.colorAt(x: Int(Double(x) * scale), y: Int(Double(y) * scale))?.usingColorSpace(.sRGB)
}

let stylePath = tmp.appendingPathComponent("style.stl").path
try writeBoxes([cube], to: stylePath)
func styled(_ configure: (inout IconRenderer.Options) -> Void) -> NSImage? {
    var options = IconRenderer.Options()
    configure(&options)
    return IconRenderer.render(URL(fileURLWithPath: stylePath), size: CGSize(width: 256, height: 256), options: options)
}

// The label box sits bottom right at about x 178...248, y 204...248: (184, 226) is its left padding (background only), (180, 206) its top-left corner.
func redLabel(_ edit: (inout LabelStyle) -> Void) -> NSImage? {
    styled {
        $0.label.corner = .bottomRight
        $0.label.backgroundColor = "#ff0000"
        $0.label.opacity = 1
        edit(&$0.label)
    }
}
if let solid = redLabel({ _ in }) {
    let p = pixel(solid, 184, 226)
    check((p?.redComponent ?? 0) > 0.9 && (p?.greenComponent ?? 1) < 0.25 && (p?.blueComponent ?? 1) < 0.1 && (p?.alphaComponent ?? 0) > 0.95, "label background colour is applied")
}
// A bottom-left label leaves its top-left corner over empty space (the iso cube does not reach it): (9, 206).
if let pill = redLabel({ $0.corner = .bottomLeft; $0.cornerRadius = 50 }), let box = redLabel({ $0.corner = .bottomLeft; $0.cornerRadius = 0 }) {
    check((pixel(pill, 9, 206)?.alphaComponent ?? 1) < 0.2 && (pixel(box, 9, 206)?.alphaComponent ?? 0) > 0.9, "label corner radius rounds the box corners")
}
if let faded = redLabel({ $0.opacity = 0.5 }) {
    check(abs((pixel(faded, 184, 226)?.alphaComponent ?? 0) - 0.5) < 0.06, "label opacity sets the label alpha")
}
if let shown = redLabel({ _ in }), let hidden = styled({ $0.label.corner = .off }) {
    check((pixel(hidden, 184, 226)?.alphaComponent ?? 1) < 0.05 && (pixel(shown, 184, 226)?.alphaComponent ?? 0) > 0.9, "label corner off hides the label")
}
if let topLeft = styled({ $0.label.corner = .topLeft; $0.label.opacity = 1 }) {
    check((pixel(topLeft, 40, 22)?.alphaComponent ?? 0) > 0.9 && (pixel(topLeft, 212, 226)?.alphaComponent ?? 1) < 0.1, "label corner moves the label")
}
if let ortho = try renderPicture([(SIMD3(-2, -2, 0), SIMD3(2, 2, 40))], view: .iso, name: "ortho-pillar"), let a = silhouette(of: ortho) {
    var options = IconRenderer.Options()
    options.projection = .perspective
    let path = tmp.appendingPathComponent("ortho-pillar.stl").path
    if let persp = IconRenderer.render(URL(fileURLWithPath: path), size: CGSize(width: 256, height: 256), options: options), let b = silhouette(of: persp) {
        check(abs(a.aspect - b.aspect) > 0.05, "perspective changes the picture (aspect \(String(format: "%.2f", a.aspect)) vs \(String(format: "%.2f", b.aspect)))")
        check((pixel(persp, 2, 2)?.alphaComponent ?? 1) < 0.05 && (pixel(persp, 128, 128)?.alphaComponent ?? 0) > 0.9, "a perspective render stays inside the frame")
    }
}

try? fm.removeItem(at: tmp)
print(failures == 0 ? "all checks passed" : "\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
