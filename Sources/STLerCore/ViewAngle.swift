import SceneKit

/// Camera presets for the icon render. Models are assumed to be Z-up.
enum ViewAngle: String, CaseIterable, Codable {
    case iso, front, back, left, right, top, bottom

    /// Direction from the model centre towards the camera.
    var cameraDirection: SCNVector3 {
        switch self {
        case .iso: SCNVector3(1, -1, 1)
        case .front: SCNVector3(0, -1, 0)
        case .back: SCNVector3(0, 1, 0)
        case .right: SCNVector3(1, 0, 0)
        case .left: SCNVector3(-1, 0, 0)
        case .top: SCNVector3(0, 0, 1)
        case .bottom: SCNVector3(0, 0, -1)
        }
    }

    /// Top and bottom views look along Z, so screen-up has to be Y there.
    var cameraUp: SCNVector3 {
        self == .top || self == .bottom ? SCNVector3(0, 1, 0) : SCNVector3(0, 0, 1)
    }
}

/// Corner of the format label drawn on the icon, or `off`.
enum BadgeCorner: String, CaseIterable, Codable {
    case off, topLeft, topRight, bottomLeft, bottomRight
}
