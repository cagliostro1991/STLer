import Foundation

/// Marks files whose icon was set by STyLer, so reruns can skip unchanged files and `reset` never touches foreign icons.
enum Signature {
    static let attr = "dev.styler.sig"

    /// Builds the signature for a render configuration; bump `v2` when the renderer output changes.
    static func make(view: String, color: String, firstPlateOnly: Bool, badge: String) -> String {
        "v2|\(view)|\(color)|\(firstPlateOnly)|\(badge)"
    }

    static func read(_ path: String) -> String? {
        let n = getxattr(path, attr, nil, 0, 0, 0)
        guard n > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: n)
        guard getxattr(path, attr, &buf, n, 0, 0) == n else { return nil }
        return String(decoding: buf, as: UTF8.self)
    }

    static func write(_ path: String, _ sig: String) {
        let bytes = Array(sig.utf8)
        setxattr(path, attr, bytes, bytes.count, 0, 0)
    }

    static func remove(_ path: String) {
        removexattr(path, attr, 0)
    }
}
