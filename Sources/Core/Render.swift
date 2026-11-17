import AppKit
import SceneKit
import ModelIO
import SceneKit.ModelIO

/// Camera direction (from the model centre towards the camera) per view name; Z-up.
let viewDirections: [String: SCNVector3] = [
    "iso": SCNVector3(1, -1, 1), "front": SCNVector3(0, -1, 0), "back": SCNVector3(0, 1, 0),
    "right": SCNVector3(1, 0, 0), "left": SCNVector3(-1, 0, 0),
    "top": SCNVector3(0, 0, 1), "bottom": SCNVector3(0, 0, -1),
]

/// Renders an STL file with an orthographic camera from the named view.
func render(stl: URL, size: CGSize, view: String, color: NSColor, firstPlateOnly: Bool = true, badge: String = "off", badgeText: String? = nil) -> NSImage? {
    guard let dir = viewDirections[view] else { return nil }
    let scene: SCNScene
    if stl.pathExtension.lowercased() == "3mf" {
        guard let node = ThreeMFLoader(url: stl, firstPlateOnly: firstPlateOnly).load() else { return nil }
        scene = SCNScene()
        scene.rootNode.addChildNode(node)
    } else {
        scene = SCNScene(mdlAsset: MDLAsset(url: stl))
    }
    let gray = SCNMaterial()
    gray.diffuse.contents = color
    gray.lightingModel = .blinn
    scene.rootNode.enumerateHierarchy { node, _ in node.geometry?.materials = [gray] }

    let (lo, hi) = scene.rootNode.boundingBox
    let c = SCNVector3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)
    let dx = hi.x - lo.x, dy = hi.y - lo.y, dz = hi.z - lo.z
    let radius: CGFloat = (dx * dx + dy * dy + dz * dz).squareRoot() / 2

    let cam = SCNCamera()
    cam.usesOrthographicProjection = true
    cam.orthographicScale = Double(radius) * 1.05
    cam.zNear = 0.01
    cam.zFar = Double(radius) * 10
    let camNode = SCNNode()
    camNode.camera = cam
    let len = (dir.x * dir.x + dir.y * dir.y + dir.z * dir.z).squareRoot()
    let k = radius * 3 / len
    camNode.position = SCNVector3(c.x + dir.x * k, c.y + dir.y * k, c.z + dir.z * k)
    scene.rootNode.addChildNode(camNode)
    camNode.look(at: c, up: dir.z == 0 ? SCNVector3(0, 0, 1) : SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

    let light = SCNNode()
    light.light = SCNLight()
    light.light?.type = .omni
    light.position = SCNVector3(camNode.position.x + radius, camNode.position.y - radius, camNode.position.z + radius)
    scene.rootNode.addChildNode(light)
    let amb = SCNNode()
    amb.light = SCNLight()
    amb.light?.type = .ambient
    amb.light?.intensity = 400
    scene.rootNode.addChildNode(amb)

    let r = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    r.scene = scene
    r.pointOfView = camNode
    let image = r.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
    return badge == "off" ? image : addBadge(to: image, text: badgeText ?? stl.pathExtension.uppercased(), corner: badge)
}

/// Draws a small rounded label with the file format in one corner of the icon.
func addBadge(to image: NSImage, text: String, corner: String) -> NSImage {
    let size = image.size
    return NSImage(size: size, flipped: false) { rect in
        image.draw(in: rect)
        let label = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size.height * 0.11, weight: .bold), .foregroundColor: NSColor.white])
        let ts = label.size()
        let padX = size.height * 0.035, padY = size.height * 0.02, margin = size.height * 0.03
        let w = ts.width + padX * 2, h = ts.height + padY * 2
        let x = corner.hasSuffix("Left") ? margin : size.width - w - margin
        let y = corner.hasPrefix("top") ? size.height - h - margin : margin
        NSColor(white: 0.15, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), xRadius: h / 2, yRadius: h / 2).fill()
        label.draw(at: CGPoint(x: x + padX, y: y + padY))
        return true
    }
}
