import AppKit
import ModelIO
import SceneKit
import SceneKit.ModelIO

/// Offscreen SceneKit renderer that turns a model file into an icon image.
enum IconRenderer {
    struct Options {
        var view = ViewAngle.iso
        var projection = Projection.orthographic
        var color = NSColor.systemGray
        /// 3MF: plates to show, 0 = all.
        var plates = 0
        /// 0...1: how much of the colours stored in the file replaces `color` (3MF).
        var modelColors = 0.0
        var label = LabelStyle()
        /// Label text; defaults to the uppercased file extension.
        var labelText: String?

        /// Plain render: no label.
        init() { label.corner = .off }

        init(style: TypeStyle, labelText: String?) {
            view = style.view
            projection = style.projection
            color = style.nsColor
            plates = style.limit
            modelColors = Double(style.modelColors) / 100
            label = style.label
            self.labelText = labelText
        }
    }

    /// Renders a model from a standard view, orthographic or perspective.
    /// - Parameters:
    ///   - url: STL or 3MF file. STEP has to be converted first, see `StepConverter`.
    ///   - size: Output size in points.
    /// - Returns: `nil` when the file cannot be read.
    static func render(_ url: URL, size: CGSize, options: Options = Options()) -> NSImage? {
        guard let scene = loadScene(url, options: options) else { return nil }

        scene.rootNode.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let material = SCNMaterial()
            material.diffuse.contents = geometry.sources(for: .color).isEmpty ? options.color : NSColor.white
            material.lightingModel = .blinn
            geometry.materials = [material]
        }

        let (low, high) = scene.rootNode.boundingBox
        let center = SCNVector3((low.x + high.x) / 2, (low.y + high.y) / 2, (low.z + high.z) / 2)
        let (dx, dy, dz) = (high.x - low.x, high.y - low.y, high.z - low.z)
        let radius = (dx * dx + dy * dy + dz * dz).squareRoot() / 2

        let direction = options.view.cameraDirection
        let length = (direction.x * direction.x + direction.y * direction.y + direction.z * direction.z).squareRoot()
        let camera = SCNCamera()
        let distance: CGFloat
        switch options.projection {
        case .orthographic:
            camera.usesOrthographicProjection = true
            camera.orthographicScale = Double(radius) * 1.05
            camera.zNear = 0.01
            camera.zFar = Double(radius) * 10
            distance = radius * 3
        case .perspective:
            camera.fieldOfView = 30
            distance = radius * 1.05 / CGFloat(sin(15.0 * Double.pi / 180))
            camera.zNear = Double(max(distance - radius * 1.5, 0.01))
            camera.zFar = Double(distance + radius * 1.5)
        }
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        let reach = distance / length
        cameraNode.position = SCNVector3(center.x + direction.x * reach, center.y + direction.y * reach, center.z + direction.z * reach)
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.look(at: center, up: options.view.cameraUp, localFront: SCNVector3(0, 0, -1))

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.position = SCNVector3(-radius * 1.5, radius * 1.5, 0)
        cameraNode.addChildNode(key)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        guard options.label.corner != .off else { return image }
        return addLabel(to: image, text: options.labelText ?? url.pathExtension.uppercased(), style: options.label)
    }

    private static func loadScene(_ url: URL, options: Options) -> SCNScene? {
        guard url.pathExtension.lowercased() == "3mf" else {
            let scene = SCNScene(mdlAsset: MDLAsset(url: url))
            scene.rootNode.enumerateHierarchy { node, _ in
                if let geometry = node.geometry, let corners = FlatGeometry.corners(of: geometry) { node.geometry = FlatGeometry.make(points: corners) }
            }
            return scene
        }
        let fill = (options.color.usingColorSpace(.sRGB) ?? .gray)
        let rgb = SIMD3(Float(fill.redComponent), Float(fill.greenComponent), Float(fill.blueComponent))
        guard let node = ThreeMFLoader(url: url, plates: options.plates, fill: rgb, colorAmount: Float(options.modelColors)).load() else { return nil }
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)
        return scene
    }

    private static func addLabel(to image: NSImage, text: String, style: LabelStyle) -> NSImage {
        let size = image.size
        return NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)
            let alpha = CGFloat(style.opacity)
            let textColor = (Config.parseColor(style.textColor) ?? .white).withAlphaComponent(alpha)
            let label = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size.height * 0.11, weight: .bold), .foregroundColor: textColor])
            let textSize = label.size()
            let padX = size.height * 0.035, padY = size.height * 0.02, margin = size.height * 0.03
            let (width, height) = (textSize.width + padX * 2, textSize.height + padY * 2)
            let isLeft = style.corner == .topLeft || style.corner == .bottomLeft
            let isTop = style.corner == .topLeft || style.corner == .topRight
            let x = isLeft ? margin : size.width - width - margin
            let y = isTop ? size.height - height - margin : margin
            let radius = height * CGFloat(style.cornerRadius) / 100
            (Config.parseColor(style.backgroundColor) ?? .black).withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius).fill()
            label.draw(at: CGPoint(x: x + padX, y: y + padY))
            return true
        }
    }
}
