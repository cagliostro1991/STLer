import AppKit
import ModelIO
import SceneKit
import SceneKit.ModelIO

/// Offscreen SceneKit renderer that turns a model file into an icon image.
enum IconRenderer {
    struct Options {
        var view = ViewAngle.iso
        var color = NSColor.systemGray
        var firstPlateOnly = true
        var badge = BadgeCorner.off
        /// Label text; defaults to the uppercased file extension.
        var badgeText: String?

        init() {}

        init(config: Config) {
            view = config.view
            color = config.nsColor
            firstPlateOnly = config.firstPlateOnly
            badge = config.badge
        }
    }

    /// Renders a model with an orthographic camera.
    /// - Parameters:
    ///   - url: STL or 3MF file. STEP has to be converted first, see `StepConverter`.
    ///   - size: Output size in points.
    /// - Returns: `nil` when the file cannot be read.
    static func render(_ url: URL, size: CGSize, options: Options = Options()) -> NSImage? {
        guard let scene = loadScene(url, firstPlateOnly: options.firstPlateOnly) else { return nil }

        let material = SCNMaterial()
        material.diffuse.contents = options.color
        material.lightingModel = .blinn
        scene.rootNode.enumerateHierarchy { node, _ in node.geometry?.materials = [material] }

        let (low, high) = scene.rootNode.boundingBox
        let center = SCNVector3((low.x + high.x) / 2, (low.y + high.y) / 2, (low.z + high.z) / 2)
        let (dx, dy, dz) = (high.x - low.x, high.y - low.y, high.z - low.z)
        let radius = (dx * dx + dy * dy + dz * dz).squareRoot() / 2

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(radius) * 1.05
        camera.zNear = 0.01
        camera.zFar = Double(radius) * 10
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        let direction = options.view.cameraDirection
        let reach = radius * 3 / (direction.x * direction.x + direction.y * direction.y + direction.z * direction.z).squareRoot()
        cameraNode.position = SCNVector3(center.x + direction.x * reach, center.y + direction.y * reach, center.z + direction.z * reach)
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.look(at: center, up: options.view.cameraUp, localFront: SCNVector3(0, 0, -1))

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.position = SCNVector3(cameraNode.position.x + radius, cameraNode.position.y - radius, cameraNode.position.z + radius)
        scene.rootNode.addChildNode(key)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        guard options.badge != .off else { return image }
        return addBadge(to: image, text: options.badgeText ?? url.pathExtension.uppercased(), corner: options.badge)
    }

    private static func loadScene(_ url: URL, firstPlateOnly: Bool) -> SCNScene? {
        guard url.pathExtension.lowercased() == "3mf" else { return SCNScene(mdlAsset: MDLAsset(url: url)) }
        guard let node = ThreeMFLoader(url: url, firstPlateOnly: firstPlateOnly).load() else { return nil }
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)
        return scene
    }

    private static func addBadge(to image: NSImage, text: String, corner: BadgeCorner) -> NSImage {
        let size = image.size
        return NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)
            let label = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size.height * 0.11, weight: .bold), .foregroundColor: NSColor.white])
            let textSize = label.size()
            let padX = size.height * 0.035, padY = size.height * 0.02, margin = size.height * 0.03
            let (width, height) = (textSize.width + padX * 2, textSize.height + padY * 2)
            let isLeft = corner == .topLeft || corner == .bottomLeft
            let isTop = corner == .topLeft || corner == .topRight
            let x = isLeft ? margin : size.width - width - margin
            let y = isTop ? size.height - height - margin : margin
            NSColor(white: 0.15, alpha: 0.85).setFill()
            NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), xRadius: height / 2, yRadius: height / 2).fill()
            label.draw(at: CGPoint(x: x + padX, y: y + padY))
            return true
        }
    }
}
