import SceneKit
import simd

/// Faceted geometry with one normal per triangle, like a slicer preview.
enum FlatGeometry {
    /// - Parameter points: Triangle corners, three per triangle.
    static func make(points: [SCNVector3]) -> SCNGeometry {
        SCNGeometry(
            sources: [SCNGeometrySource(vertices: points), SCNGeometrySource(normals: normals(for: points))],
            elements: [SCNGeometryElement(indices: (0..<Int32(points.count)).map { $0 }, primitiveType: .triangles)])
    }

    /// Triangle corners of a geometry that is made of plain triangles, or `nil` for anything else.
    static func corners(of geometry: SCNGeometry) -> [SCNVector3]? {
        guard let source = geometry.sources(for: .vertex).first, source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector == 3 else { return nil }
        let positions: [SCNVector3] = source.data.withUnsafeBytes { raw in
            (0..<source.vectorCount).map { index in
                let base = source.dataOffset + index * source.dataStride
                return SCNVector3(CGFloat(raw.load(fromByteOffset: base, as: Float.self)), CGFloat(raw.load(fromByteOffset: base + 4, as: Float.self)), CGFloat(raw.load(fromByteOffset: base + 8, as: Float.self)))
            }
        }
        var corners: [SCNVector3] = []
        for element in geometry.elements {
            guard element.primitiveType == .triangles, element.bytesPerIndex == 2 || element.bytesPerIndex == 4 else { return nil }
            element.data.withUnsafeBytes { raw in
                for i in 0..<element.primitiveCount * 3 {
                    let index = element.bytesPerIndex == 4 ? Int(raw.load(fromByteOffset: i * 4, as: UInt32.self)) : Int(raw.load(fromByteOffset: i * 2, as: UInt16.self))
                    if index < positions.count { corners.append(positions[index]) }
                }
            }
        }
        return corners.count % 3 == 0 ? corners : nil
    }

    private static func normals(for points: [SCNVector3]) -> [SCNVector3] {
        func vector(_ p: SCNVector3) -> SIMD3<Double> { SIMD3(Double(p.x), Double(p.y), Double(p.z)) }
        var normals: [SCNVector3] = []
        normals.reserveCapacity(points.count)
        for i in stride(from: 0, to: points.count, by: 3) {
            let a = vector(points[i])
            let n = simd_normalize(simd_cross(vector(points[i + 1]) - a, vector(points[i + 2]) - a))
            let normal = SCNVector3(CGFloat(n.x), CGFloat(n.y), CGFloat(n.z))
            normals += [normal, normal, normal]
        }
        return normals
    }
}
