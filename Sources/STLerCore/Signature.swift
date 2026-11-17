import Foundation

/// Marks files whose icon was written by STLer, so reruns skip unchanged files and `reset` never touches foreign icons.
/// Stored as an extended attribute; it disappears together with the icon when a file is copied without xattrs.
enum Signature {
    private static let attribute = "dev.stler.sig"

    /// Fingerprint of every setting that changes the icon of one file type, so changing one type never re-renders another.
    /// Bump the prefix when the renderer output changes.
    static func make(for config: Config, type: FileType) -> String {
        let style = config[type]
        let label = style.label
        var parts = ["v6", type.rawValue, style.view.rawValue, style.projection.rawValue, style.color]
        if type != .stl { parts += [String(style.limit), String(style.modelColors)] }
        parts += [label.corner.rawValue, label.textColor, label.backgroundColor, String(label.cornerRadius), String(label.opacity)]
        return parts.joined(separator: "|")
    }

    static func read(_ path: String) -> String? {
        let size = getxattr(path, attribute, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard getxattr(path, attribute, &buffer, size, 0, 0) == size else { return nil }
        return String(decoding: buffer, as: UTF8.self)
    }

    static func write(_ path: String, _ signature: String) {
        let bytes = Array(signature.utf8)
        setxattr(path, attribute, bytes, bytes.count, 0, 0)
    }

    static func remove(_ path: String) {
        removexattr(path, attribute, 0)
    }
}
