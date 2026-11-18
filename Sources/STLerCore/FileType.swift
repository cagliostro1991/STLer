import Foundation

/// The model formats STLer handles. Each type has its own settings.
enum FileType: String, CaseIterable {
    case stl, threeMF = "3mf", step

    /// Lowercase file extensions of the type.
    var extensions: [String] { self == .step ? ["step", "stp"] : [rawValue] }

    /// Base model colour of the type; matches the type's tint in the settings window.
    var defaultColor: String {
        switch self {
        case .stl: "#4f8ff7"
        case .threeMF: "#f59e42"
        case .step: "#a66cf0"
        }
    }

    /// Name shown in the UI and on the icon label.
    /// Extension of the bundled `3DBenchy` sample for this type.
    var sampleExtension: String { rawValue }

    var title: String { self == .threeMF ? "3MF" : rawValue.uppercased() }

    init?(path: String) {
        let ext = (path as NSString).pathExtension.lowercased()
        guard let type = Self.allCases.first(where: { $0.extensions.contains(ext) }) else {
            return nil
        }
        self = type
    }
}
