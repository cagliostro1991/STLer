import Foundation
import ModelIO

/// The 3DBenchy sample the settings window previews for each file type.
enum SampleFiles {
    private static let cacheDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/stler/samples")

    /// OBJ and PLY samples are exported from the bundled STL instead of being shipped (about 18 MB each).
    static func isGenerated(_ type: FileType) -> Bool { type == .obj || type == .ply }

    /// The sample of `type`: the bundled file, or for OBJ and PLY a copy exported once into the cache.
    /// Exporting takes a few seconds, so call this off the main thread for those two.
    /// - Parameter cache: Where exported samples go; the tests use a temporary folder.
    static func url(for type: FileType, bundle: Bundle = .main, cache: URL = cacheDirectory) -> URL?
    {
        if let bundled = bundle.url(forResource: "3DBenchy", withExtension: type.rawValue) {
            return bundled
        }
        guard isGenerated(type), let stl = bundle.url(forResource: "3DBenchy", withExtension: "stl")
        else { return nil }
        let target = cache.appendingPathComponent("3DBenchy.\(type.rawValue)")
        if FileManager.default.fileExists(atPath: target.path) { return target }
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try? MDLAsset(url: stl).export(to: target)
        return FileManager.default.fileExists(atPath: target.path) ? target : nil
    }
}
